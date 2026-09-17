<div align="center">

# 🌿 A U R A
### Clinical-Grade AI Dermatology & Aesthetic Skincare Intelligence
**Smart India Hackathon (SIH 2026) Shortlisted Innovation**

[![Flutter](https://img.shields.io/badge/Flutter-3.x-02569B?style=for-the-badge&logo=flutter&logoColor=white)](https://flutter.dev)
[![FastAPI](https://img.shields.io/badge/FastAPI-0.110+-009688?style=for-the-badge&logo=fastapi&logoColor=white)](https://fastapi.tiangolo.com)
[![PyTorch](https://img.shields.io/badge/PyTorch-2.x-EE4C2C?style=for-the-badge&logo=pytorch&logoColor=white)](https://pytorch.org)
[![Gemini](https://img.shields.io/badge/Google%20Gemini-Flash%20Vision-4285F4?style=for-the-badge&logo=google&logoColor=white)](https://ai.google.dev)
[![Platform](https://img.shields.io/badge/Platform-Android%20%7C%20iOS-black?style=for-the-badge)](#)
[![License](https://img.shields.io/badge/License-Proprietary-red?style=for-the-badge)](#)

<br/>

<p align="center">
  <b>Aura</b> is an end-to-end intelligent dermatology ecosystem that unites clinical diagnostics with aesthetic facial wellness. By pairing an on-device/offline PyTorch CNN with Google Gemini 2.5 Flash Vision, Aura delivers sub-1.5s lesion triage, mathematical facial symmetry scoring, Yuka-style barcode & label toxicity audits, and personalized 90-day progress roadmaps.
</p>

[Key Features](#-key-features) • [System Architecture](#-system-architecture) • [Tech Stack](#-tech-stack) • [Quick Start](#-quick-start) • [Security & Ethics](#-security--ethics)

</div>

---

## ⚡ Highlights

- **Dual-Engine Lesion Diagnostic**: Hybrid CNN + Multimodal Vision for reliable skin condition classification with clinical confidence scoring, differential alerts, and barrier-repair routines.
- **Mathematical Facial Analysis**: Evaluates bilateral symmetry, jawline gonial angle, canthal tilt, and skin texture quality with a personalized 90-day aesthetic improvement projection.
- **Toxicity & Ingredient Scanner**: Barcode scanning (2.5M+ products via Open Beauty Facts) + Optical Character Recognition for raw ingredient lists, categorized into Green/Yellow/Red hazard tiers with **one-tap Clinical PDF export**.
- **Concierge Aura Coach**: High-impact, concise AI dermatologist assistant (<40 words per reply) designed for fast, actionable advice without information fatigue.
- **Loss-Aversion Habit Engine**: Gamified routine compliance backed by SQLite WAL mode and a dynamic mascot that visually reflects streak health.
- **Dermatologist Radar**: Instant geo-proximity directory for connecting users directly to certified local practitioners.

---

## 🧩 Key Modules

| Module | Engine / Pipeline | Capability & Output |
| :--- | :--- | :--- |
| **Lesion Triage** | PyTorch CNN + Gemini 2.5 Vision | Primary diagnosis, confidence rating, differential diagnoses, warning signs, and home care protocols. |
| **Facial & Aesthetic** | Gemini 2.5 Flash Vision | Quantitative symmetry, eye angle, jawline definition, plus 90-day progressive milestone forecasting. |
| **Ingredient Scanner** | Open Beauty Facts + Gemini OCR | Comedogenic rating, allergen flags, carcinogen screening, and shareable PDF assessment report. |
| **Aura AI Coach** | Tuned Concierge LLM | Receptionist-style assistant for quick routine validation, product conflicts, and ingredient advice. |
| **Habit & Streak System** | Local SQLite (WAL) + Lottie | Gamified habit loop with streak preservation cues to boost long-term treatment adherence. |
| **Clinic Locator** | Geo-Index & Places API | Proximity-ranked directory of verified dermatologists and specialized skincare clinics. |

---

## 🏗️ System Architecture

```
                      ┌─────────────────────────────────────────┐
                      │        AURA CLIENT (Flutter / Dart)     │
                      │  • Material 3 Dark OLED    • Lottie FX  │
                      │  • Offline State Cache     • PDF Engine │
                      └────────────────────┬────────────────────┘
                                           │  HTTPS / REST / JSON
                                           ▼
                      ┌─────────────────────────────────────────┐
                      │         AURA BACKEND (FastAPI / Py3)    │
                      │  • Async Pipelines   • SQLite (WAL Mode)│
                      │  • In-Memory Vision  • Schema Validation│
                      └──────────────┬──────────────────┬───────┘
                                     │                  │
         ┌───────────────────────────┴───┐          ┌───┴───────────────────────────┐
         ▼                               ▼          ▼                               ▼
┌──────────────────┐           ┌──────────────────┐ ┌──────────────────┐  ┌──────────────────┐
│  PyTorch CNN     │           │  Gemini 2.5      │ │ Open Beauty      │  │ Geo Proximity    │
│  Deep Learning   │           │  Flash Vision    │ │ Facts API        │  │ Provider Index   │
│ (Lesion Pattern) │           │ (Aesthetics/OCR) │ │(2.5M+ Barcodes)  │  │(Clinic Mapping)  │
└──────────────────┘           └──────────────────┘ └──────────────────┘  └──────────────────┘
```

---

## 🛠️ Tech Stack

```
Mobile Client      Flutter 3.x • Dart • Provider • Lottie • PDF & Share Plus
API & Services     Python 3.11 • FastAPI • Uvicorn • SQLAlchemy • SQLite WAL
Artificial Intel   PyTorch 2.x (CNN Classifier) • Google Gemini 2.5 Flash Vision
Infrastructure     Ngrok Tunneling • RESTful JSON API • AsyncIO
```

---

## 📂 Repository Layout

```
FACEIT/
├── backend/                  # FastAPI AI Microservice
│   ├── main.py               # Core REST endpoints & AI pipelines
│   ├── models/               # PyTorch classification models
│   ├── requirements.txt      # Python dependencies
│   └── .env.example          # Environment variable template
├── mobile_app/               # Cross-Platform Flutter Client
│   ├── lib/
│   │   ├── main.dart         # Entry point & app theme
│   │   ├── config.dart       # API endpoint configuration
│   │   ├── screens/          # Core screens (Analyzer, Scanner, Coach, etc.)
│   │   └── widgets/          # Reusable UI components & Aura mascot
│   └── pubspec.yaml          # Flutter package dependencies
├── launch_aura_project.bat   # One-click startup script (Backend + Tunnel)
└── README.md                 # Project documentation
```

---

## 🚀 Quick Start

### 1. Backend Setup
```bash
cd backend

# Create virtual environment
python -m venv venv
# Windows:
.\venv\Scripts\activate
# Linux/macOS:
source venv/bin/activate

# Install dependencies
pip install -r requirements.txt

# Configure environment keys
cp .env.example .env
# Edit .env and supply your GEMINI_API_KEY

# Run development server
uvicorn main:app --host 0.0.0.0 --port 8000 --reload
```

### 2. Mobile App Setup
```bash
cd mobile_app

# Install Flutter dependencies
flutter pub get

# Launch on connected device or emulator
flutter run
```

> **Automated Launch**: On Windows, double-click `launch_aura_project.bat` to automatically spin up the FastAPI service and cloud tunnel in parallel.

---

## 🔒 Security, Privacy & Clinical Ethics

- **Zero-Persistence Biometrics**: Facial selfies and medical photos are processed in memory and never stored in plain-text or transferred to external analytics platforms.
- **Clinical Decision Support (CDS)**: Aura is designed to supplement, not replace, certified professional medical judgment. Lesion analyses include automatic escalation notices for malignant patterns.

---

## 👥 Team & Credentials

- **Project**: AURA (Faceit)
- **Competition**: Smart India Hackathon (SIH 2026)
- **Repository**: [Sahilr-2007/FACEIT](https://github.com/Sahilr-2007/FACEIT)
- **Lead Developer**: Sahil Raut ([@Sahilr-2007](https://github.com/Sahilr-2007))

---

<div align="center">
  <sub>Built with precision for Smart India Hackathon 2026. All rights reserved.</sub>
</div>
