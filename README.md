# Batch Scan Flutter

## Run on Android emulator

1. Ensure the Android emulator is running.
2. Fetch packages:

```bash
flutter pub get
```

3. Run the app:

```bash
flutter run
```

## Camera permission notes

Add the following platform permissions if they are not already present in your project:

### Android

In `android/app/src/main/AndroidManifest.xml` ensure this line is present outside the `<application>` tag:

```xml
<uses-permission android:name="android.permission.CAMERA" />
```

### iOS

In `ios/Runner/Info.plist` add a camera usage description:

```xml
<key>NSCameraUsageDescription</key>
<string>This app needs camera access to scan barcodes.</string>
```
