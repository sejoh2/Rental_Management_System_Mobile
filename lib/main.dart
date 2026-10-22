import 'package:flutter/material.dart';

import 'app/app.dart';
import 'config.dart';
import 'core/api_client.dart';
import 'core/app_scope.dart';
import 'core/auth_controller.dart';
import 'core/live_controller.dart';
import 'core/notices_controller.dart';
import 'core/preferences.dart';
import 'core/push_controller.dart';
import 'core/properties_controller.dart';
import 'core/session_store.dart';
import 'data/property_repository.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final preferences = AppPreferences();

  // Light or dark, and whether the intro was seen, are known before the first frame.
  await preferences.load();

  final session = SessionStore();
  final api = ApiClient(baseUrl: apiUrl, session: session);
  final auth = AuthController(api: api, session: session);
  final properties = PropertiesController(
    repository: PropertyRepository(api),
    preferences: preferences,
  );

  // What is new for the caretaker, looked at every minute while signed in.
  final notices = NoticesController(
    api: api,
    auth: auth,
    properties: properties,
  );

  // Real time: screens update by themselves while the app is open.
  final live = LiveController(api: api, auth: auth);

  live.changes.listen((change) {
    if (change.everything ||
        const {'caretakers', 'properties', 'units'}.contains(change.area)) {
      properties.load();
    }

    if (change.everything || change.area == 'maintenance') notices.check();
    if (change.everything || change.area == 'account') auth.refresh();
  });

  // Phone notifications: registers this phone after sign-in.
  final push = PushController(api: api, auth: auth, notices: notices);

  // The caretaker's properties are loaded once signed in, and forgotten on sign-out.
  auth.addListener(() {
    final user = auth.user;

    if (auth.status == AuthStatus.signedIn &&
        user != null &&
        user.isCaretaker &&
        !user.needsName) {
      if (properties.properties == null && !properties.loading) {
        properties.load();
      }
    } else if (auth.status == AuthStatus.signedOut) {
      properties.clear();
    }
  });

  // Finds out who is signed in while the first screen is drawn.
  auth.start();
  push.start();

  runApp(
    CaretakerApp(
      services: AppServices(
        api: api,
        auth: auth,
        preferences: preferences,
        properties: properties,
        notices: notices,
        push: push,
        live: live,
      ),
    ),
  );
}
