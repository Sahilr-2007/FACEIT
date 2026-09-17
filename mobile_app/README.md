# 📱 Aura Mobile Client (Flutter)

[![Flutter](https://img.shields.io/badge/Flutter-3.x-02569B?logo=flutter&logoColor=white)](https://flutter.dev)
[![Dart](https://img.shields.io/badge/Dart-3.x-0175C2?logo=dart&logoColor=white)](https://dart.dev)
[![Platform](https://img.shields.io/badge/Platform-Android%20%7C%20iOS-black)](#)

The cross-platform client application for **AURA**, built with Flutter. Engineered with an OLED dark aesthetic, fluid micro-animations, and offline state management.

---

## 📱 Features

- **Facial Analyzer**: Bilateral symmetry evaluation, jawline gonial angle calculation, and 90-day progress forecasting.
- **Lesion Scanner**: Real-time camera capture with dual-engine clinical differential output.
- **Toxicity OCR & Barcode Scanner**: Scans ingredients with high-contrast safety tiers and instant **Clinical PDF Export**.
- **Aura Mascot & Streak Engine**: Dynamic meditative mascot driven by streak preservation psychology.
- **Aura AI Coach**: Low-latency conversational concierge for routine checks and ingredient queries.
- **Clinic Radar**: Geo-proximity dermatologist directory.

---

## 🛠️ Architecture & State

- **UI Framework**: Flutter (Material 3 with bespoke Dark Theme)
- **Animation Engine**: Lottie + Flutter Canvas
- **Networking**: `http` with auto-fallback configuration in [`lib/config.dart`](lib/config.dart)
- **Reporting**: `pdf` & `printing` for on-device clinical report generation
- **State Management**: Reactive state models with local SQLite caching

---

## 🚀 Running the App

```bash
# 1. Install dependencies
flutter pub get

# 2. Verify connected devices
flutter devices

# 3. Launch in debug mode
flutter run
```

> **Backend Connection**: Configure your backend endpoint in [`lib/config.dart`](lib/config.dart). When using Ngrok or a local network, update `backendUrl` accordingly.
