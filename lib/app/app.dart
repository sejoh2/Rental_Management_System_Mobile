import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../config.dart';
import '../core/api_client.dart';
import '../core/app_scope.dart';
import '../core/theme/app_theme.dart';
import '../data/repair_repository.dart';
import '../features/repairs/repair_page.dart';
import 'router.dart';
import 'routes.dart';

class CaretakerApp extends StatefulWidget {
  const CaretakerApp({super.key, required this.services});

  final AppServices services;

  @override
  State<CaretakerApp> createState() => _CaretakerAppState();
}

class _CaretakerAppState extends State<CaretakerApp> {
  // Made once: a new router on every rebuild would lose the page history.
  late final GoRouter _router = buildRouter(widget.services);

  /// For the banner shown when a notification arrives with the app open.
  final _messenger = GlobalKey<ScaffoldMessengerState>();

  @override
  void initState() {
    super.initState();

    final push = widget.services.push;

    if (push != null) {
      push.onOpen = _openFromPush;
      push.onForeground = _showForeground;
      push.takeWaiting();
    }
  }

  @override
  void dispose() {
    _router.dispose();
    super.dispose();
  }

  void _showForeground(String title, String body, Map<String, String> data) {
    _messenger.currentState?.showSnackBar(
      SnackBar(
        content: Text(body.isEmpty ? title : '$title: $body'),
        duration: const Duration(seconds: 6),
        action: SnackBarAction(
          label: 'Open',
          onPressed: () => _openFromPush(data),
        ),
      ),
    );
  }

  /// A tapped notification: its property, then its tab, then the request.
  Future<void> _openFromPush(Map<String, String> data) async {
    final services = widget.services;

    // Just opened from a notification: wait for the sign-in and the properties.
    for (var i = 0; i < 40 && services.properties.properties == null; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 250));
    }

    final property = services.properties.properties
        ?.where((item) => item.id == data['property_id'])
        .firstOrNull;

    if (property == null) return;

    await services.properties.select(property);

    if (data['type'] == 'reading') {
      _router.go(Routes.water);
      return;
    }

    _router.go(Routes.repairs);

    final repairId = data['repair_id'];

    if (data['type'] != 'maintenance' || repairId == null) return;

    try {
      final repair = await RepairRepository(services.api).get(repairId);
      final navigator = _router.routerDelegate.navigatorKey.currentState;

      await navigator?.push(
        MaterialPageRoute<bool>(
          builder: (_) => RepairPage(property: property, repair: repair),
        ),
      );
    } on ApiException {
      // The Maintenance tab is open; the request is in its list.
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppScope(
      services: widget.services,
      child: ListenableBuilder(
        // Only the light or dark choice rebuilds the whole app.
        listenable: widget.services.preferences,
        builder: (context, _) => MaterialApp.router(
          scaffoldMessengerKey: _messenger,
          title: appName,
          debugShowCheckedModeBanner: false,
          theme: buildTheme(Brightness.light),
          darkTheme: buildTheme(Brightness.dark),
          themeMode: widget.services.preferences.themeMode,
          routerConfig: _router,
        ),
      ),
    );
  }
}
