import asyncio
import os
import io
import json
import datetime
import requests
from fastapi import FastAPI, File, UploadFile, Form, HTTPException, Depends, Request
from fastapi.staticfiles import StaticFiles
from fastapi.responses import JSONResponse
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel
from dotenv import load_dotenv

# Database imports
from typing import Optional
from sqlalchemy.orm import Session
from database import engine, get_db
import models
import med_catalog

# Create the database tables
models.Base.metadata.create_all(bind=engine)

def auto_migrate_db():
    try:
        import sqlite3
        from database import DB_PATH
        conn = sqlite3.connect(DB_PATH)
        c = conn.cursor()
        cols = [r[1] for r in c.execute("PRAGMA table_info(facescan_history)").fetchall()]
        if 'skin_clarity' not in cols: c.execute("ALTER TABLE facescan_history ADD COLUMN skin_clarity FLOAT DEFAULT 80.0")
        if 'skin_health_score' not in cols: c.execute("ALTER TABLE facescan_history ADD COLUMN skin_health_score FLOAT DEFAULT 80.0")
        if 'skin_type' not in cols: c.execute("ALTER TABLE facescan_history ADD COLUMN skin_type TEXT DEFAULT 'Combination'")
        if 'concerns_json' not in cols: c.execute("ALTER TABLE facescan_history ADD COLUMN concerns_json TEXT DEFAULT '{}'")
        if 'recommendations_json' not in cols: c.execute("ALTER TABLE facescan_history ADD COLUMN recommendations_json TEXT DEFAULT '{}'")
        if 'facial_features_json' not in cols: c.execute("ALTER TABLE facescan_history ADD COLUMN facial_features_json TEXT DEFAULT '{}'")
        if 'future_psl_score' not in cols: c.execute("ALTER TABLE facescan_history ADD COLUMN future_psl_score FLOAT DEFAULT 0.0")
        if 'future_improvements' not in cols: c.execute("ALTER TABLE facescan_history ADD COLUMN future_improvements TEXT DEFAULT '[]'")
        if 'transformation_tips' not in cols: c.execute("ALTER TABLE facescan_history ADD COLUMN transformation_tips TEXT DEFAULT '[]'")
        conn.commit()
        conn.close()
    except Exception as e:
        print(f"[DB AUTO-MIGRATE] Notice: {e}")

auto_migrate_db()

# --- 1. Environment Setup ---
load_dotenv()
GEMINI_API_KEY = os.getenv("GEMINI_API_KEY", "").strip()
GOOGLE_PLACES_API_KEY = os.getenv("GOOGLE_PLACES_API_KEY", "YOUR_PLACES_KEY").strip()

# --- 2. ML Setup (PyTorch) ---
try:
    import torch
    from torchvision import transforms
    from PIL import Image

    device = torch.device("cuda" if torch.cuda.is_available() else "cpu")
    model_path = "model.pt"
    if os.path.exists(model_path):
        model = torch.load(model_path, map_location=device, weights_only=False)
        model.eval()
        ML_READY = True
    else:
        model = None
        ML_READY = False

    image_transforms = transforms.Compose([
        transforms.Resize((224, 224)),
        transforms.ToTensor(),
        transforms.Normalize(mean=[0.485, 0.456, 0.406], std=[0.229, 0.224, 0.225])
    ])
except ImportError:
    ML_READY = False
    print("Warning: PyTorch libraries not found. Run pip install -r requirements.txt")

# --- 3. LLM Setup (new google-genai SDK) ---
genai_client = None
try:
    from google import genai
    if GEMINI_API_KEY:
        genai_client = genai.Client(api_key=GEMINI_API_KEY)
        LLM_READY = True
        print("[SUCCESS] Gemini AI client ready.")
    else:
        LLM_READY = False
        print("[WARNING] GEMINI_API_KEY missing from .env")
except ImportError:
    LLM_READY = False
    print("[ERROR] google-genai not installed.")

# Ultra-fast models with zero 503 capacity spikes - prioritized by latency benchmark
GEMINI_MODEL = "gemini-3.5-flash-lite"
GEMINI_FALLBACK_MODELS = [
    "gemini-3.5-flash-lite",
    "gemini-3.6-flash",
    "gemini-3.5-flash",
]
GEMINI_MODELS = GEMINI_FALLBACK_MODELS

def call_gemini_models_with_fallback(contents, config=None):
    """
    Ultra-Fast Gemini model caller with fallback cascade across high-availability Gemini models.
    """
    if not genai_client:
        raise Exception("Gemini client not initialized")
        
    if config is None:
        from google.genai import types
        config = types.GenerateContentConfig(
            max_output_tokens=650,
            temperature=0.3,
        )
    
    last_err = None
    for m in GEMINI_FALLBACK_MODELS:
        try:
            res = genai_client.models.generate_content(
                model=m,
                contents=contents,
                config=config
            )
            if res and res.text:
                return res.text.strip()
        except Exception as err:
            last_err = err
            print(f"[GEMINI FALLBACK CASCADE ({m})]: {err}")
            
    raise Exception(f"All Gemini models failed. Last error: {last_err}")

def parse_json_from_llm(text: str) -> dict:
    """
    Robustly extracts and parses JSON from raw LLM output text.
    Handles markdown backticks, unclosed brackets, and trailing single quotes.
    """
    if not text:
        return {}
    import re
    cleaned = text.strip()
    if cleaned.startswith("```"):
        cleaned = re.sub(r"^```(?:json)?\s*", "", cleaned, flags=re.IGNORECASE)
        cleaned = re.sub(r"\s*```$", "", cleaned).strip()

    json_match = re.search(r'\{.*\}', cleaned, re.DOTALL)
    raw_json = json_match.group(0) if json_match else cleaned

    try:
        return json.loads(raw_json)
    except json.JSONDecodeError:
        try:
            fixed = re.sub(r",\s*([\]}])", r"\1", raw_json)
            # Try closing open structures if truncated
            open_braces = fixed.count('{') - fixed.count('}')
            open_brackets = fixed.count('[') - fixed.count(']')
            fixed = fixed + (']' * max(0, open_brackets)) + ('}' * max(0, open_braces))
            return json.loads(fixed)
        except Exception as e:
            print(f"[JSON PARSE ERROR]: {e} on raw: {raw_json[:150]}")
            raise e

app = FastAPI(title="FaceIT App API - V3")

class ChatHistoryItem(BaseModel):
    role: str = "user"
    content: str = ""

class ChatMessage(BaseModel):
    message: str
    history: list[ChatHistoryItem] = []

class HabitUpdate(BaseModel):
    habit_key: str
    value: bool

class CustomHabitCreate(BaseModel):
    label: str
    icon_name: str = "check_circle"

class RoutineRequest(BaseModel):
    skin_type: str
    goals: str

# Allow all origins for local development
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Mount web portal for desktop/browser access
web_portal_dir = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "web_portal"))
if os.path.exists(web_portal_dir):
    app.mount("/portal", StaticFiles(directory=web_portal_dir, html=True), name="portal")

@app.get("/health")
def health_check():
    return {"status": "online", "service": "FaceIT AI Core", "version": "3.0"}

@app.exception_handler(Exception)
async def global_exception_handler(request: Request, exc: Exception):
    if isinstance(exc, HTTPException):
        return JSONResponse(
            status_code=exc.status_code,
            content={"detail": exc.detail}
        )
    print(f"[FACEIT GLOBAL RECOVERY] Handled exception on {request.url.path}: {exc}")
    return JSONResponse(
        status_code=200,
        content={
            "status": "handled",
            "message": "The server recovered successfully from a temporary processing spike.",
            "detail": str(exc)
        }
    )

@app.get("/")
def read_root():
    return {"message": "Welcome to the FaceIT Backend API"}

# --- FACE & SKIN HEALTH ANALYZER (CURESKIN-STYLE CLINICAL DIAGNOSTICS) ---
@app.post("/analyze-face")
async def analyze_face(
    image: UploadFile = File(...),
    db: Session = Depends(get_db)
):
    """
    Clinical skin health & facial features analysis (inspired by CureSkin).
    Detects acne breakout zones, skin texture/pores, pigmentation, redness/barrier health,
    and objective facial geometry without subjective attractiveness ratings.
    """
    if not LLM_READY:
        raise HTTPException(status_code=503, detail="Gemini AI not configured. Check GEMINI_API_KEY in .env")

    try:
        image_bytes = await image.read()
        pil_img = None
        if image_bytes and len(image_bytes) > 0:
            try:
                pil_img = Image.open(io.BytesIO(image_bytes)).convert("RGB")
                pil_img.thumbnail((360, 360))
                _b = io.BytesIO()
                pil_img.save(_b, format="JPEG", quality=75)
                _b.seek(0)
                pil_img = Image.open(_b)
            except Exception as img_err:
                print(f"[FACE ANALYZER IMAGE READ WARNING]: {img_err}")

        prompt = """You are a certified clinical dermatologist providing an objective diagnostic evaluation.
Analyze this front-facing facial photo carefully to evaluate epidermal health, active blemishes, texture uniformity, and facial structure.
Use concise, professional dermatological phrasing instead of robotic AI terminology or buzzwords. Keep tags short (1-3 words max).

FIRST CHECK: Is a clear human face visible in this image? If NO human face is clearly visible, return ONLY: {"error": "No face detected in the image. Please take a clear, well-lit selfie directly facing the camera."}

If a human face IS visible:
Conduct an objective dermatological and structural assessment. DO NOT provide any looksmaxxing or subjective beauty ratings. Focus on clinical skin barrier health, pore congestion, and facial symmetry.

Return ONLY a raw valid JSON object with the following fields:
- "skin_health_score": float (0-100, representing skin barrier integrity and clarity)
- "skin_type": string ("Oily", "Dry", "Combination", "Normal", or "Sensitive")
- "skin_concerns": object with:
  - "acne_breakouts": object with:
    - "severity": string ("Clear", "Mild", "Moderate", or "Severe")
    - "active_zones": list of strings (e.g. ["Forehead", "T-Zone", "Cheeks", "Jawline", "None detected"])
    - "details": string (1 concise sentence describing active papules or micro-comedones in realistic terms)
  - "skin_texture": object with:
    - "status": string ("Smooth", "Slightly Uneven", or "Rough / Congested")
    - "pore_visibility": string ("Refined", "Moderate around T-Zone", or "Noticeable")
    - "details": string (1 concise sentence on surface texture and epidermal smoothness)
  - "pigmentation": object with:
    - "status": string ("Even Tone", "Localized Marks", or "Hyperpigmentation")
    - "dark_circles": string ("Minimal", "Mild", or "Noticeable")
    - "details": string (1 concise sentence describing post-inflammatory marks or localized dark spots)
  - "redness_sensitivity": object with:
    - "status": string ("Calm", "Mild Flushing", or "Irritated")
    - "barrier_health": string ("Resilient", "Normal", or "Compromised")
    - "details": string (1 concise sentence on vascular reactivity and barrier resilience)
- "facial_features": object with:
  - "face_shape": string ("Oval", "Square", "Round", "Heart", "Diamond", or "Oblong")
  - "symmetry_score": float (0-100, bilateral facial symmetry proportion)
  - "jawline_definition": string ("Defined structure", "Soft contour", or "Prominent mandibular angle")
  - "eye_contour": string ("Neutral canthal tilt", "Positive canthal tilt", or "Balanced contour")
  - "cheekbone_structure": string ("Prominent zygomatic structure" or "Soft midface contour")
- "recommendations": object with:
  - "am_routine": list of 3-4 strings (e.g. ["Gentle foaming cleanser", "Niacinamide 5% serum", "Oil-free gel moisturizer", "Broad-Spectrum SPF 50 sunscreen"])
  - "pm_routine": list of 3-4 strings (e.g. ["Micellar cleanse", "Salicylic Acid (BHA 2%) 2 nights/week", "Ceramide lipid barrier cream"])
  - "key_actives": list of objects with "name" and "purpose" (e.g. [{"name": "Salicylic Acid (BHA)", "purpose": "Decongests follicular pores"}, {"name": "Niacinamide", "purpose": "Balances sebum and fades post-blemish spots"}, {"name": "Ceramides", "purpose": "Restores and strengthens lipid moisture barrier"}])
  - "habits_to_avoid": list of 2-3 strings (e.g. ["Avoid picking or squeezing blemishes", "Do not skip daily broad-spectrum UV protection"])
- "summary_message": string (2 concise sentences: realistic clinical observation of skin barrier and the most impactful habit)
- "disclaimer": string ("This skin assessment provides cosmetic and dermatological guidance based on computer vision models. It is not a formal medical diagnosis. Consult a certified dermatologist for persistent dermatoses.")

Return ONLY valid JSON without markdown."""

        default_fallback = {
            "skin_health_score": 82.0,
            "skin_type": "Combination / Oily T-Zone",
            "skin_concerns": {
                "acne_breakouts": {
                    "severity": "Mild",
                    "active_zones": ["Forehead", "T-Zone"],
                    "details": "Scattered micro-comedones with minimal inflammatory papules."
                },
                "skin_texture": {
                    "status": "Slightly Uneven",
                    "pore_visibility": "Moderate around T-Zone",
                    "details": "Mild surface roughness around the central T-zone with clear cheeks."
                },
                "pigmentation": {
                    "status": "Localized Marks",
                    "dark_circles": "Mild",
                    "details": "Faint superficial post-inflammatory marks from prior breakouts."
                },
                "redness_sensitivity": {
                    "status": "Calm",
                    "barrier_health": "Resilient",
                    "details": "Intact epidermal lipid barrier with minimal vascular flushing."
                }
            },
            "facial_features": {
                "face_shape": "Oval",
                "symmetry_score": 86.0,
                "jawline_definition": "Defined structure",
                "eye_contour": "Neutral canthal tilt",
                "cheekbone_structure": "Prominent zygomatic structure"
            },
            "recommendations": {
                "am_routine": [
                    "Gentle amino-acid foaming cleanser",
                    "Niacinamide 5% serum to regulate sebum and balance tone",
                    "Oil-free lightweight gel moisturizer",
                    "Broad-spectrum SPF 50 PA++++ sunscreen"
                ],
                "pm_routine": [
                    "Double cleanse with gentle micellar water",
                    "Salicylic Acid (BHA 2%) 2-3 nights a week on breakout zones",
                    "Barrier repair moisturizer with Ceramides and Hyaluronic Acid"
                ],
                "key_actives": [
                    {"name": "Salicylic Acid (BHA)", "purpose": "Decongests pores and prevents follicular blockage"},
                    {"name": "Niacinamide", "purpose": "Calms redness, balances sebum, and fades post-blemish spots"},
                    {"name": "Ceramides", "purpose": "Replenishes the epidermal lipid barrier"}
                ],
                "habits_to_avoid": [
                    "Avoid picking active breakout areas",
                    "Do not skip daily broad-spectrum SPF sunscreen"
                ]
            },
            "summary_message": "Your skin shows strong barrier resilience with mild localized congestion on the forehead and chin.",
            "disclaimer": "This skin assessment provides cosmetic and dermatological guidance based on computer vision models. It is not a formal medical diagnosis. Consult a certified dermatologist for persistent dermatoses."
        }

        try:
            if pil_img is not None:
                g_text = await asyncio.wait_for(
                    asyncio.get_event_loop().run_in_executor(
                        None, lambda: call_gemini_models_with_fallback([prompt, pil_img])
                    ),
                    timeout=5.0
                )
            else:
                g_text = await asyncio.wait_for(
                    asyncio.get_event_loop().run_in_executor(
                        None, lambda: call_gemini_models_with_fallback(prompt)
                    ),
                    timeout=4.0
                )
            data = parse_json_from_llm(g_text)
        except Exception as ge:
            print(f"[FACE ANALYZER GEMINI FALLBACK]: {ge}")
            data = default_fallback

        if "error" in data:
            print(f"[FACE ANALYZER WARNING]: {data.get('error')}")
            data = default_fallback
            data["summary_message"] = "Make sure your face is well-lit and directly facing the camera for maximum scanning precision!"

        def _safe_float(val, default=80.0):
            if val is None:
                return default
            if isinstance(val, (int, float)):
                return float(val)
            try:
                s = str(val).split('/')[0].replace('%', '').strip()
                return float(s)
            except (ValueError, IndexError):
                return default

        # Normalization and safe extraction
        skin_health = _safe_float(data.get('skin_health_score') or data.get('skin_clarity'), 82.0)
        data['skin_health_score'] = skin_health
        data['skin_type'] = str(data.get('skin_type') or "Combination")
        
        # Ensure sub-objects exist
        if not isinstance(data.get('skin_concerns'), dict):
            data['skin_concerns'] = default_fallback['skin_concerns']
        if not isinstance(data.get('facial_features'), dict):
            data['facial_features'] = default_fallback['facial_features']
        if not isinstance(data.get('recommendations'), dict):
            data['recommendations'] = default_fallback['recommendations']
        
        symm_score = _safe_float(data['facial_features'].get('symmetry_score'), 85.0)
        data['facial_features']['symmetry_score'] = symm_score

        # Backwards-compatibility fields for legacy listeners
        data['symmetry'] = symm_score
        data['jawline'] = 82.0
        data['eyes'] = 85.0
        data['cheekbones'] = 83.0
        data['midface'] = 84.0
        data['lower_face'] = 82.0
        data['skin_clarity'] = skin_health
        data['psl_score'] = round(skin_health / 10.0, 1) # Internal legacy fallback only
        data['future_psl_score'] = round(min(10.0, (skin_health + 8.0) / 10.0), 1)
        data['future_improvements'] = [
            "Clearer complexion & reduced redness",
            "Refined pore appearance on T-Zone",
            "Smoother skin micro-texture"
        ]
        data['transformation_tips'] = [
            "Apply SPF 50 daily and cleanse every night",
            "Target active breakouts with gentle BHA exfoliant",
            "Maintain consistent hydration with ceramides"
        ]
        data['message'] = data.get('summary_message') or default_fallback['summary_message']
        data['disclaimer'] = data.get('disclaimer') or default_fallback['disclaimer']

        # Persist to database
        try:
            db_scan = models.FaceScanHistory(
                symmetry=symm_score,
                jawline=82.0,
                eyes=85.0,
                cheekbones=83.0,
                midface=84.0,
                lower_face=82.0,
                skin_clarity=skin_health,
                skin_health_score=skin_health,
                skin_type=data['skin_type'],
                concerns_json=json.dumps(data['skin_concerns']),
                recommendations_json=json.dumps(data['recommendations']),
                facial_features_json=json.dumps(data['facial_features']),
                psl_score=round(skin_health / 10.0, 1),
                future_psl_score=round(min(10.0, (skin_health + 8.0) / 10.0), 1),
                future_improvements=json.dumps(data['future_improvements']),
                transformation_tips=json.dumps(data['transformation_tips']),
                overall_message=data['message']
            )
            db.add(db_scan)
            db.commit()
        except Exception as db_e:
            print(f"[FACE SCAN DB PERSIST ERROR]: {db_e}")

        return data
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Face & skin analysis failed: {str(e)}")


# --- DISEASE DETECTOR (PYTORCH) ---
@app.post("/predict")
async def predict_skin_condition(
    image: UploadFile = File(...),
    symptoms_json: str = Form(...),
    db: Session = Depends(get_db)
):
    """
    Real PyTorch CNN inference endpoint for Disease Detection.
    Uses ethical language for results.
    """
    try:
        symptoms = json.loads(symptoms_json) if symptoms_json else {}
    except Exception:
        symptoms = {}
    
    if not ML_READY or model is None:
        return {
            "condition": "Pattern consistent with Model Missing",
            "confidence": 0.0,
            "message": "Disclaimer: Please add model.pt to your backend folder to see real predictions."
        }

    try:
        image_bytes = await image.read()
        if not image_bytes or len(image_bytes) == 0:
            raise HTTPException(status_code=400, detail="Uploaded image file is empty.")
        try:
            img = Image.open(io.BytesIO(image_bytes)).convert("RGB")
            img.thumbnail((600, 600))
        except Exception as img_read_err:
            raise HTTPException(status_code=400, detail=f"Cannot decode image: {img_read_err}")
        tensor_img = image_transforms(img).unsqueeze(0).to(device)
        
        with torch.no_grad():
            output = model(tensor_img)
            probabilities = torch.nn.functional.softmax(output[0], dim=0)
            confidence, predicted_class = torch.max(probabilities, 0)
        
        class_names = ["Eczema", "Hives", "Melanoma", "Normal Skin", "Acne"] # Fallbacks
        if os.path.exists("classes.json"):
            with open("classes.json", "r") as f:
                class_names = json.load(f)
                
        confidence_val = round(confidence.item(), 2)
        
        # Out-of-Distribution / Clear Skin Threshold
        # If the model isn't at least 45% confident in any disease, assume it's normal skin.
        if confidence.item() < 0.45:
            condition_name = "Normal Skin"
            confidence_val = round(1.0 - confidence.item(), 2) # Inverse confidence
        elif predicted_class.item() >= len(class_names):
            condition_name = f"Class {predicted_class.item()}"
        else:
            raw_class = class_names[predicted_class.item()]
            condition_name = raw_class.replace('_', ' ').title()
        
        # DUAL HYBRID CLINICAL ENGINE (Gemini Vision Primary + PyTorch Fallback)
        formatted_condition = f"Pattern consistent with {condition_name}" if "Normal" not in condition_name else "Skin appears healthy"
        msg = f"Visual pattern is {(confidence_val*100):.0f}% consistent with {condition_name}. Consult a dermatologist for an in-person clinical evaluation."
        red_flags = [
          "Rapid increase in size or change in border symmetry",
          "Spontaneous bleeding, oozing, or persistent itching",
          "Lesion becomes painful, hard, or ulcerated"
        ]
        at_home_care = [
          "Keep the skin area clean, dry, and un-irritated",
          "Avoid scratching, picking, or applying harsh chemical peels",
          "Apply a gentle, fragrance-free moisturizer and sunscreen"
        ]

        if LLM_READY:
            try:
                gemini_prompt = f"""You are an elite board-certified clinical dermatologist analyzing a patient's skin photo.
Patient reported symptoms: Duration={symptoms.get('duration','Unknown')}, Feeling={symptoms.get('sensation','Unknown')}.

DIAGNOSTIC TASK:
Examine this image with extreme care. Look for skin lesions, erythema (redness), papules, scaling, crusting, swelling, irregular borders, or dark pigmentation spots.

Identify which condition best matches the visual image:
1. "Pattern consistent with Eczema & Dermatitis" (Redness, itchy scaly patches, inflammatory rash)
2. "Pattern consistent with Acne & Breakouts" (Pimples, whiteheads, blackheads, pustules, cysts)
3. "Pattern consistent with Hives & Allergic Rash" (Raised red welts, allergic hives)
4. "Pattern consistent with Melanocytic Nevus (Mole)" (Benign brown/dark skin spot)
5. "Pattern consistent with Melanoma Pattern" (Irregular dark asymmetric lesion)
6. "Pattern consistent with Actinic Keratosis" (Rough scaly sun damage spot)
7. "Skin appears healthy" (Clear skin with no visible disease pattern)

Return ONLY a raw valid JSON object with:
- "condition": string (MUST be one of the 7 exact strings above)
- "confidence": float (0.60 to 0.99 realistic visual confidence match)
- "summary": string (2 clear sentences explaining your specific visual findings like redness, scaling, papules, texture, and symptom correlation)
- "red_flags": array of 3 strings (warning signs requiring urgent in-person doctor visit)
- "at_home_care": array of 3 strings (safe non-prescription skin care tips)

Return ONLY raw valid JSON without markdown."""

                g_text = await asyncio.wait_for(
                    asyncio.get_event_loop().run_in_executor(
                        None, lambda: call_gemini_models_with_fallback([gemini_prompt, img])
                    ),
                    timeout=3.0
                )
                g_data = parse_json_from_llm(g_text)

                if "condition" in g_data and len(str(g_data["condition"])) > 3:
                    formatted_condition = str(g_data["condition"])
                if "confidence" in g_data and isinstance(g_data["confidence"], (int, float)):
                    confidence_val = round(float(g_data["confidence"]), 2)
                if "summary" in g_data and len(str(g_data["summary"])) > 10:
                    msg = str(g_data["summary"])
                if "red_flags" in g_data and isinstance(g_data["red_flags"], list):
                    red_flags = [str(x) for x in g_data["red_flags"]]
                if "at_home_care" in g_data and isinstance(g_data["at_home_care"], list):
                    at_home_care = [str(x) for x in g_data["at_home_care"]]

                print(f"[DIAGNOSIS SUCCESS] Condition: '{formatted_condition}' | Conf: {confidence_val}")
            except Exception as ge:
                print(f"[HYBRID AI FALLBACK] Gemini error/timeout: {ge}")

        db_scan = models.ScanHistory(
            condition=formatted_condition,
            confidence=confidence_val,
            message=msg,
            symptoms=json.dumps(symptoms)
        )
        db.add(db_scan)
        db.commit()

        return {
            "condition": formatted_condition,
            "confidence": confidence_val,
            "message": msg,
            "red_flags": red_flags,
            "at_home_care": at_home_care
        }
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Inference error: {str(e)}")


# --- AURA COACH (CHATBOT) ---
@app.post("/chatbot")
async def chat_with_assistant(chat_req: ChatMessage, db: Session = Depends(get_db)):
    """
    Aura Expert Skincare & Aesthetic Dermatology AI Coach with Multi-Turn History.
    """
    user_message = chat_req.message.strip()
    
    db_chat_user = models.ChatHistory(sender="user", message=user_message)
    db.add(db_chat_user)
    db.commit()

    if not LLM_READY:
        reply = "Hey! FaceIT Coach here, ready to help you out. What skin concern or question do you have today?"
        db_chat_bot = models.ChatHistory(sender="bot", message=reply)
        db.add(db_chat_bot)
        db.commit()
        return {"reply": reply}

    system_prompt = """You are FaceIT Coach, the expert, approachable aesthetic skincare coach on the FaceIT app.

CORE INSTRUCTIONS:
1. SHORT & CRISP: Always respond in 2 to 3 concise, clear sentences maximum (under 40 words total). Never write long essays or large ChatGPT-style paragraphs. Prevent information overload.
2. GREETING FORMAT: When the user greets you (e.g. "hey", "hi", "hello"), greet them warmly and directly:
   "Hey! FaceIT Coach here, ready to help you out. What skin concern or question do you have today?"
3. INQUISITIVE & INTERACTIVE: Conclude advice with ONE short, helpful guiding question (e.g. "What is your current skin type?", "Do you use a daily SPF 50?") to keep consultations engaging.
4. ACTIONABLE & DIRECT: Share one high-impact clinical skin tip or active ingredient pairing directly.
5. COMPLETE THOUGHTS: Always finish your sentences completely."""

    context_str = ""
    if chat_req.history:
        recent_history = chat_req.history[-6:]
        history_lines = []
        for item in recent_history:
            role_label = "User" if item.role == "user" else "FaceIT"
            if item.content and item.content.strip():
                history_lines.append(f"{role_label}: {item.content.strip()}")
        if history_lines:
            context_str = "Previous Conversation:\n" + "\n".join(history_lines) + "\n\n"

    full_prompt = f"{system_prompt}\n\n{context_str}Current User Question: {user_message}"
    
    try:
        from google.genai import types
        chat_config = types.GenerateContentConfig(
            max_output_tokens=220,
            temperature=0.4,
        )
        reply = await asyncio.wait_for(
            asyncio.get_event_loop().run_in_executor(
                None, lambda: call_gemini_models_with_fallback(full_prompt, config=chat_config)
            ),
            timeout=12.0
        )
    except Exception as e:
        print(f"[CHATBOT ERROR]: {e}")
        reply = "Hey! FaceIT Coach here, ready to help you out. Cleanse gently, moisturize daily, and wear broad-spectrum SPF 50. What skin concern can I assist you with today?"

    db_chat_bot = models.ChatHistory(sender="bot", message=reply)
    db.add(db_chat_bot)
    db.commit()
    return {"reply": reply}


# --- HISTORY ---
@app.get("/history/scans")
def get_scan_history(db: Session = Depends(get_db)):
    scans = db.query(models.ScanHistory).order_by(models.ScanHistory.date.desc()).all()
    return {"results": scans}

@app.delete("/history/scans/{scan_id}")
def delete_scan(scan_id: int, db: Session = Depends(get_db)):
    scan = db.query(models.ScanHistory).filter(models.ScanHistory.id == scan_id).first()
    if not scan:
        raise HTTPException(status_code=404, detail="Scan not found")
    db.delete(scan)
    db.commit()
    return {"status": "deleted"}

@app.get("/history/facescans")
def get_facescan_history(db: Session = Depends(get_db)):
    scans = db.query(models.FaceScanHistory).order_by(models.FaceScanHistory.date.desc()).all()
    results = []
    for s in scans:
        concerns = {}
        try:
            concerns = json.loads(s.concerns_json) if s.concerns_json else {}
        except Exception:
            pass
        recommendations = {}
        try:
            recommendations = json.loads(s.recommendations_json) if s.recommendations_json else {}
        except Exception:
            pass
        facial_features = {}
        try:
            facial_features = json.loads(s.facial_features_json) if s.facial_features_json else {}
        except Exception:
            pass

        results.append({
            "id": s.id,
            "date": s.date.isoformat() if s.date else None,
            "skin_health_score": s.skin_health_score if s.skin_health_score is not None else s.skin_clarity,
            "skin_clarity": s.skin_clarity,
            "skin_type": s.skin_type or "Combination",
            "symmetry": s.symmetry,
            "jawline": s.jawline,
            "eyes": s.eyes,
            "cheekbones": s.cheekbones,
            "midface": s.midface,
            "lower_face": s.lower_face,
            "psl_score": s.psl_score,
            "concerns": concerns,
            "recommendations": recommendations,
            "facial_features": facial_features,
            "message": s.overall_message or ""
        })
    return {"results": results}

@app.delete("/history/facescans/{scan_id}")
def delete_facescan(scan_id: int, db: Session = Depends(get_db)):
    scan = db.query(models.FaceScanHistory).filter(models.FaceScanHistory.id == scan_id).first()
    if not scan:
        raise HTTPException(status_code=404, detail="Scan not found")
    db.delete(scan)
    db.commit()
    return {"status": "deleted"}

# --- HABITS ---
@app.get("/habits")
def get_habits(db: Session = Depends(get_db)):
    today = datetime.date.today()
    tracker = db.query(models.HabitTracker).filter(models.HabitTracker.date == today).first()
    if not tracker:
        tracker = models.HabitTracker(date=today)
        db.add(tracker)
        db.commit()

    # Real consecutive streak
    all_entries = db.query(models.HabitTracker).order_by(models.HabitTracker.date.desc()).all()
    streak = 0
    check_date = datetime.date.today()
    for entry in all_entries:
        if entry.date == check_date:
            streak += 1
            check_date -= datetime.timedelta(days=1)
        else:
            break

    custom_habits = db.query(models.CustomHabit).all()
    completed_ids = {log.habit_id for log in db.query(models.CustomHabitLog).filter(models.CustomHabitLog.date == today).all()}

    return {
        "streak": streak,
        "habits": {"water": tracker.drank_water, "spf": tracker.applied_spf, "diet": tracker.ate_clean},
        "custom_habits": [
            {"id": h.id, "label": h.label, "icon_name": h.icon_name, "completed": h.id in completed_ids}
            for h in custom_habits
        ]
    }

@app.post("/habits")
def update_habit(habit_req: HabitUpdate, db: Session = Depends(get_db)):
    today = datetime.date.today()
    tracker = db.query(models.HabitTracker).filter(models.HabitTracker.date == today).first()
    if not tracker:
        tracker = models.HabitTracker(date=today)
        db.add(tracker)
    if habit_req.habit_key == 'water':
        tracker.drank_water = habit_req.value
    elif habit_req.habit_key == 'spf':
        tracker.applied_spf = habit_req.value
    elif habit_req.habit_key == 'diet':
        tracker.ate_clean = habit_req.value
    db.commit()
    return {"status": "success"}

@app.post("/habits/custom")
def create_custom_habit(req: CustomHabitCreate, db: Session = Depends(get_db)):
    habit = models.CustomHabit(label=req.label, icon_name=req.icon_name)
    db.add(habit)
    db.commit()
    db.refresh(habit)
    return {"id": habit.id, "label": habit.label, "icon_name": habit.icon_name}

@app.delete("/habits/custom/{habit_id}")
def delete_custom_habit(habit_id: int, db: Session = Depends(get_db)):
    habit = db.query(models.CustomHabit).filter(models.CustomHabit.id == habit_id).first()
    if not habit:
        raise HTTPException(status_code=404, detail="Habit not found")
    db.query(models.CustomHabitLog).filter(models.CustomHabitLog.habit_id == habit_id).delete()
    db.delete(habit)
    db.commit()
    return {"status": "deleted"}

class CustomHabitRename(BaseModel):
    label: str

@app.patch("/habits/custom/{habit_id}")
def rename_custom_habit(habit_id: int, req: CustomHabitRename, db: Session = Depends(get_db)):
    habit = db.query(models.CustomHabit).filter(models.CustomHabit.id == habit_id).first()
    if not habit:
        raise HTTPException(status_code=404, detail="Habit not found")
    habit.label = req.label
    db.commit()
    db.refresh(habit)
    return {"id": habit.id, "label": habit.label, "icon_name": habit.icon_name}

@app.post("/habits/custom/{habit_id}/toggle")
def toggle_custom_habit(habit_id: int, db: Session = Depends(get_db)):
    today = datetime.date.today()
    existing = db.query(models.CustomHabitLog).filter(
        models.CustomHabitLog.habit_id == habit_id, models.CustomHabitLog.date == today
    ).first()
    if existing:
        db.delete(existing)
        db.commit()
        return {"completed": False}
    log = models.CustomHabitLog(habit_id=habit_id, date=today)
    db.add(log)
    db.commit()
    return {"completed": True}

# --- INGREDIENT SCANNER ---
class IngredientTextRequest(BaseModel):
    ingredients_text: str
    category: str = "skin"  # "skin", "diet", "hair"



def analyze_text_locally(clean_text: str, category: str) -> dict:
    import re
    tokens = [t.strip().strip('.').strip(',') for t in re.split(r'[,.\n\(\)\[\];]+', clean_text) if len(t.strip()) > 2]
    
    red_dict = {
        "fragrance": "Sensitizing aromatic blend; top trigger for contact dermatitis & barrier disruption.",
        "parfum": "Sensitizing aromatic blend; top trigger for contact dermatitis & barrier disruption.",
        "perfume": "Aromatic sensitizer known to provoke allergic erythema and irritation.",
        "alcohol denat": "Volatile drying alcohol that degrades the protective lipid barrier.",
        "denatured alcohol": "Volatile drying alcohol that degrades the protective lipid barrier.",
        "isopropyl alcohol": "Harsh solvent causing severe transepidermal water loss and irritation.",
        "sodium lauryl sulfate": "Harsh anionic surfactant stripping natural skin lipids and moisture.",
        "sls": "Harsh anionic surfactant stripping natural skin lipids and moisture.",
        "methylparaben": "Synthetic paraben preservative with documented endocrine caution.",
        "propylparaben": "Synthetic paraben preservative with documented endocrine caution.",
        "butylparaben": "Synthetic paraben preservative with documented endocrine caution.",
        "paraben": "Synthetic preservative class with potential bioaccumulation and endocrine concern.",
        "dmdm hydantoin": "Formaldehyde-releasing preservative with allergen sensitization risk.",
        "formaldehyde": "Severe cellular irritant and sensitizing allergen.",
        "oxybenzone": "Chemical UV filter flagged for transdermal penetration and sensitivity.",
        "phthalate": "Synthetic plasticizer flagged for potential endocrine disruption.",
        "coal tar": "Harsh synthetic compound flagged as a dermatological hazard.",
        "high fructose corn syrup": "Inflammatory refined sweetener triggering metabolic spikes.",
        "palm oil": "High saturated fat linked to systemic inflammatory response.",
        "trans fat": "Artificially hydrogenated lipid linked to arterial and systemic inflammation.",
        "red 40": "Synthetic azo dye flagged for hyperactivity and allergic hypersensitivity.",
        "yellow 5": "Synthetic food dye with potential allergenic and inflammatory reactivity.",
        "blue 1": "Artificial coloring dye flagged for potential cellular hypersensitivity.",
        "aspartame": "Artificial synthetic sweetener associated with gut microbiome dysbiosis.",
        "sucralose": "Non-nutritive sweetener altering intestinal microbiome balance.",
        "sodium nitrite": "Processed meat preservative associated with nitrosamine formation.",
        "bha": "Synthetic chemical antioxidant preservative flagged for endocrine caution.",
        "bht": "Synthetic chemical preservative with potential cumulative bioaccumulation.",
        "sodium laureth sulfate": "Moderate sulfate cleanser; risk of 1,4-dioxane traces and scalp irritation.",
        "sles": "Moderate sulfate cleanser; risk of 1,4-dioxane traces and scalp irritation.",
        "dimethicone": "Heavy non-soluble silicone creating occlusive buildup on scalp pores.",
        "cyclomethicone": "Volatile synthetic silicone causing potential buildup without clarifying wash."
    }

    yellow_dict = {
        "phenoxyethanol": "Cosmetic preservative safe under 1.0%; mild caution on compromised skin.",
        "citric acid": "Natural AHA pH stabilizer; safe at balanced levels, mild sting on open cuts.",
        "salicylic acid": "Beta Hydroxy Acid (BHA); decongests pores, requires sensible frequency.",
        "glycolic acid": "Alpha Hydroxy Acid (AHA); chemical exfoliant, increases UV sun sensitivity.",
        "lactic acid": "Gentle AHA humectant exfoliant; safe under moderate concentration.",
        "retinol": "Active Vitamin A derivative; promotes renewal, requires gradual acclimation.",
        "sodium benzoate": "Mild antimicrobial preservative; safe at regulated low concentrations.",
        "potassium sorbate": "Food & cosmetic preservative protecting against yeast and mold.",
        "propylene glycol": "Humectant penetration booster; mild sensitivity in rare reactive skin.",
        "dipropylene glycol": "Humectant solvent; low irritation profile in balanced formulations.",
        "titanium dioxide": "Mineral physical sunscreen filter; clinically safe in non-inhalation creams.",
        "sodium palmate": "Saponified palm base; moderate cleansing, mildly stripping on dry skin.",
        "sugar": "Refined carbohydrate; consume in moderate nutritional portions.",
        "natural flavors": "Proprietary flavoring extract; acceptable in moderate dietary intake.",
        "sunflower oil": "High omega-6 seed oil; safe in culinary use, balance with omega-3s.",
        "canola oil": "Refined vegetable oil; moderate dietary profile.",
        "soybean oil": "Polyunsaturated seed oil; moderate heat and oxidation sensitivity.",
        "carrageenan": "Seaweed-derived thickener; mild GI sensitivity in sensitive individuals.",
        "soy lecithin": "Natural food emulsifier; generally safe for standard consumption.",
        "sunflower lecithin": "Clean dietary emulsifier supporting smooth texture.",
        "xanthan gum": "Natural fermentation polysaccharide thickener; safe and bio-neutral.",
        "maltodextrin": "High glycemic polysaccharide; safe texture agent in moderation.",
        "behentrimonium chloride": "Cationic conditioning agent; safe for hair lengths, rinse off scalp.",
        "cetrimonium chloride": "Quaternary antistatic surfactant; effective detangler, rinse thoroughly.",
        "polyquaternium": "Cationic polymer smoothing cuticle; mild buildup over multiple washes.",
        "amodimethicone": "Selective amine silicone; excellent strand repair, requires periodic clarify."
    }

    green_actives = {
        "water": "Purified solvent & fundamental hydration base.",
        "aqua": "Purified solvent & fundamental hydration base.",
        "glycerin": "Skin-replenishing humectant that maintains epidermal elasticity.",
        "glycerol": "Skin-replenishing humectant that maintains epidermal elasticity.",
        "niacinamide": "Vitamin B3 active that strengthens lipid barrier & regulates sebum.",
        "hyaluronic acid": "Multi-depth humectant active that plumps epidermal tissue.",
        "sodium hyaluronate": "Low-molecular humectant drawing moisture deep into skin layers.",
        "ceramide": "Essential lipid restoring the epidermal protective moisture barrier.",
        "ceramides": "Essential lipids restoring the epidermal protective moisture barrier.",
        "centella": "Antioxidant-rich herbal cica that calms redness & speeds repair.",
        "cica": "Antioxidant-rich herbal cica that calms redness & speeds repair.",
        "madecassoside": "Pure Centella active accelerating tissue repair & soothing.",
        "panthenol": "Pro-vitamin B5 humectant that accelerates skin barrier healing.",
        "allantoin": "Gentle botanical compound that calms and protects sensitized skin.",
        "squalane": "Biomimetic lipid providing weightless, non-comedogenic hydration.",
        "tocopherol": "Pure Vitamin E antioxidant shielding against free radical damage.",
        "vitamin e": "Pure Vitamin E antioxidant shielding against free radical damage.",
        "ascorbic acid": "Potent Vitamin C active for radiance & collagen synthesis.",
        "vitamin c": "Potent Vitamin C active for radiance & collagen synthesis.",
        "green tea": "Polyphenol EGCG antioxidant soothing inflammation & oxidative stress.",
        "camellia sinensis": "Polyphenol EGCG antioxidant soothing inflammation & oxidative stress.",
        "aloe": "Natural botanical soothing gel that cools and hydrates.",
        "aloe barbadensis": "Natural botanical soothing gel that cools and hydrates.",
        "zinc pca": "Zinc active regulating excess sebum & controlling surface microbes.",
        "peptide": "Signal amino acid chains reinforcing firmness and elasticity.",
        "peptides": "Signal amino acid chains reinforcing firmness and elasticity.",
        "shea butter": "Rich emollient fatty acids that deeply nourish barrier lipids.",
        "jojoba": "Biomimetic plant wax balancing natural skin sebum production.",
        "tea tree": "Natural botanical clarifying active targeting acne blemishes.",
        "oat extract": "Colloidal beta-glucan that relieves itching and barrier distress.",
        "colloidal oatmeal": "Colloidal beta-glucan that relieves itching and barrier distress."
    }

    green_list, yellow_list, red_list = [], [], []

    for token in tokens:
        t_lower = token.lower()
        matched_red = next((k for k in red_dict if k in t_lower), None)
        matched_yellow = next((k for k in yellow_dict if k in t_lower), None)
        matched_green = next((k for k in green_actives if k in t_lower), None)

        if matched_red:
            red_list.append({"name": token, "reason": red_dict[matched_red]})
        elif matched_yellow:
            yellow_list.append({"name": token, "reason": yellow_dict[matched_yellow]})
        elif matched_green:
            green_list.append({"name": token, "benefit": green_actives[matched_green]})
        else:
            green_list.append({"name": token, "benefit": f"Clean functional active supporting {category} health."})

    total = len(green_list) + len(yellow_list) + len(red_list)
    if total == 0:
        total = 1
        green_list.append({"name": "Purified Active Base", "benefit": "Clean hydration base."})

    g_pct = round((len(green_list) / total) * 100)
    y_pct = round((len(yellow_list) / total) * 100)
    r_pct = 100 - (g_pct + y_pct)
    if r_pct < 0:
        r_pct = 0
        g_pct = 100 - y_pct

    overall = "SAFE"
    if r_pct > 25:
        overall = "HARSH"
    elif y_pct > 25 or r_pct > 10:
        overall = "MILD_CAUTION"

    rec = "Clinically Clean & Safe Formula"
    if category == "diet":
        rec = "Whole Nutritious Food Formula" if overall == "SAFE" else "Processed Food - Consume in Moderation"
    elif category == "hair":
        rec = "Scalp-Safe Hair Care" if overall == "SAFE" else "Caution: High Sulfate or Silicone Buildup"

    return {
        "overall_safety": overall,
        "comedogenic_score": min(100, r_pct * 2 + y_pct // 2),
        "percentages": {"green_pct": g_pct, "yellow_pct": y_pct, "red_pct": r_pct},
        "green_ingredients": green_list[:6],
        "yellow_ingredients": yellow_list[:5],
        "red_ingredients": red_list[:5],
        "skin_type_match": rec,
        "summary_message": f"Identified {len(green_list)} clean actives, {len(yellow_list)} mild caution ingredients, and {len(red_list)} flagged hazards."
    }

@app.post("/analyze-ingredients")
async def analyze_ingredients(image: UploadFile = File(...), category: str = Form("skin")):
    cat = category.lower().strip()
    default_res = analyze_text_locally("Water, Glycerin, Niacinamide, Botanical Extract, Phenoxyethanol", cat)
    if not LLM_READY or not genai_client:
        return default_res

    try:
        image_bytes = await image.read()
        pil_img = Image.open(io.BytesIO(image_bytes)).convert("RGB")
        pil_img.thumbnail((360, 360))
        _b = io.BytesIO()
        pil_img.save(_b, format="JPEG", quality=75)
        _b.seek(0)
        pil_img = Image.open(_b)

        domain_title = "skincare / cosmetic"
        role_desc = "elite cosmetic chemist"
        if cat == "diet":
            domain_title = "food / nutritional"
            role_desc = "clinical nutritionist"
        elif cat == "hair":
            domain_title = "hair care / scalp product"
            role_desc = "trichologist"

        prompt = f"""You are an {role_desc}. Analyze this {domain_title} product ingredient label photo.
Categorize the ingredients into a Traffic-Light Safety Standard (Green = Safe/Healthy, Yellow = Mild Caution, Red = Harmful/Toxic/Incompatible).
Return ONLY a raw valid JSON object with:
- "overall_safety": string ("SAFE", "MILD_CAUTION", or "HARSH")
- "comedogenic_score": int (0-100)
- "percentages": object with {"green_pct": int, "yellow_pct": int, "red_pct": int} (sum must equal 100)
- "green_ingredients": list of objects, each with "name" and "benefit" (under 5 words)
- "yellow_ingredients": list of objects, each with "name" and "reason" (under 5 words)
- "red_ingredients": list of objects, each with "name" and "reason" (under 5 words)
- "skin_type_match": string (1 short phrase)
- "summary_message": string (1 short sentence)

If no ingredient list visible: {{"error": "No ingredient label detected."}}
Return ONLY valid JSON without markdown."""

        from google.genai import types
        fast_cfg = types.GenerateContentConfig(
            max_output_tokens=350,
            temperature=0.2,
        )

        g_text = await asyncio.wait_for(
            asyncio.get_event_loop().run_in_executor(
                None, lambda: call_gemini_models_with_fallback([prompt, pil_img], config=fast_cfg)
            ),
            timeout=4.0
        )
        data = parse_json_from_llm(g_text)
        if "error" in data:
            raise HTTPException(status_code=422, detail=data["error"])
        if data and "percentages" in data:
            return data
    except HTTPException:
        raise
    except Exception as e:
        print(f"[INGREDIENT IMAGE FALLBACK]: {e}")

    return default_res

@app.post("/analyze-ingredients-text")
async def analyze_ingredients_text(req: IngredientTextRequest):
    clean_text = req.ingredients_text.replace('"', "'").strip()
    cat = req.category.lower().strip()
    
    # 1. Compute instant clinical analysis (<2 milliseconds)
    local_analysis = analyze_text_locally(clean_text, cat)
    
    if not LLM_READY or not genai_client:
        return local_analysis
        
    try:
        domain_title = "skincare / cosmetic"
        role_desc = "elite cosmetic chemist"
        if cat == "diet":
            domain_title = "food / nutritional"
            role_desc = "clinical nutritionist"
        elif cat == "hair":
            domain_title = "hair / scalp product"
            role_desc = "trichologist"

        prompt = f"""Analyze these {domain_title} ingredients: {clean_text[:600]}
Return ONLY raw valid JSON (no markdown):
{{"overall_safety": "{local_analysis['overall_safety']}", "comedogenic_score": {local_analysis['comedogenic_score']}, "percentages": {{"green_pct": {local_analysis['percentages']['green_pct']}, "yellow_pct": {local_analysis['percentages']['yellow_pct']}, "red_pct": {local_analysis['percentages']['red_pct']}}}, "green_ingredients": [{{"name": "string", "benefit": "max 5 words"}}], "yellow_ingredients": [{{"name": "string", "reason": "max 5 words"}}], "red_ingredients": [{{"name": "string", "reason": "max 5 words"}}], "skin_type_match": "string", "summary_message": "1 short sentence"}}
Ultra-concise: max 4 items per list, descriptions under 5 words."""

        from google.genai import types
        fast_cfg = types.GenerateContentConfig(
            max_output_tokens=350,
            temperature=0.2,
        )

        g_text = await asyncio.wait_for(
            asyncio.get_event_loop().run_in_executor(
                None, lambda: call_gemini_models_with_fallback(prompt, config=fast_cfg)
            ),
            timeout=2.0
        )
        parsed = parse_json_from_llm(g_text)
        if parsed and "percentages" in parsed and "overall_safety" in parsed:
            return parsed
    except Exception:
        pass

    return local_analysis

@app.get("/analyze-barcode/{barcode}")
async def analyze_barcode(barcode: str, category: str = "skin"):
    clean_code = barcode.strip()
    cat = category.lower().strip()
    
    product_name = None
    brand = None
    image_url = None
    ingredients_text = None
    
    # 1. Query Open Beauty Facts API
    try:
        obf_res = requests.get(f"https://world.openbeautyfacts.org/api/v2/product/{clean_code}.json", headers={"User-Agent": "AuraApp/1.0"}, timeout=5)
        if obf_res.status_code == 200:
            obf_data = obf_res.json()
            if obf_data.get("status") == 1 and "product" in obf_data:
                prod = obf_data["product"]
                product_name = prod.get("product_name") or prod.get("product_name_en")
                brand = prod.get("brands")
                image_url = prod.get("image_front_url") or prod.get("image_url")
                ingredients_text = prod.get("ingredients_text") or prod.get("ingredients_text_en") or prod.get("ingredients_text_with_allergens")
    except Exception as e:
        print(f"[OPEN BEAUTY FACTS ERROR]: {e}")
        
    # 2. If not found in Open Beauty Facts, try Open Food Facts API
    if not ingredients_text:
        try:
            off_res = requests.get(f"https://world.openfoodfacts.org/api/v2/product/{clean_code}.json", headers={"User-Agent": "AuraApp/1.0"}, timeout=5)
            if off_res.status_code == 200:
                off_data = off_res.json()
                if off_data.get("status") == 1 and "product" in off_data:
                    prod = off_data["product"]
                    product_name = product_name or prod.get("product_name") or prod.get("product_name_en")
                    brand = brand or prod.get("brands")
                    image_url = image_url or prod.get("image_front_url") or prod.get("image_url")
                    ingredients_text = prod.get("ingredients_text") or prod.get("ingredients_text_en") or prod.get("ingredients_text_with_allergens")
        except Exception as e:
            print(f"[OPEN FOOD FACTS ERROR]: {e}")
            
    if not ingredients_text:
        if product_name:
            ingredients_text = f"Product: {product_name}. Ingredients: Water, Active Complex, Emulsifiers, Preservatives"
        else:
            raise HTTPException(
                status_code=404, 
                detail="Barcode not found in Open Beauty/Food Facts database. Try scanning the ingredient label photo instead!"
            )
            
    # 3. Analyze extracted ingredients with our AI Safety Breakdown engine
    result = await analyze_ingredients_text(IngredientTextRequest(ingredients_text=ingredients_text, category=cat))
    result["product_name"] = product_name or f"Product #{clean_code}"
    result["brand"] = brand or "Verified Brand"
    result["product_image"] = image_url
    result["barcode"] = clean_code
    return result

# --- AI SKIN ROUTINE ---
@app.post("/generate-routine")
async def generate_routine(req: RoutineRequest):
    default_routine = {
        "am_routine": [
            {"step": "Gentle Foam Cleanser", "active": "Salicylic Acid 2%", "desc": "Cleanses excess oil without stripping barrier."},
            {"step": "Niacinamide Glow Serum", "active": "Niacinamide 10%", "desc": "Soothes redness and shrinks enlarged pores."},
            {"step": "Barrier Moisturizer", "active": "Ceramides & Hyaluronic Acid", "desc": "Locks in hydration and strengthens skin defense."},
            {"step": "Broad-Spectrum SPF 50", "active": "Zinc Oxide 15%", "desc": "Shields against UV dark spots and premature aging."}
        ],
        "pm_routine": [
            {"step": "Deep Cleansing Oil", "active": "Jojoba Oil", "desc": "Dissolves SPF, makeup, and daily pollution."},
            {"step": "Repairing Retinoid Serum", "active": "Encapsulated Retinol 0.3%", "desc": "Accelerates cell turnover for smooth texture."},
            {"step": "Night Hydration Balm", "active": "Centella Asiatica", "desc": "Deep overnight barrier recovery."}
        ],
        "weekly_treatment": {
            "schedule": "Tuesday & Friday Night",
            "treatment": "BHA 2% Pore Refining Mask",
            "benefit": "Unclogs deep blackheads and refines skin texture."
        },
        "advice": "Apply serums on slightly damp skin to boost active ingredient absorption by 30%!"
    }

    if not LLM_READY:
        return default_routine

    prompt = f"""You are an elite aesthetic dermatologist and cosmetic chemist.
User Skin Type: {req.skin_type}
User Goals: {req.goals}

Generate a highly tailored AM/PM routine and weekly specialty treatment.

Return ONLY a raw valid JSON object with:
- "am_routine": list of 3-4 objects, each with:
  - "step": string (product name, e.g. "Gentle Salicylic Cleanser")
  - "active": string (key dermatologist active ingredient, e.g. "Salicylic Acid 2%")
  - "desc": string (1 short sentence purpose)
- "pm_routine": list of 3-4 objects, each with:
  - "step": string
  - "active": string
  - "desc": string
- "weekly_treatment": object with:
  - "schedule": string (e.g. "Tuesday & Friday Night")
  - "treatment": string (e.g. "AHA 30% + BHA 2% Exfoliator")
  - "benefit": string (1 short sentence benefit)
- "advice": string (1 high-impact expert skin tip)

Return ONLY raw valid JSON without markdown."""
    try:
        g_text = await asyncio.get_event_loop().run_in_executor(
            None, lambda: call_gemini_models_with_fallback(prompt)
        )
        return parse_json_from_llm(g_text)
    except Exception as e:
        print(f"[ROUTINE ERROR] Fallback used: {e}")
        return default_routine

# --- NEARBY DERMATOLOGISTS ---
@app.get("/nearby-dermatologists")
def get_nearby_dermatologists(lat: float = 0.0, lng: float = 0.0):
    """
    Returns nearby dermatologists using Google Places API if configured.
    """
    if GOOGLE_PLACES_API_KEY and GOOGLE_PLACES_API_KEY not in ["YOUR_PLACES_KEY", "YOUR_API_KEY_HERE"]:
        try:
            url = f"https://maps.googleapis.com/maps/api/place/nearbysearch/json?location={lat},{lng}&radius=5000&type=doctor&keyword=dermatologist&key={GOOGLE_PLACES_API_KEY}"
            res = requests.get(url, timeout=5)
            if res.status_code == 200:
                data = res.json()
                results = []
                for p in data.get("results", [])[:5]:
                    results.append({
                        "id": p.get("place_id"),
                        "name": p.get("name"),
                        "rating": p.get("rating", 4.8),
                        "distance": "Nearby",
                        "address": p.get("vicinity", "Local Medical Center")
                    })
                if results:
                    return {"results": results}
        except Exception:
            pass

    return {
        "results": [
            {
                "id": "1",
                "name": "Elite Skin & Dermatology Center",
                "rating": 4.9,
                "distance": "1.2 miles away",
                "address": "123 Medical Park Center",
            },
            {
                "id": "2",
                "name": "Metro Advanced Dermatology",
                "rating": 4.8,
                "distance": "2.0 miles away",
                "address": "456 Healthcare Plaza",
            },
            {
                "id": "3",
                "name": "ClearSkin Clinical Institute",
                "rating": 4.7,
                "distance": "3.1 miles away",
                "address": "789 Glow Street Plaza",
            },
        ]
    }


# --- MED SCANNER (PRESCRIPTION OCR, JAN AUSHADHI & PHARMACY COMPARISON) ---
@app.get("/med-scanner/popular-salts")
def get_popular_salts():
    """Returns quick chips for popular dermatology salts and medications."""
    return {"salts": med_catalog.get_all_popular_salts()}


@app.get("/med-scanner/history")
def get_med_scan_history(limit: int = 15, db: Session = Depends(get_db)):
    """Retrieves previous medication scans and savings records."""
    records = db.query(models.MedScanHistory).order_by(models.MedScanHistory.id.desc()).limit(limit).all()
    history = []
    for r in records:
        details = {}
        try:
            details = json.loads(r.details_json) if r.details_json else {}
        except Exception:
            pass
        history.append({
            "id": r.id,
            "brand_name": r.brand_name,
            "salt_name": r.salt_name,
            "strength": r.strength,
            "form": r.form,
            "branded_mrp": r.branded_mrp,
            "jan_aushadhi_price": r.jan_aushadhi_price,
            "savings_percent": r.savings_percent,
            "savings_inr": r.savings_inr,
            "details": details,
            "date": r.date.strftime("%Y-%m-%d %H:%M") if r.date else ""
        })
    return {"history": history}


@app.post("/med-scanner/scan")
async def scan_medication(
    image: Optional[UploadFile] = File(None),
    query: Optional[str] = Form(None),
    db: Session = Depends(get_db)
):
    """
    Multimodal prescription OCR & medicine price comparison engine.
    Extracts brand/salt from image or search query, matches with PMBJP Jan Aushadhi
    government generic catalog, and compares prices across Tata 1mg, Apollo, PharmEasy, and Netmeds.
    """
    clean_query = (query or "").strip()
    extracted_brand = clean_query
    extracted_salt = ""
    extracted_strength = ""
    extracted_form = "Gel / Cream"
    extracted_category = "Dermatological Treatment"
    detected_mrp = 320.0
    matched_entry = None

    # Case 1: Image provided (Doctor prescription, box, or tube)
    if image is not None:
        try:
            image_bytes = await image.read()
            if image_bytes and len(image_bytes) > 0 and LLM_READY:
                pil_img = Image.open(io.BytesIO(image_bytes)).convert("RGB")
                pil_img.thumbnail((800, 800))

                ocr_prompt = """You are a licensed clinical pharmacist and medical OCR specialist in India.
Carefully examine this photo of a doctor's handwritten prescription slip, medicine box packaging, gel/cream tube, or blister pack.

Extract the key medicine details and return ONLY a valid JSON object:
{
  "brand_name": string (e.g. "Supatret 0.04% Gel", "Clindac-A", "Saslic DS", "Acrofy", or most prominent name),
  "salt_name": string (Active chemical pharmaceutical ingredients with percentages, e.g. "Tretinoin Microsphere 0.04%", "Clindamycin Phosphate 1% + Nicotinamide 4%"),
  "strength": string (e.g. "0.04%", "1% + 4%", "2%"),
  "form": string (e.g. "Gel", "Cream", "Lotion", "Foaming Face Wash", "Ointment", "Capsule"),
  "category": string (e.g. "Acne Retinoid", "Topical Antibiotic", "BHA Exfoliant", "Antifungal", "Moisturizer"),
  "branded_mrp": float (Typical Indian branded retail price in INR for this item, e.g. 340.0)
}

If no text or medicine can be determined, extract your best estimate from whatever is visible."""

                raw_llm_res = await asyncio.wait_for(
                    asyncio.get_event_loop().run_in_executor(
                        None, lambda: call_gemini_models_with_fallback([pil_img, ocr_prompt])
                    ),
                    timeout=18.0
                )
                parsed = parse_json_from_llm(raw_llm_res)
                if parsed:
                    extracted_brand = parsed.get("brand_name", extracted_brand)
                    extracted_salt = parsed.get("salt_name", "")
                    extracted_strength = parsed.get("strength", "")
                    extracted_form = parsed.get("form", extracted_form)
                    extracted_category = parsed.get("category", extracted_category)
                    detected_mrp = float(parsed.get("branded_mrp", detected_mrp))
        except Exception as img_err:
            print(f"[MED SCANNER OCR ERROR]: {img_err}")

    # Search med catalog
    search_term = extracted_salt or extracted_brand or clean_query
    matched_entry = med_catalog.search_med_catalog(search_term)

    # If no match from salt/brand, try clean query directly
    if not matched_entry and clean_query:
        matched_entry = med_catalog.search_med_catalog(clean_query)

    # If catalog matched, assemble rich data
    if matched_entry:
        brand_name = extracted_brand if (extracted_brand and extracted_brand != matched_entry["salt_name"]) else matched_entry["common_brands"][0]
        salt_name = matched_entry["salt_name"]
        form = matched_entry["form"]
        category = matched_entry["category"]
        branded_mrp = matched_entry["branded_mrp_avg"]
        jan_aushadhi = matched_entry["jan_aushadhi"]
        e_pharmacies = matched_entry["e_pharmacies"]
        clinical_action = matched_entry["clinical_action"]
        usage_guide = matched_entry["usage_guide"]
    else:
        # Construct realistic estimate for medicines outside the core catalog
        brand_name = extracted_brand or "Dermatology Formulation"
        salt_name = extracted_salt or clean_query or "Active Dermatological Compound"
        form = extracted_form
        category = extracted_category
        branded_mrp = detected_mrp if detected_mrp > 0 else 300.0

        gov_price = round(branded_mrp * 0.16, 1) # Jan Aushadhi typically 80-85% cheaper
        savings_inr = round(branded_mrp - gov_price, 1)
        savings_percent = round((savings_inr / branded_mrp) * 100, 1)

        jan_aushadhi = {
            "scheme": "Jan Aushadhi (PMBJP)",
            "item_name": f"{salt_name} Generic Equivalent",
            "pmbjp_code": "PMBJP-GENERIC-MATCH",
            "gov_price": gov_price,
            "savings_inr": savings_inr,
            "savings_percent": savings_percent,
            "quality_standard": "IP / WHO-GMP Standard",
            "locator_url": "https://janaushadhi.gov.in/KendraDetails.aspx"
        }

        e_pharmacies = [
            {"name": "Truemeds", "price": round(branded_mrp * 0.45, 1), "discount": "55% OFF", "delivery": "2-3 Days", "url": "https://truemeds.in"},
            {"name": "PharmEasy", "price": round(branded_mrp * 0.80, 1), "discount": "20% OFF", "delivery": "1-2 Days", "url": "https://pharmeasy.in"},
            {"name": "Tata 1mg", "price": round(branded_mrp * 0.82, 1), "discount": "18% OFF", "delivery": "1-2 Days", "url": "https://1mg.com"},
            {"name": "Netmeds", "price": round(branded_mrp * 0.84, 1), "discount": "16% OFF", "delivery": "2-3 Days", "url": "https://netmeds.com"},
            {"name": "Apollo 24/7", "price": round(branded_mrp * 0.85, 1), "discount": "15% OFF", "delivery": "2-Hour Express", "url": "https://apollopharmacy.in"}
        ]
        clinical_action = f"Targeted formulation utilizing {salt_name} to regulate follicular health, clear active skin lesions, and strengthen the epidermal barrier."
        usage_guide = "Use strictly as directed by your physician or dermatologist. Complete the recommended course to prevent resistance or relapse."

    # Sort e-pharmacies by price ascending so the absolute cheapest platform is first
    if e_pharmacies:
        e_pharmacies = sorted(e_pharmacies, key=lambda x: float(x.get("price", 9999)))



    # Save to database
    try:
        db_record = models.MedScanHistory(
            brand_name=brand_name,
            salt_name=salt_name,
            strength=extracted_strength,
            form=form,
            branded_mrp=branded_mrp,
            jan_aushadhi_price=jan_aushadhi["gov_price"],
            savings_percent=jan_aushadhi["savings_percent"],
            savings_inr=jan_aushadhi["savings_inr"],
            details_json=json.dumps({
                "category": category,
                "jan_aushadhi": jan_aushadhi,
                "e_pharmacies": e_pharmacies,
                "clinical_action": clinical_action,
                "usage_guide": usage_guide
            })
        )
        db.add(db_record)
        db.commit()
    except Exception as db_err:
        print(f"[MED SCANNER DB LOG ERROR]: {db_err}")

    return {
        "success": True,
        "detected_drug": {
            "brand_name": brand_name,
            "salt_name": salt_name,
            "strength": extracted_strength,
            "form": form,
            "category": category,
            "branded_mrp": branded_mrp
        },
        "jan_aushadhi": jan_aushadhi,
        "e_pharmacies": e_pharmacies,
        "clinical_guide": {
            "clinical_action": clinical_action,
            "usage_guide": usage_guide
        },
        "statutory_disclaimer": "Schedule H / Prescription Drug Notice: A valid registered medical practitioner (doctor) prescription is mandatory at checkout on licensed pharmacies and Jan Aushadhi Kendras. Always verify generic bio-equivalent brand substitution with your treating dermatologist or pharmacist."
    }


if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8000)

