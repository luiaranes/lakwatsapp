# Lakwatsapp — iOS Build & Install Guide

> Step-by-step instructions for building and installing the app on iOS devices.

---

## Prerequisites

### 1. Development Environment
- macOS computer (required for iOS development)
- Xcode installed from the App Store
- Flutter SDK installed and configured
- Apple Developer account (free for personal device testing, paid for App Store)

### 2. Verify Setup
```bash
flutter doctor
```

Ensure iOS development is checked:
```
[✓] Xcode - develop for iOS and macOS
[✓] iOS toolchain - develop for iOS devices
```

---

## Building for iOS

### Step 1: Navigate to Project
```bash
cd lakwatsapp/lakwatsapp
```

### Step 2: Get Dependencies
```bash
flutter pub get
```

### Step 3: Install CocoaPods Dependencies
```bash
cd ios
pod install
cd ..
```

### Step 4: Open in Xcode
```bash
open ios/Runner.xcworkspace
```

> **Important:** Always open `.xcworkspace`, not `.xcodeproj`

---

## Configure Signing (First Time Only)

### In Xcode:

1. Select **Runner** in the project navigator (left sidebar)
2. Select **Runner** under TARGETS
3. Go to **Signing & Capabilities** tab
4. Check **Automatically manage signing**
5. Select your **Team** (your Apple ID)
6. Update **Bundle Identifier** if needed (must be unique)

### Bundle Identifier Format:
```
com.yourname.lakwatsapp
```

---

## Install on Physical Device

### Step 1: Connect Your iPhone
- Connect iPhone to Mac via USB cable
- Unlock your iPhone
- Tap "Trust" when prompted on your iPhone

### Step 2: Select Your Device in Xcode
- In Xcode toolbar, click the device dropdown
- Select your connected iPhone

### Step 3: Build and Run

**Option A: Via Xcode**
- Click the Play button (▶) or press `Cmd + R`

**Option B: Via Terminal**
```bash
# List connected devices
flutter devices

# Run on your device
flutter run -d <device-id>

# Or run release build (faster, no debug overhead)
flutter run --release -d <device-id>
```

### Step 4: Trust Developer Certificate (First Time)

On your iPhone:
1. Go to **Settings → General → VPN & Device Management**
2. Find your Apple ID under "Developer App"
3. Tap **Trust "[Your Apple ID]"**
4. Tap **Trust** to confirm

---

## Build Release IPA

### For Ad Hoc / TestFlight Distribution

```bash
# Clean build
flutter clean
flutter pub get

# Build release
flutter build ios --release
```

### Archive in Xcode

1. Open `ios/Runner.xcworkspace` in Xcode
2. Select **Any iOS Device** as build target
3. Go to **Product → Archive**
4. Wait for archive to complete
5. In the Organizer window:
   - **Distribute App** for TestFlight/App Store
   - **Export** for Ad Hoc distribution

---

## Common Issues & Solutions

### "Untrusted Developer" Error
Go to Settings → General → VPN & Device Management → Trust your developer certificate.

### "No Provisioning Profile" Error
1. In Xcode, go to Signing & Capabilities
2. Uncheck then re-check "Automatically manage signing"
3. Select your Team again

### Build Fails After Adding Packages
```bash
cd ios
pod deintegrate
pod install
cd ..
flutter clean
flutter pub get
flutter build ios
```

### "Unable to Install" Error
- Check that Bundle Identifier is unique
- Ensure device is not running out of storage
- Try restarting both Xcode and your device

### Code Signing Errors
```bash
# Reset code signing
cd ios
rm -rf Pods Podfile.lock
pod install
cd ..
```

---

## Device Requirements

| Feature | Minimum iOS Version |
|---------|---------------------|
| Basic App | iOS 14.0+ |
| Voice Input (native) | iOS 26.0+ |
| Voice Input (fallback) | iOS 14.0+ |

---

## Quick Reference

| Task | Command |
|------|---------|
| Run on device (debug) | `flutter run -d <device-id>` |
| Run on device (release) | `flutter run --release -d <device-id>` |
| Build release | `flutter build ios --release` |
| List devices | `flutter devices` |
| Clean build | `flutter clean && flutter pub get` |
| Install pods | `cd ios && pod install && cd ..` |

---

## Notes

- **Voice Input:** Requires a physical device. Simulators don't have microphone access.
- **Camera/Photos:** Permissions are already configured in Info.plist.
- **Google Sign-In:** Works on physical devices; may have issues on simulators.

---

*Last updated: April 10, 2026*
