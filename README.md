# MyBill POS - Restaurant Point of Sale System

A Flutter-based Point of Sale (POS) application designed for restaurants and food service businesses. Built with an offline-first architecture, this app ensures seamless operations even without internet connectivity.

## Features

### Core POS Functionality
- **Menu Management** - Browse food items by department/category with image support
- **Order Processing** - Add items to cart, manage quantities, and process bills
- **Receipt Generation** - Create and print receipts via Bluetooth thermal printers
- **Customer Management** - Save customer details and order history
- **Table Management** - Assign orders to table numbers

### Offline-First Architecture
- **Smart Database Service** - Automatically switches between Firebase (online) and SQLite (offline)
- **Offline Bill Storage** - Bills created offline are stored locally and synced when connectivity returns
- **Data Preloading** - Proactively caches menu data for offline availability
- **Connection Monitoring** - Real-time connectivity status with visual indicators
- **Automatic Sync** - Pending bills automatically sync when internet is restored

### Reporting & Analytics
- **Sales Reports** - View sales data with multiple report types:
  - Bill-wise reports
  - Date-wise reports
  - Item-wise reports
- **Performance Dashboard** - Monitor business performance metrics
- **Product Dashboard** - Track product sales and inventory

### Printing Support
- Bluetooth thermal printer integration
- Receipt preview before printing
- Multiple printer connection support

## Tech Stack

- **Framework**: Flutter 3.x (Dart SDK >=3.0.1)
- **Backend**: Firebase (Firestore, Auth, Storage)
- **Local Database**: SQLite (sqflite) + Hive
- **State Management**: Provider
- **Platforms**: Android, iOS, Web, Windows, macOS, Linux

## Key Dependencies

| Package | Purpose |
|---------|---------|
| `firebase_core`, `cloud_firestore`, `firebase_auth` | Backend services |
| `sqflite` | Local SQLite database |
| `hive_flutter` | Fast key-value storage |
| `provider` | State management |
| `connectivity_plus` | Network monitoring |
| `bluetooth_print`, `flutter_pos_printer_platform_image_3` | Thermal printing |
| `cached_network_image` | Image caching |
| `pdf`, `printing` | PDF generation |
| `lottie` | Animations |

## Project Structure

```
lib/
├── main.dart                    # App entry point with provider setup
└── view/
    ├── home/
    │   ├── restaurant_screen.dart      # Main POS screen
    │   ├── productDashBoard.dart       # Product analytics
    │   ├── performance_dashboard_screen.dart
    │   ├── calculator_screen.dart
    │   ├── customer_listScreen.dart
    │   ├── usersDataScreen.dart
    │   ├── receipt_preview.dart
    │   └── reports/                    # Sales reporting
    │       ├── billWise_report.dart
    │       ├── dateWise_report.dart
    │       └── itemWise_report.dart
    ├── login/
    │   └── splash_screen.dart          # Auth flow
    ├── local_DB/                       # Local database models
    └── tab_screen/
        └── view-model/
            ├── backend/
            │   ├── smart_database_service.dart    # Online/offline data handling
            │   ├── offline_bill_manager.dart      # Offline bill sync
            │   ├── connection_monitor.dart        # Connectivity tracking
            │   ├── sqlite_helper.dart             # SQLite operations
            │   ├── firebase_dao.dart              # Firebase data access
            │   └── unified_database_service.dart  # Abstracted DB layer
            ├── widgets/
            │   ├── offline_bill_status_widget.dart
            │   ├── sync_status_indicator.dart
            │   ├── cached_blob_image.dart
            │   └── printers/                      # Printer widgets
            ├── constants/
            └── frontend/
```

## Getting Started

### Prerequisites
- Flutter SDK (>=3.0.1)
- Dart SDK (>=3.0.1)
- Firebase project configured
- Android Studio / VS Code

### Installation

1. Clone the repository
```bash
git clone <repository-url>
cd pos
```

2. Install dependencies
```bash
flutter pub get
```

3. Configure Firebase
   - Add your `google-services.json` (Android) to `android/app/`
   - Add your `GoogleService-Info.plist` (iOS) to `ios/Runner/`

4. Run the app
```bash
flutter run
```

### Build for Production

```bash
# Android APK
flutter build apk --release

# Android App Bundle
flutter build appbundle --release

# iOS
flutter build ios --release
```

## Offline Mode

The app is designed to work seamlessly offline:

1. **First Launch**: Requires internet to download initial menu data
2. **Subsequent Use**: Menu data is cached locally in SQLite
3. **Creating Bills Offline**: Bills are stored locally with a pending sync status
4. **Auto-Sync**: When connectivity returns, pending bills automatically sync to Firebase
5. **Visual Indicators**: The app shows online/offline status and pending bill count

## Configuration

### App Icon
Update the app icon by modifying `flutter_icons` in `pubspec.yaml`:
```yaml
flutter_icons:
  android: true
  ios: true
  image_path: "assets/images/myBillLogo.jpeg"
```

Then run:
```bash
flutter pub run flutter_launcher_icons
```

## License

This project is private and not published to pub.dev.

## Support

For issues and feature requests, please contact the development team.
