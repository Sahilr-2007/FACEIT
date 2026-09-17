# FaceIt (AURA)

An AI-powered skincare and facial analysis application built with **Flutter** and **FastAPI**. It combines an offline **PyTorch CNN** and **Google Gemini Vision** to detect skin conditions, analyze facial symmetry, scan cosmetic product ingredients for harmful chemicals, and generate personalized skincare routines.

---

## Features

- **Skin Disease & Lesion Detection**: Identifies skin conditions (acne, eczema, psoriasis, etc.) using a local PyTorch CNN classifier with Google Gemini 2.5 Flash Vision for clinical differential analysis.
- **Facial Geometry & Symmetry Analysis**: Evaluates bilateral facial symmetry, jawline angle, canthal tilt, and skin texture with a structured 90-day progress plan.
- **Ingredient & Toxicity Scanner**: Scans product barcodes (via Open Beauty Facts) or extracts raw text from ingredient labels via OCR. Flags comedogenic ingredients, allergens, and carcinogens with one-tap **Clinical PDF Export**.
- **Aura AI Coach**: Quick, conversational chatbot for answering skincare questions, checking routine conflicts, and validating products.
- **Habit & Streak Tracker**: Daily morning and evening routine tracker with habit streak tracking backed by SQLite (WAL mode).
- **Dermatologist Finder**: Locates nearby board-certified dermatologists and skincare clinics.

---

## Tech Stack

| Layer | Technology |
|---|---|
| **Mobile Client** | Flutter 3.x, Dart, Material 3, Lottie, PDF Generation |
| **Backend API** | FastAPI, Python 3.11, Uvicorn, SQLAlchemy |
| **Machine Learning** | PyTorch 2.x, Torchvision, NumPy, PIL |
| **Generative Vision** | Google Gemini 2.5 Flash Vision (`google-genai`) |
| **Database** | SQLite (WAL mode) |
| **External APIs** | Open Beauty Facts API (Barcode scanning) |

---

## Project Structure

```
FACEIT/
├── backend/
│   ├── main.py              # FastAPI server, endpoints, and ML inference pipeline
│   ├── models/              # PyTorch model weights
│   ├── requirements.txt     # Python backend dependencies
│   └── .env.example         # Environment variable template
├── mobile_app/
│   ├── lib/
│   │   ├── main.dart        # Flutter entrypoint & theme
│   │   ├── config.dart      # Backend URL & API routes
│   │   ├── screens/         # UI screens (Analyzer, Scanner, Chatbot, Streak)
│   │   └── widgets/         # Custom widgets
│   └── pubspec.yaml         # Flutter dependencies
├── launch_aura_project.bat  # Automated startup script for Windows
└── README.md
```

---

## Getting Started

### Prerequisites

- [Flutter SDK](https://docs.flutter.dev/get-started/install) (3.19+)
- [Python](https://www.python.org/downloads/) (3.10+)
- [Google Gemini API Key](https://aistudio.google.com/)

---

### 1. Backend Setup

```bash
cd backend

# Create and activate virtual environment
python -m venv venv

# Windows
.\venv\Scripts\activate
# macOS/Linux
source venv/bin/activate

# Install dependencies
pip install -r requirements.txt

# Configure environment
cp .env.example .env
# Edit .env and set your GEMINI_API_KEY:
# GEMINI_API_KEY=your_actual_api_key_here

# Start the server
uvicorn main:app --host 0.0.0.0 --port 8000 --reload
```

Backend will run at `http://localhost:8000`. Swagger API docs available at `http://localhost:8000/docs`.

---

### 2. Mobile App Setup

```bash
cd mobile_app

# Install dependencies
flutter pub get

# Run on connected device or emulator
flutter run
```

> **Note**: Update `backendUrl` in [`mobile_app/lib/config.dart`](mobile_app/lib/config.dart) with your local machine's IP or tunnel URL (e.g., Ngrok) if testing on a physical phone.

---

## Core API Endpoints

| Method | Endpoint | Description |
|---|---|---|
| `POST` | `/analyze` | Analyze skin lesion image (PyTorch + Gemini fallback) |
| `POST` | `/analyze-face` | Analyze facial symmetry, jawline angle & skin quality |
| `POST` | `/scan-ingredients` | Barcode lookup & OCR hazard tier analysis |
| `POST` | `/chatbot` | Skincare consultation assistant |
| `GET` | `/streak` | Fetch current streak and routine completion status |
| `POST` | `/streak/complete` | Mark daily routine step completed |
| `GET` | `/dermatologists` | Get nearby dermatologist clinics |
| `GET` | `/health` | Health check endpoint |

---

## Environment Variables

Create a `backend/.env` file with the following:

```env
GEMINI_API_KEY=your_google_gemini_api_key
```

---

## Medical Disclaimer

FaceIt (AURA) is an educational and cosmetic decision-support tool. It does not provide medical diagnosis or replace consultation with a certified dermatologist or healthcare professional.

---

## License

This project is proprietary and intended for technical demonstration and evaluation purposes.
