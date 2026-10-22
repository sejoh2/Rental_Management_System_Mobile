import 'dart:async';
import 'dart:convert';

import 'package:flutter/widgets.dart';

import 'api_client.dart';
import 'auth_controller.dart';

/// Something changed on the server: an area (maintenance, water, tenants,
/// units, billing, payments, expenses, caretakers, properties, account, or
/// "all") and the property it is in, if one.
class LiveChange {
  const LiveChange(this.area, this.propertyId);

  final String area;
  final String? propertyId;

  bool get everything => area == 'all';
}

/// Real-time updates while the app is open. One connection to the server,
/// which says "look again" whenever anything in the caretaker's properties
/// changes, by anyone; open screens then fetch their data again. Nothing
/// else travels on it. Closed while the app is in the background (push
/// notifications cover that), and opened again when it comes back.
class LiveController with WidgetsBindingObserver {
  LiveController({required this.api, required this.auth}) {
    auth.addListener(_sessionChanged);
    WidgetsBinding.instance.addObserver(this);
    _sessionChanged();
  }

  static const _firstRetry = Duration(seconds: 5);
  static const _longestRetry = Duration(minutes: 1);

  /// The server sends a heartbeat every 25 seconds: silence for longer means
  /// the connection is gone.
  static const _silence = Duration(seconds: 70);

  final ApiClient api;
  final AuthController auth;

  final _changes = StreamController<LiveChange>.broadcast();

  Stream<LiveChange> get changes => _changes.stream;

  StreamSubscription<String>? _lines;
  Timer? _retry;
  Timer? _watchdog;
  Duration _retryIn = _firstRetry;
  bool _connecting = false;
  bool _foreground = true;

  bool get _signedIn =>
      auth.status == AuthStatus.signedIn &&
      auth.user != null &&
      auth.user!.isCaretaker &&
      !auth.user!.needsName;

  void _sessionChanged() {
    if (_signedIn && _foreground) {
      if (_lines == null) _connect();
    } else {
      _close();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
    _sessionChanged();
  }

  Future<void> _connect() async {
    if (_connecting || _lines != null) return;

    _connecting = true;

    try {
      final response = await api.post(
        '/api/live/ticket',
        query: {'for': 'caretaker'},
      );
      final ticket = (response['data'] as Json)['ticket'] as String;
      final stream = await api.openEventStream(
        '/api/live/stream',
        query: {'ticket': ticket},
      );

      if (!_signedIn || !_foreground) return;

      String? event;
      String? data;

      _lines = stream.listen(
        (line) {
          _feedWatchdog();

          if (line.startsWith('event:')) {
            event = line.substring(6).trim();
          } else if (line.startsWith('data:')) {
            data = line.substring(5).trim();
          } else if (line.isEmpty && event != null) {
            _handle(event!, data);
            event = null;
            data = null;
          }
        },
        onError: (_) => _lost(),
        onDone: _lost,
        cancelOnError: true,
      );
      _feedWatchdog();
    } catch (_) {
      _lost();
    } finally {
      _connecting = false;
    }
  }

  void _handle(String event, String? data) {
    if (event == 'ready') {
      _retryIn = _firstRetry;
      // Anything missed while the connection was down.
      _changes.add(const LiveChange('all', null));
      return;
    }

    if (event != 'changed') return;

    try {
      final detail = jsonDecode(data ?? '{}') as Map<String, dynamic>;

      _changes.add(
        LiveChange(
          '${detail['area'] ?? 'all'}',
          detail['property_id'] == null ? null : '${detail['property_id']}',
        ),
      );
    } catch (_) {
      _changes.add(const LiveChange('all', null));
    }
  }

  void _feedWatchdog() {
    _watchdog?.cancel();
    _watchdog = Timer(_silence, _lost);
  }

  void _lost() {
    _close();

    if (!_signedIn || !_foreground) return;

    _retry?.cancel();
    _retry = Timer(_retryIn, _connect);
    _retryIn = _retryIn * 2 > _longestRetry ? _longestRetry : _retryIn * 2;
  }

  void _close() {
    _watchdog?.cancel();
    _watchdog = null;
    _retry?.cancel();
    _retry = null;
    _lines?.cancel();
    _lines = null;
  }

  void dispose() {
    _close();
    auth.removeListener(_sessionChanged);
    WidgetsBinding.instance.removeObserver(this);
    _changes.close();
  }
}

/// For a screen that should update by itself: call [listenLive] once, and
/// [liveReload] runs (once for a burst of changes) when something in its
/// [liveAreas] changes in its property.
mixin LiveRefresh<T extends StatefulWidget> on State<T> {
  StreamSubscription<LiveChange>? _liveSubscription;
  Timer? _liveGather;

  Set<String> get liveAreas;

  /// Null: changes in any property.
  String? get livePropertyId;

  /// Fetches the screen's data again, keeping what is shown until it arrives.
  Future<void> liveReload();

  void listenLive(LiveController? live) {
    if (live == null || _liveSubscription != null) return;

    _liveSubscription = live.changes.listen((change) {
      final area = change.everything || liveAreas.contains(change.area);
      final place =
          change.propertyId == null ||
          livePropertyId == null ||
          change.propertyId == livePropertyId;

      if (!area || !place) return;

      _liveGather?.cancel();
      _liveGather = Timer(const Duration(milliseconds: 600), () {
        if (mounted) liveReload();
      });
    });
  }

  @override
  void dispose() {
    _liveGather?.cancel();
    _liveSubscription?.cancel();
    super.dispose();
  }
}
