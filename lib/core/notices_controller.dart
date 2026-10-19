import 'dart:async';

import 'package:flutter/widgets.dart';

import '../data/repair_repository.dart';
import '../models/repair.dart';
import 'api_client.dart';
import 'auth_controller.dart';
import 'properties_controller.dart';

/// What is new for the caretaker (repairs the owner reported or gave to
/// them), for the bell at the top of each tab. Also looks again at the
/// account (read-only or not).
///
/// It looks every minute while the app is open and signed in, and at once
/// when the app comes back to the screen. Nothing is checked while the app
/// is in the background: a phone notification needs a push service, which
/// can be added later.
class NoticesController extends ChangeNotifier with WidgetsBindingObserver {
  NoticesController({required this.api, required this.auth, this.properties}) {
    auth.addListener(_sessionChanged);
    WidgetsBinding.instance.addObserver(this);
    _sessionChanged();
  }

  static const _every = Duration(minutes: 1);

  final ApiClient api;
  final AuthController auth;

  /// Looked at again with the account, so a property the owner has just
  /// added (or removed) shows without signing in again.
  final PropertiesController? properties;

  List<Repair> items = const [];
  Timer? _timer;
  bool _checking = false;

  int get count => items.length;

  bool get _signedIn =>
      auth.status == AuthStatus.signedIn &&
      auth.user != null &&
      auth.user!.isCaretaker &&
      !auth.user!.needsName;

  void _sessionChanged() {
    if (_signedIn) {
      if (_timer == null) {
        _timer = Timer.periodic(_every, (_) => check());
        check();
      }
    } else {
      _timer?.cancel();
      _timer = null;

      if (items.isNotEmpty) {
        items = const [];
        notifyListeners();
      }
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _signedIn) {
      check();
      auth.refresh();
      properties?.load();
    }
  }

  /// Looks for what is new. A failure keeps the last list: the next look
  /// will do.
  Future<void> check() async {
    if (_checking || !_signedIn) return;

    _checking = true;

    try {
      final found = await RepairRepository(api).notices();

      items = found;
      notifyListeners();
    } on ApiException {
      // Nothing to do.
    } finally {
      _checking = false;
    }

    // Every few looks is enough for the account and its properties.
    if (DateTime.now().minute % 5 == 0) {
      auth.refresh();
      properties?.load();
    }
  }

  /// "Mark all as read".
  Future<void> markAllSeen() async {
    await RepairRepository(api).markNoticesSeen();
    items = const [];
    notifyListeners();
  }

  /// A repair was opened: it is no longer new.
  void seen(String repairId) {
    if (!items.any((item) => item.id == repairId)) return;

    items = items.where((item) => item.id != repairId).toList();
    notifyListeners();
  }

  @override
  void dispose() {
    _timer?.cancel();
    auth.removeListener(_sessionChanged);
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }
}
