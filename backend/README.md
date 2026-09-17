# 🧠 Aura Intelligence Engine (FastAPI Backend)

[![Python](https://img.shields.io/badge/Python-3.11+-3776AB?logo=python&logoColor=white)](https://python.org)
[![FastAPI](https://img.shields.io/badge/FastAPI-0.110+-009688?logo=fastapi&logoColor=white)](https://fastapi.tiangolo.com)
[![PyTorch](https://img.shields.io/badge/PyTorch-2.x-EE4C2C?logo=pytorch&logoColor=white)](https://pytorch.org)
[![Gemini](https://img.shields.io/badge/Google%20Gemini-Flash%20Vision-4285F4?logo=google&logoColor=white)](https://ai.google.dev)

The high-throughput AI microservice powering **AURA**. Combines deep learning computer vision, multimodal generative models, and asynchronous external product APIs.

---

## ⚡ API Endpoints

| Method | Endpoint | Description |
| :--- | :--- | :--- |
| `POST` | `/analyze` | Hybrid disease classification (PyTorch CNN + Gemini Vision fallback). |
| `POST` | `/analyze-face` | Facial symmetry, gonial angle, and 90-day aesthetic projection. |
| `POST` | `/scan-ingredients` | Barcode lookup (Open Beauty Facts) and OCR hazard categorization. |
| `POST` | `/chatbot` | Aura Coach conversational assistance (<40 words per reply). |
| `GET` | `/streak` | Daily habit tracker & streak status. |
| `POST` | `/streak/complete` | Mark daily habit completion. |
| `GET` | `/dermatologists` | Geo-ranked list of certified clinics. |
| `GET` | `/health` | Service liveness & database status. |

---

## 🛠️ Tech Architecture

- **Web Framework**: FastAPI with ASGI Uvicorn
- **Database**: SQLite with Write-Ahead Logging (WAL) mode for concurrency
- **Deep Learning**: PyTorch (`torch`, `torchvision`) for local lesion inference
- **Generative AI**: Google Gemini 2.5 Flash Vision via `google-genai`
- **Data Schemas**: Pydantic v2 with strict payload validation

---

## 🚀 Setup & Execution

```bash
# 1. Activate virtual environment
python -m venv venv
.\venv\Scripts\activate   # Windows
source venv/bin/activate  # macOS/Linux

# 2. Install requirements
pip install -r requirements.txt

# 3. Configure credentials
cp .env.example .env
# Set GEMINI_API_KEY in .env

# 4. Run API server
uvicorn main:app --host 0.0.0.0 --port 8000 --reload
```

Interactive API documentation available at `http://localhost:8000/docs`.
