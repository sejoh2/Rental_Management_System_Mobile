import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Keeps the signed-in session on the phone.
///
/// The tokens are held in the phone's protected storage (the Android
/// Keystore), never in plain files, and in memory while the app is open so
/// that a request does not wait on storage.
class SessionStore {
  SessionStore([FlutterSecureStorage? storage])
    : _storage = storage ?? const FlutterSecureStorage();

  static const _accessKey = 'access_token';
  static const _refreshKey = 'refresh_token';

  final FlutterSecureStorage _storage;

  String? accessToken;
  String? refreshToken;

  bool get hasSession => refreshToken != null;

  /// Reads what was kept from the last time the app was open.
  Future<void> load() async {
    try {
      accessToken = await _storage.read(key: _accessKey);
      refreshToken = await _storage.read(key: _refreshKey);
    } catch (_) {
      // Storage that cannot be read (for example after a restore from a
      // backup) is treated as signed out, never as a crash.
      accessToken = null;
      refreshToken = null;
    }
  }

  Future<void> save({required String access, required String refresh}) async {
    accessToken = access;
    refreshToken = refresh;

    await _storage.write(key: _accessKey, value: access);
    await _storage.write(key: _refreshKey, value: refresh);
  }

  Future<void> clear() async {
    accessToken = null;
    refreshToken = null;

    try {
      await _storage.delete(key: _accessKey);
      await _storage.delete(key: _refreshKey);
    } catch (_) {
      // Nothing more can be done; the copies in memory are already gone.
    }
  }
}
