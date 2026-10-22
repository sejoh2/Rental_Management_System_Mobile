import 'package:flutter/widgets.dart';

import 'api_client.dart';
import 'auth_controller.dart';
import 'notices_controller.dart';
import 'preferences.dart';
import 'push_controller.dart';
import 'properties_controller.dart';

/// The app's shared services, made once when the app opens.
class AppServices {
  const AppServices({
    required this.api,
    required this.auth,
    required this.preferences,
    required this.properties,
    required this.notices,
    this.push,
  });

  final ApiClient api;
  final AuthController auth;
  final AppPreferences preferences;
  final PropertiesController properties;
  final NoticesController notices;

  /// Phone notifications; null in tests.
  final PushController? push;
}

/// Gives every screen the shared services.
///
/// A screen that calls `AppScope.of(context)` is rebuilt when the session,
/// the preferences, the selected property or the notices change.
class AppScope extends InheritedNotifier<Listenable> {
  AppScope({super.key, required this.services, required super.child})
    : super(
        notifier: Listenable.merge([
          services.auth,
          services.preferences,
          services.properties,
          services.notices,
        ]),
      );

  final AppServices services;

  static AppServices of(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<AppScope>()!.services;
  }

  /// The services without rebuilding when they change: for button handlers.
  static AppServices read(BuildContext context) {
    return context.getInheritedWidgetOfExactType<AppScope>()!.services;
  }
}
