/// Where the server is.
///
/// Set it when starting the app, for example on a phone on the same Wi-Fi
/// as the computer running the backend:
///
///   flutter run --dart-define=API_URL=http://192.168.0.102:8080
///
/// The default is the address an Android emulator uses to reach the
/// computer it runs on.
const String apiUrl = String.fromEnvironment(
  'API_URL',
  defaultValue: 'http://10.0.2.2:8080',
);

/// The name shown in the app. One place, because the system will be renamed.
const String appName = 'Kodi';
