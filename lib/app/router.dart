import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../core/app_scope.dart';
import '../features/auth/name_page.dart';
import '../features/auth/sign_in_page.dart';
import '../features/expenses/expenses_page.dart';
import '../features/home/home_page.dart';
import '../features/landing/intro_page.dart';
import '../features/landing/welcome_page.dart';
import '../features/profile/profile_page.dart';
import '../features/repairs/repairs_page.dart';
import '../features/units/units_tab.dart';
import '../features/water/water_tab.dart';
import '../widgets/message_box.dart';
import 'app_shell.dart';
import 'routes.dart';

/// The app's pages and the rule for who may see which.
GoRouter buildRouter(AppServices services) {
  return GoRouter(
    initialLocation: Routes.units,
    // Looks again at the rule whenever the session or the intro choice changes.
    refreshListenable: Listenable.merge([services.auth, services.preferences]),
    redirect: (context, state) => redirectFor(
      status: services.auth.status,
      user: services.auth.user,
      introSeen: services.preferences.introSeen,
      location: state.matchedLocation,
      // A property chosen before: straight to its units. If it is no longer
      // theirs, the tabs send them to Home (see PropertyGate).
      propertyChosen: services.preferences.selectedPropertyId != null,
    ),
    routes: [
      GoRoute(
        path: Routes.starting,
        builder: (context, state) => const Scaffold(body: LoadingView()),
      ),
      GoRoute(
        path: Routes.offline,
        builder: (context, state) => FullScreenMessage(
          icon: Icons.cloud_off_outlined,
          title: 'No connection to the server',
          message:
              services.auth.startError ??
              'Check your connection and try again.',
          actionLabel: 'Try again',
          onAction: services.auth.start,
          secondaryLabel: 'Sign out',
          onSecondary: services.auth.signOut,
        ),
      ),
      GoRoute(
        path: Routes.welcome,
        builder: (context, state) => const WelcomePage(),
      ),
      GoRoute(
        path: Routes.intro,
        builder: (context, state) => const IntroPage(),
      ),
      GoRoute(
        path: Routes.signIn,
        builder: (context, state) => const SignInPage(),
      ),
      GoRoute(path: Routes.name, builder: (context, state) => const NamePage()),
      GoRoute(
        path: Routes.notCaretaker,
        builder: (context, state) => FullScreenMessage(
          icon: Icons.person_off_outlined,
          title: 'This app is for caretakers',
          message:
              'The number ${services.auth.user?.phone ?? ''} is not registered as a caretaker. '
              'If you are one, ask the property owner to add this number. Owners use the web app.',
          actionLabel: 'Sign out',
          onAction: services.auth.signOut,
        ),
      ),
      // Home: choosing the property. No tabs here; they belong to a property.
      GoRoute(path: Routes.home, builder: (context, state) => const HomePage()),
      StatefulShellRoute.indexedStack(
        builder: (context, state, shell) => AppShell(shell: shell),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: Routes.units,
                builder: (context, state) => const UnitsTab(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: Routes.expenses,
                builder: (context, state) => const ExpensesTab(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: Routes.repairs,
                builder: (context, state) => const RepairsTab(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: Routes.water,
                builder: (context, state) => const WaterTab(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: Routes.profile,
                builder: (context, state) => const ProfilePage(),
              ),
            ],
          ),
        ],
      ),
    ],
  );
}
