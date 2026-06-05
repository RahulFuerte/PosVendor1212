# Billing Sphere — Claude Code Handoff (updated 2026-06-05)

## Project basics

- **App name:** Billing Sphere (POS)
- **Package ID:** `com.fuertedevelopers.pos`
- **Project path:** `D:\Flutter\Projects\pos\pos23052026\Pos\Pos`
- **Flutter:** 3.44.1 / Dart 3.12.0 (stable channel)
- **Android:** AGP 9.0.1 · Kotlin 2.3.20 · Gradle 9.1.0 · compileSdk 36 · minSdk 24 · targetSdk 36
- **OS:** Windows 11 / PowerShell. Flutter SDK on `C:\src\flutter`, project on `D:\` — cross-drive layout is intentional. See DO NOT TOUCH.
- **Git branch:** `feature/app-enhancements`
- **Test device:** Xiaomi 2201117TI · Android 13 (API 33)

---

## DO NOT TOUCH — ever

These were arrived at through painful debugging. Changing any of them breaks the build.

### `android/gradle.properties`
```properties
kotlin.incremental=false
android.builtInKotlin=false
```
- `kotlin.incremental=false` — prevents `RelocatableFileToPathConverter IllegalArgumentException` from Kotlin on cross-drive paths (C: SDK / D: project).
- `android.builtInKotlin=false` — **critical**. Setting this to `true` causes `audioplayers_android` to throw "Failed to apply plugin 'kotlin-android' — this and base files have different roots" (Windows cross-drive KGP path bug). Build fails completely.

### `android/build.gradle.kts` (root)
Contains a `subprojects { afterEvaluate { ... } }` block forcing `compileSdk = 36` on all plugin modules. Required for `audioplayers_android`. Do not modify or remove.

### `pubspec.yaml`
- No `dependency_overrides` block. If you see one, delete it.
- `razorpay_flutter` is NOT in pubspec and must stay that way. Do not add it back.

### KGP build warnings
Every build prints warnings about 10 plugins applying KGP themselves (audioplayers_android, device_info_plus, flutter_localization, flutter_pos_printer_platform_image_3, flutter_tts, fluttertoast, mobile_scanner, network_info_plus, package_info_plus, share_plus). These are warnings only — builds succeed. Ignore them. Do not try to "fix" them by flipping `android.builtInKotlin`.

---

## Everything already done — do not redo

### Flutter upgrade (complete)
- Flutter 3.16.0 → 3.44.1 / Dart 3.12.0
- SDK channel repaired (was on broken custom branch)
- `intl` bumped to `^0.20.2`
- Removed `material_design_icons_flutter` (broke on Dart 3.12 `IconData final`); all icon refs migrated to `community_material_icon`
- Removed abandoned plugins: `bluetooth_print`, `flutter_bluetooth_scanner`, `pinput`
- Upgraded v1-embedding plugins: `geolocator` 11→14, `uuid` 3→4, `image_cropper` 5→12
- Android folder fully regenerated with correct org `com.fuertedevelopers`
- 41 `flutter analyze` warnings fixed

### Android configuration (complete)
- `MainActivity.kt` — custom version with TTS (`MethodChannel "com.fuertedevelopers.pos/tts"`) and `CameraXConfig.Provider` (Camera2Config — required by mobile_scanner)
- `AndroidManifest.xml` — app label "Billing Sphere", all 8 permissions, UCropActivity declared, `android:enableOnBackInvokedCallback="true"`
- `styles.xml` — `Theme.AppCompat.Light.NoActionBar` added
- CameraX dependencies in `android/app/build.gradle.kts`: `camera-camera2:1.3.4` + `camera-core:1.3.4`
- Release APK signing: keystore `android/app/billingsphere.jks`, alias `billingsphere`, config in `android/key.properties` + `signingConfigs.release` in `build.gradle.kts`. **Keep password safe.**

### Razorpay (removed on purpose)
`razorpay_flutter` was removed because its `NoClassDefFoundError` (extends `Error`, not `Exception`) escaped the registrant's `catch(Exception)` and silently killed every plugin registered after it. All Dart usages are commented out in `lib/`. Re-integration is a separate deferred task.

### Packages — 22 total upgraded
Session 1 (17 packages): audioplayers 5→6.7.1, cached_network_image →3.4.1, carousel_slider →5.1.2, device_info_plus →12.4.0, flutter_launcher_icons →0.14.4, flutter_localization →0.4.0, flutter_tts →4.2.5, fluttertoast →9.1.0, geolocator →14.0.2, google_fonts →8.1.0, image_cropper →12.2.1, permission_handler →12.0.3, shared_preferences →2.5.5, smooth_page_indicator →2.0.1, tutorial_coach_mark →1.3.3, uuid →4.5.3, win32_registry →2.1.0

Session 2 (5 packages): fl_chart 0.66→1.2.0 (dashboard API fixes applied), mobile_scanner 4→7.2.0, share_plus 7→10.1.4, url_strategy removed (discontinued), file_picker held at 8.3.7 (see BLOCKED below)

### Bug fixes (complete)
- White screen bug: `syncSubscriptionWithApi()` in `splash_screen.dart` had no timeout. Fixed with `.timeout(Duration(seconds:8))` + silent fallback. Also removed `..loadSavedSubscription()` from `SubscriptionProvider` constructor (race condition).
- `printer.dart`: connectivity_plus import was commented out + broken single-slash comment caused compile errors. Both fixed.
- `main.dart`: Added `await FlutterLocalization.instance.ensureInitialized()` before `runApp()` — was throwing `EnsureInitializeException` on first widget build.

### App icon (complete)
Adaptive icon: background `#0C6B0F` (app green), foreground `assets/images/logo.png` (two-line square "Billing / Sphere" in light text). Generated with `dart run flutter_launcher_icons`.

### Smoke tests (5/7 complete)
- ✅ App launches, splash → login screen
- ✅ Login + home screen — no crash
- ✅ Navigate all screens — no crash
- ✅ Barcode scanner — camera opens, QR scan works
- ✅ Geolocation — returns coordinates
- ⏳ Bluetooth printer — pending (user has no printer right now)
- ⏳ TTS — pending (test alongside printer)

---

## What is genuinely pending

### 1. Smoke tests — Bluetooth printer + TTS
No code change needed. When user has a printer:
- Pair a Bluetooth thermal printer and print a test receipt from the app
- Trigger TTS (order confirmation voice)
Both features compile and connect at the service level — this is functional verification only.

### 2. Razorpay re-integration (deferred — separate task)
Do not attempt unless user explicitly asks. Research needed: namespace collision between `com.razorpay:standard-core` and `com.razorpay:core`. Check if a newer `razorpay_flutter` version fixes it.

---

## Blocked upgrades — do not attempt

These cannot be upgraded until `audioplayers_android` ships a fix for the Windows cross-drive KGP path issue (`C:` cache vs `D:` project causing "different roots" error when `builtInKotlin=true`):

| Package | Current | Target | Blocker |
|---|---|---|---|
| `file_picker` | 8.3.7 | 11.x | file_picker 11.x skips Kotlin on AGP9+, needs `builtInKotlin=true` |
| `connectivity_plus` | 5.0.2 | 7.x | Needs `builtInKotlin=true`; also `List<ConnectivityResult>` API change |
| `lottie` | 2.7.0 | 3.x | `archive ^4` vs `excel` needing `archive ^3` — irreconcilable |
| KGP migration (9 plugins) | — | — | Same `builtInKotlin=true` cross-drive issue |

When `connectivity_plus` + `file_picker` unblock:
- `connection_monitor.dart`: change `ConnectivityResult` → `List<ConnectivityResult>`, update `checkConnectivity()` call
- `printer.dart` `isOnline()`: same
- `customer_list_screen.dart:136`: `FilePicker.platform.pickFiles(` → `FilePicker.pickFiles(`

---

## Key file locations

| File | Notes |
|---|---|
| `lib/main.dart` | ensureInitialized + providers |
| `lib/view/home/screens/dashboard.dart` | fl_chart 1.2 API (getTooltipColor, tooltipBorderRadius) |
| `lib/core/network/connection_monitor.dart` | connectivity_plus 5.x API (single ConnectivityResult) |
| `lib/view/tab_screen/view-model/widgets/printers/printer.dart` | connectivity_plus + BT printing |
| `lib/core/utils/pdf_helper.dart:177` | share_plus — `Share.shareXFiles` (valid through v10) |
| `lib/view/home/screens/customer_list_screen.dart:136` | file_picker — `FilePicker.platform.pickFiles(` |
| `android/gradle.properties` | `kotlin.incremental=false` + `android.builtInKotlin=false` |
| `android/build.gradle.kts` | subprojects compileSdk=36 override |
| `android/app/build.gradle.kts` | signing config + CameraX deps |
| `android/key.properties` | keystore credentials (gitignored) |
| `android/app/billingsphere.jks` | release keystore (gitignored) |
| `assets/images/logo.png` | adaptive icon foreground |

---

## Communication style with the user

- Direct. No preamble, give the next concrete action.
- Short. Long explanations get skipped.
- Honest about risk. If a change might break something, say so first.
- No "great question!" filler. Diagnose, fix, verify, move on.
- No co-author line in git commits — user's name only.
