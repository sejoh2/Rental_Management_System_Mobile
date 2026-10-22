import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

import 'api_client.dart';
import 'auth_controller.dart';
import 'notices_controller.dart';

/// Phone notifications (Firebase Cloud Messaging).
///
/// After sign-in it asks the phone for permission and gives the server this
/// phone's push address; on sign-out it takes the address back. A tap on a
/// notification (also when the app was closed) is passed to [onOpen], which
/// opens the request or reading. While the app is open, a notification
/// refreshes the bell and is passed to [onForeground].
///
/// Without the Firebase settings file (android/app/google-services.json)
/// Firebase does not start, and the app works as before without push.
class PushController {
  PushController({
    required this.api,
    required this.auth,
    required this.notices,
  });

  final ApiClient api;
  final AuthController auth;
  final NoticesController notices;

  /// Opens what a notification is about: {type, repair_id | reading_id, property_id}.
  void Function(Map<String, String> data)? onOpen;

  /// A notification that arrived while the app is on screen.
  void Function(String title, String body, Map<String, String> data)?
  onForeground;

  bool _started = false;
  bool _registering = false;

  /// The address the server has, and for whom.
  String? _token;
  String? _tokenUser;

  /// A tap that came before the app was ready to open it.
  Map<String, String>? _waiting;

  Future<void> start() async {
    if (_started) return;

    _started = true;

    try {
      await Firebase.initializeApp();
    } catch (_) {
      // No Firebase settings in this build: no push.
      return;
    }

    FirebaseMessaging.onMessage.listen((message) {
      notices.check();
      onForeground?.call(
        message.notification?.title ?? '',
        message.notification?.body ?? '',
        _strings(message.data),
      );
    });
    FirebaseMessaging.onMessageOpenedApp.listen(
      (message) => _open(_strings(message.data)),
    );
    FirebaseMessaging.instance.onTokenRefresh.listen(_send);

    final first = await FirebaseMessaging.instance.getInitialMessage();

    if (first != null) _open(_strings(first.data));

    auth.addListener(_sessionChanged);
    auth.beforeSignOut = _unregister;
    _sessionChanged();
  }

  /// Hands over a tap that came before [onOpen] was set.
  void takeWaiting() {
    final waiting = _waiting;

    if (waiting != null && onOpen != null) {
      _waiting = null;
      onOpen!(waiting);
    }
  }

  bool get _signedIn =>
      auth.status == AuthStatus.signedIn &&
      auth.user != null &&
      auth.user!.isCaretaker &&
      !auth.user!.needsName;

  void _sessionChanged() {
    if (_signedIn && _tokenUser != auth.user!.id) _register();
  }

  Future<void> _register() async {
    if (_registering) return;

    _registering = true;

    try {
      final settings = await FirebaseMessaging.instance.requestPermission();

      if (settings.authorizationStatus == AuthorizationStatus.denied) return;

      final token = await FirebaseMessaging.instance.getToken();

      if (token != null) await _send(token);
    } catch (_) {
      // Tried again at the next sign-in or when the app opens.
    } finally {
      _registering = false;
    }
  }

  Future<void> _send(String token) async {
    if (!_signedIn) return;

    try {
      await api.post(
        '/api/caretaker/push-devices',
        body: {'token': token, 'platform': 'android'},
      );
      _token = token;
      _tokenUser = auth.user!.id;
    } on ApiException {
      // Sent again next time.
    }
  }

  /// Before signing out: this phone stops getting the person's notifications.
  Future<void> _unregister() async {
    final token = _token;

    _token = null;
    _tokenUser = null;

    if (token == null) return;

    try {
      await api
          .delete('/api/caretaker/push-devices', body: {'token': token})
          .timeout(const Duration(seconds: 5));
    } catch (_) {
      // The server drops an address Firebase no longer knows.
    }

    try {
      // A new address for whoever signs in next.
      await FirebaseMessaging.instance.deleteToken();
    } catch (_) {
      // Nothing more to do.
    }
  }

  void _open(Map<String, String> data) {
    if (onOpen == null) {
      _waiting = data;
    } else {
      onOpen!(data);
    }
  }

  static Map<String, String> _strings(Map<String, dynamic> data) => {
    for (final entry in data.entries) entry.key: '${entry.value}',
  };
}
