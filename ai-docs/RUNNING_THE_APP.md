# Lakwatsapp — Running the App

> Instructions for running the app on iOS, Android, and Web platforms.

---

## Prerequisites

### 1. Flutter SDK
Ensure Flutter is installed and up to date:
```bash
flutter --version
flutter doctor
```

### 2. Environment Variables
Make sure the `.env` file exists in `lakwatsapp/` with your Supabase credentials:
```
SUPABASE_URL=https://your-project.supabase.co
SUPABASE_ANON_KEY=your-anon-key
```

### 3. Dependencies
Install all dependencies:
```bash
cd lakwatsapp
flutter pub get
```

### 4. Database Migrations
Apply Supabase migrations (local or hosted project):
```bash
supabase db push
```

Recent Phase 3 migrations:
- `017_trip_bookings.sql` — bookings + email import logs
- `018_trip_packing_items.sql` — packing list items
- `019_packing_assignments_notifications.sql` — assignee columns + in-app notifications

### 5. Edge Functions (optional for AI / email features)
```bash
supabase functions deploy generate-itinerary
supabase functions deploy generate-packing-suggestions
supabase functions deploy parse-booking-email
supabase functions deploy process-forwarded-email
```

Requires `ANTHROPIC_API_KEY` in Supabase Edge Function secrets for AI functions.

---

## Web

### Development
```bash
cd lakwatsapp
flutter run -d chrome --web-port=3000
```

**Important:** Use `--web-port=3000` to match the Supabase OAuth redirect URL configuration.

### Hot Reload Commands
While running:
- `r` — Hot reload (applies code changes instantly)
- `R` — Hot restart (restarts app, clears state)
- `q` — Quit

### Production Build
```bash
flutter build web
```
Output will be in `build/web/`. Deploy this folder to any static hosting (Vercel, Netlify, Firebase Hosting, etc.).

---

## iOS

### Requirements
- macOS computer
- Xcode installed (from App Store)
- iOS Simulator or physical iPhone/iPad
- Apple Developer account (for physical device testing)

### Setup
```bash
# Open iOS project in Xcode (first time only)
cd lakwatsapp/ios
pod install
open Runner.xcworkspace
```

In Xcode:
1. Select your Team in **Signing & Capabilities**
2. Update Bundle Identifier if needed

### Run on Simulator
```bash
cd lakwatsapp

# List available simulators
flutter devices

# Boot a simulator first (optional - it will auto-boot if needed)
xcrun simctl boot "iPhone 16 Pro Max"

# Run on specific simulator by name
flutter run -d "iPhone 16 Pro Max"
flutter run -d "iPhone 16 Pro"
flutter run -d "iPhone 15 Pro"

# Or run on any available simulator
flutter run
```

**Available Simulators (common ones):**
| Device | iOS Version |
|--------|-------------|
| iPhone 17 Pro Max | iOS 26.x |
| iPhone 17 Pro | iOS 26.x |
| iPhone Air | iOS 26.x |
| iPhone 16 Pro Max | iOS 18.x |
| iPhone 16 Pro | iOS 18.x |
| iPhone 16 | iOS 18.x |
| iPhone 15 Pro Max | iOS 17.5 |
| iPhone 15 Pro | iOS 17.5 |
| iPad Pro 13-inch (M4) | iOS 18.x |

**Notes:**
- Google Sign-In may behave differently on simulators vs physical devices.
- **Voice input** requires a real device — simulators don't have microphone access.

### Run on Physical Device
1. Connect iPhone via USB
2. Trust the computer on your iPhone
3. Run:
```bash
flutter run -d <device-id>
```

### Production Build
```bash
# Build for App Store
flutter build ios --release

# Open in Xcode for archive/upload
open ios/Runner.xcworkspace
```
Then in Xcode: **Product → Archive → Distribute App**

---

## Android

### Requirements
- Android Studio installed
- Android SDK
- Android Emulator or physical Android device
- USB debugging enabled (for physical device)

### Setup
```bash
# Accept Android licenses
flutter doctor --android-licenses
```

### Run on Emulator
```bash
cd lakwatsapp

# List available devices
flutter devices

# Run on Android Emulator
flutter run -d <emulator-id>
```

### Run on Physical Device
1. Enable **Developer Options** on your Android phone:
   - Go to Settings → About Phone
   - Tap "Build Number" 7 times
2. Enable **USB Debugging** in Developer Options
3. Connect phone via USB and accept the debugging prompt
4. Run:
```bash
flutter run -d <device-id>
```

### Production Build

**APK (for direct installation):**
```bash
flutter build apk --release
```
Output: `build/app/outputs/flutter-apk/app-release.apk`

**App Bundle (for Play Store):**
```bash
flutter build appbundle --release
```
Output: `build/app/outputs/bundle/release/app-release.aab`

---

## Supabase OAuth Configuration

For Google Sign-In to work on each platform, configure the redirect URLs in Supabase:

### Supabase Dashboard → Authentication → URL Configuration

| Setting | Value |
|---------|-------|
| Site URL | `http://localhost:3000` (for web dev) |
| Redirect URLs | Add all of the following: |

```
http://localhost:3000
http://localhost:3000/
io.supabase.lakwatsapp://login-callback/
com.example.larga://login-callback/
```

### Google Cloud Console

For Google OAuth, add authorized redirect URIs:
```
https://YOUR_PROJECT_REF.supabase.co/auth/v1/callback
```

---

## Common Issues

### "localhost refused to connect" after Google Sign-In
- Ensure the app is running on the correct port (`--web-port=3000`)
- Verify Supabase Site URL matches your dev port

### iOS Build Fails
```bash
cd ios
pod deintegrate
pod install
cd ..
flutter clean
flutter pub get
```

### Android Build Fails
```bash
cd android
./gradlew clean
cd ..
flutter clean
flutter pub get
```

### Hot Reload Not Working
Try hot restart (`R`) or full restart (`q` then `flutter run` again).

### Voice Input Not Working
- **On Simulator:** Voice input requires a real device. Simulators don't have microphone access.
- **Permission Denied:** Ensure microphone permission is granted in device settings.
- **iOS 26+:** Uses native SpeechAnalyzer API via `liquid_speech` package.
- **Android/Older iOS:** Uses `speech_to_text` package as fallback.

---

## Quick Reference

| Platform | Command |
|----------|---------|
| Web (Chrome) | `flutter run -d chrome --web-port=3000` |
| iOS Simulator (iPhone 17 Pro) | `flutter run -d "iPhone 17 Pro"` |
| iOS Simulator (iPhone 16 Pro Max) | `flutter run -d "iPhone 16 Pro Max"` |
| iOS Simulator (iPhone 16 Pro) | `flutter run -d "iPhone 16 Pro"` |
| iOS Physical Device | `flutter run -d <device-id>` |
| Android Emulator | `flutter run -d <emulator-id>` |
| Android Device | `flutter run -d <device-id>` |
| List Devices | `flutter devices` |
| Boot iOS Simulator | `xcrun simctl boot "iPhone 16 Pro Max"` |
| Build Web | `flutter build web` |
| Build iOS | `flutter build ios --release` |
| Build Android APK | `flutter build apk --release` |
| Build Android Bundle | `flutter build appbundle --release` |

---

*Last updated: May 18, 2026*
