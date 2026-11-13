# Google Maps setup

The app now uses Google Maps for location selection, address lookup, and live rider tracking. It requests a fresh high-accuracy customer location when the home dashboard opens. A previously saved location is used only when GPS or permission is unavailable.

## Google Cloud APIs

Enable billing and these APIs in the Google Cloud project:

- Maps SDK for Android
- Maps SDK for iOS (when building iOS)
- Maps JavaScript API (when running Flutter web)
- Geocoding API

Use restricted keys in production. Android keys should be restricted by package name and SHA certificate; browser keys should be restricted by allowed web origins.

## Android (PowerShell)

The same value is required by the native map and by Dart address lookup:

```powershell
$env:GOOGLE_MAPS_API_KEY="your_google_maps_key"
flutter pub get
flutter run --dart-define=GOOGLE_MAPS_API_KEY="$env:GOOGLE_MAPS_API_KEY"
```

For an APK:

```powershell
$env:GOOGLE_MAPS_API_KEY="your_google_maps_key"
flutter build apk --release --dart-define=GOOGLE_MAPS_API_KEY="$env:GOOGLE_MAPS_API_KEY"
```

## Web

Replace `YOUR_GOOGLE_MAPS_API_KEY` in `web/index.html`, then run:

```powershell
flutter run -d chrome --dart-define=GOOGLE_MAPS_API_KEY="your_google_maps_key"
```

Browser location works only on `localhost` or an HTTPS origin, and the user must grant location permission.

## iOS

Replace `YOUR_GOOGLE_MAPS_API_KEY` under `GOOGLE_MAPS_API_KEY` in `ios/Runner/Info.plist`. Also pass the Dart define when running so Geocoding API calls use the configured key.
