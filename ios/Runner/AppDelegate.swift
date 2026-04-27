import Flutter
import GoogleMaps
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    if let key = Self.resolveGoogleMapsApiKeyFromBundle() {
      GMSServices.provideAPIKey(key)
    }
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
  }

  /// Reads `GOOGLE_MAPS_API_KEY` from Info.plist (filled via `Secrets.xcconfig` → build setting → plist substitution).
  /// Returns nil only when missing, templated, or still an unresolved `$(…)` placeholder — otherwise Maps crashes at runtime with:
  /// `GMSServicesException … must be initialized via [GMSServices provideAPIKey:…]`.
  private static func resolveGoogleMapsApiKeyFromBundle() -> String? {
    guard let raw = Bundle.main.object(forInfoDictionaryKey: "GOOGLE_MAPS_API_KEY") as? String else {
      return nil
    }
    let key = raw.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !key.isEmpty else { return nil }
    // Build setting missing → plist can contain literal "$(GOOGLE_MAPS_API_KEY)"; never pass that to GMSServices.
    if key.contains("$(") { return nil }
    // Copied from Secrets.xcconfig.example before replacing placeholder.
    if key == "YOUR_GOOGLE_MAPS_API_KEY_HERE" { return nil }
    return key
  }
}
