import 'package:flutter/material.dart';

import 'config.dart';
import 'core/api_client.dart';
import 'core/app_scope.dart';
import 'core/app_theme.dart';
import 'core/auth_controller.dart';
import 'core/session_store.dart';
import 'features/auth/name_page.dart';
import 'features/auth/sign_in_page.dart';
import 'features/home/home_page.dart';
import 'widgets/message_box.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  final session = SessionStore();
  final api = ApiClient(baseUrl: apiUrl, session: session);
  final auth = AuthController(api: api, session: session);

  // Finds out who is signed in while the first screen is drawn.
  auth.start();

  runApp(CaretakerApp(api: api, auth: auth));
}

class CaretakerApp extends StatelessWidget {
  const CaretakerApp({super.key, required this.api, required this.auth});

  final ApiClient api;
  final AuthController auth;

  @override
  Widget build(BuildContext context) {
    return AppScope(
      api: api,
      auth: auth,
      child: MaterialApp(
        title: appName,
        debugShowCheckedModeBanner: false,
        // Follows the phone's light or dark setting.
        theme: buildTheme(Brightness.light),
        darkTheme: buildTheme(Brightness.dark),
        home: const _Gate(),
      ),
    );
  }
}

/// Shows the right screen for the session: sign in, the name step, or the app.
class _Gate extends StatelessWidget {
  const _Gate();

  @override
  Widget build(BuildContext context) {
    final auth = AppScope.of(context).auth;

    switch (auth.status) {
      case AuthStatus.starting:
        return const Scaffold(body: Center(child: CircularProgressIndicator()));

      case AuthStatus.unreachable:
        return FullScreenMessage(
          title: 'No connection to the server',
          message: auth.startError ?? 'Check your connection and try again.',
          actionLabel: 'Try again',
          onAction: auth.start,
          secondaryLabel: 'Sign out',
          onSecondary: auth.signOut,
        );

      case AuthStatus.signedOut:
        return const SignInPage();

      case AuthStatus.signedIn:
        final user = auth.user!;

        // Owners and administrators use the web app.
        if (!user.isCaretaker) {
          return FullScreenMessage(
            title: 'This app is for caretakers',
            message:
                'The number ${user.phone} is not registered as a caretaker. If you are a caretaker, ask the property owner to add this number. Owners use the web app.',
            actionLabel: 'Sign out',
            onAction: auth.signOut,
          );
        }

        if (user.needsName) return const NamePage();

        return const HomePage();
    }
  }
}
