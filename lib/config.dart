/// Where the server is.
///
/// Set it when starting the app. With the phone on a USB cable, after
/// `adb reverse tcp:8080 tcp:8080`:
///
///   flutter run --dart-define=API_URL=http://localhost:8080
///
/// or the hosted backend:
///
///   flutter run --dart-define=API_URL=https://YOUR-BACKEND.onrender.com
///
/// The default is the address an Android emulator uses to reach the
/// computer it runs on.
const String apiUrl = String.fromEnvironment(
  'API_URL',
  defaultValue: 'http://10.0.2.2:8080',
);

/// The name and brand letter, in one place, because the system will be
/// renamed. The launcher name is also in android/app/src/main/AndroidManifest.xml
/// (android:label) and ios/Runner/Info.plist; the icon is drawn by
/// tool/make_icons.ps1.
const String appName = 'Kodi';
const String brandLetter = 'K';

/// The same promise as on the web.
const String tagline =
    'Every unit, tenant and shilling — accounted for automatically.';

/// Shown in Settings. Keep in step with `version` in pubspec.yaml.
const String appVersion = '1.0.0';
