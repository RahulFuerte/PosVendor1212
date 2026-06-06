# Billing Sphere — POS App

A full-featured Point of Sale (POS) Android application built with Flutter.

---

## About

**Billing Sphere** is a modern POS app designed for small to medium businesses. It handles sales, inventory, customer management, billing, barcode scanning, Bluetooth printing, and more — all from a single Android device.

- **Package ID:** `com.fuertedevelopers.pos`
- **Platform:** Android (minSdk 24 / targetSdk 36)
- **Built with:** Flutter 3.44.1 / Dart 3.12.0

---

## Features

- Dashboard with sales charts and analytics
- Product & inventory management
- Customer management
- Barcode / QR code scanner
- Bluetooth thermal printer support
- PDF receipt generation & sharing
- Multi-language support (10 languages)
- Text-to-speech order confirmation
- Geolocation support
- Subscription management
- In-app guided tour (25 steps)
- Google Fonts + adaptive app icon

---

## Tech Stack

| Area | Package |
|---|---|
| State management | Provider |
| Charts | fl_chart 1.2 |
| Barcode scanner | mobile_scanner 7.2 |
| Bluetooth printing | flutter_pos_printer_platform_image_3 |
| PDF | pdf + printing |
| File sharing | share_plus 10 |
| Localization | flutter_localization 0.4 |
| Image handling | image_cropper 12 + cached_network_image |
| Audio | audioplayers 6 + flutter_tts 4 |
| Storage | shared_preferences |
| Fonts | google_fonts 8 |

---

## Getting Started

### Prerequisites

- Flutter 3.44.1 (stable channel)
- Android Studio / VS Code
- Android device or emulator (API 24+)

### Setup

```bash
# Clone the repo
git clone https://github.com/RahulFuerte/-Billing-Sphere.git
cd -Billing-Sphere

# Install dependencies
flutter pub get

# Run on connected device
flutter run
```

### Build Release APK

```bash
flutter build apk --release
```

> Release signing is configured. Keystore and `key.properties` are gitignored — contact the repo owner for release credentials.

---

## Project Structure

```
lib/
├── main.dart                  # Entry point + providers
├── core/
│   ├── network/               # Connectivity monitor
│   └── utils/                 # PDF helper, utilities
└── view/
    ├── home/screens/          # Dashboard, customer list
    ├── tab_screen/            # Main tab navigation
    └── ...                    # Feature screens
android/
├── app/build.gradle.kts       # Signing config + CameraX deps
├── build.gradle.kts           # compileSdk override for all plugins
└── gradle.properties          # Cross-drive build fixes
assets/
└── images/                    # App logo and assets
```

---

## Developer

**Fuerte Developers**
pooja@fuertedevelopers.com
