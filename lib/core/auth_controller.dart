import 'package:flutter/foundation.dart';

import '../models/app_user.dart';
import 'api_client.dart';
import 'session_store.dart';

enum AuthStatus {
  /// The app has just opened and is finding out who is signed in.
  starting,

  /// A session is kept, but the server could not be reached to confirm it.
  unreachable,

  signedOut,
  signedIn,
}

/// Who is signed in, and the steps to sign in and out.
class AuthController extends ChangeNotifier {
  AuthController({required this.api, required this.session}) {
    api.onSessionExpired = _expired;
    // A change refused as read-only: look again, so the banner shows.
    api.onReadOnly = () {
      if (!readOnly) refresh();
    };
  }

  final ApiClient api;
  final SessionStore session;

  AuthStatus status = AuthStatus.starting;
  AppUser? user;

  /// Why the server could not be reached, while [status] is unreachable.
  String? startError;

  /// True while the owner's Kodi bill is unpaid past the grace days: the
  /// caretaker can look at everything but change nothing.
  bool readOnly = false;

  /// The owner of the account, for "Call the owner".
  OwnerContact? owner;

  /// Run first when signing out, while still signed in: the phone's push
  /// address is taken back.
  Future<void> Function()? beforeSignOut;

  /// Finds out who is signed in. Called when the app opens, and again from
  /// the "Try again" button when the server could not be reached.
  Future<void> start() async {
    status = AuthStatus.starting;
    startError = null;
    notifyListeners();

    await session.load();

    if (!session.hasSession) {
      _set(AuthStatus.signedOut);
      return;
    }

    try {
      final response = await api.get('/api/auth/me');

      _read(response);
      _set(AuthStatus.signedIn);
    } on ApiException catch (error) {
      if (error.unreachable) {
        startError = error.message;
        _set(AuthStatus.unreachable);
      } else {
        await session.clear();
        user = null;
        _set(AuthStatus.signedOut);
      }
    }
  }

  /// Looks again at the account: the name, whether it is read-only, the
  /// owner. Called every minute or so while the app is open. A failure is
  /// ignored: the next look will do.
  Future<void> refresh() async {
    if (status != AuthStatus.signedIn) return;

    try {
      _read(await api.get('/api/auth/me'));
      notifyListeners();
    } on ApiException {
      // Nothing to do.
    }
  }

  void _read(Json response) {
    user = AppUser.fromJson(response['user'] as Json);

    final subscription = response['subscription'];
    final contact = response['owner'];

    readOnly = subscription is Map && subscription['read_only'] == true;
    owner = contact is Map<String, dynamic>
        ? OwnerContact.fromJson(contact)
        : null;
  }

  /// Sends a sign-in code by SMS. -> seconds until another may be asked for.
  Future<int> requestCode(String phone) async {
    final response = await api.post(
      '/api/auth/request-otp',
      body: {'phone': phone},
      auth: false,
    );

    return (response['resend_in_seconds'] as num?)?.toInt() ?? 60;
  }

  Future<void> verifyCode(String phone, String code) async {
    final response = await api.post(
      '/api/auth/verify-otp',
      body: {'phone': phone, 'code': code},
      auth: false,
    );

    await session.save(
      access: response['access_token'] as String,
      refresh: response['refresh_token'] as String,
    );

    user = AppUser.fromJson(response['user'] as Json);
    _set(AuthStatus.signedIn);
    // Read-only state and the owner come with /me.
    refresh();
  }

  /// Asked once, right after the first sign-in.
  Future<void> saveName(String fullName) async {
    final response = await api.patch(
      '/api/auth/me/name',
      body: {'full_name': fullName},
    );

    user = AppUser.fromJson(response['user'] as Json);
    notifyListeners();
  }

  Future<void> signOut() async {
    try {
      await beforeSignOut?.call();
    } catch (_) {
      // Signing out goes ahead.
    }

    final refresh = session.refreshToken;

    await session.clear();
    user = null;
    owner = null;
    readOnly = false;
    _set(AuthStatus.signedOut);

    if (refresh == null) return;

    try {
      // Ends the session on the server too. Signing out on the phone has
      // already happened, so a failure here is not shown.
      await api.post(
        '/api/auth/logout',
        body: {'refresh_token': refresh},
        auth: false,
      );
    } on ApiException {
      // Nothing to do.
    }
  }

  void _expired() {
    user = null;
    owner = null;
    readOnly = false;
    _set(AuthStatus.signedOut);
  }

  void _set(AuthStatus next) {
    status = next;
    notifyListeners();
  }
}

/// The owner who added this caretaker.
class OwnerContact {
  const OwnerContact({required this.fullName, required this.phone});

  factory OwnerContact.fromJson(Json json) {
    return OwnerContact(
      fullName: (json['full_name'] as String?)?.trim() ?? '',
      phone: (json['phone'] as String?)?.trim() ?? '',
    );
  }

  final String fullName;
  final String phone;
}
