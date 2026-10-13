import 'package:flutter/widgets.dart';

import 'api_client.dart';
import 'auth_controller.dart';

/// Gives every screen the server connection and the signed-in session.
///
/// A screen that reads `AppScope.of(context).auth` is rebuilt when the
/// session changes (signed in, signed out, name saved).
class AppScope extends InheritedNotifier<AuthController> {
  const AppScope({
    super.key,
    required AuthController auth,
    required this.api,
    required super.child,
  }) : super(notifier: auth);

  final ApiClient api;

  AuthController get auth => notifier!;

  static AppScope of(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<AppScope>()!;
  }
}
