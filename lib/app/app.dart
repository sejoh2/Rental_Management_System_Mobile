import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../config.dart';
import '../core/app_scope.dart';
import '../core/theme/app_theme.dart';
import 'router.dart';

class CaretakerApp extends StatefulWidget {
  const CaretakerApp({super.key, required this.services});

  final AppServices services;

  @override
  State<CaretakerApp> createState() => _CaretakerAppState();
}

class _CaretakerAppState extends State<CaretakerApp> {
  // Made once: a new router on every rebuild would lose the page history.
  late final GoRouter _router = buildRouter(widget.services);

  @override
  void dispose() {
    _router.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AppScope(
      services: widget.services,
      child: ListenableBuilder(
        // Only the light or dark choice rebuilds the whole app.
        listenable: widget.services.preferences,
        builder: (context, _) => MaterialApp.router(
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
