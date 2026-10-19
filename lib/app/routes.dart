import '../core/auth_controller.dart';
import '../models/app_user.dart';

/// Every page address in the app, in one place.
abstract final class Routes {
  static const starting = '/starting';
  static const offline = '/offline';
  static const welcome = '/welcome';
  static const intro = '/intro';
  static const signIn = '/sign-in';
  static const name = '/name';
  static const notCaretaker = '/not-caretaker';

  /// Choosing the property to work on: the one place to switch.
  static const home = '/home';

  // The tabs, for the chosen property.
  static const units = '/units';
  static const expenses = '/expenses';
  static const repairs = '/repairs';
  static const water = '/water';
  static const profile = '/profile';
}

const _signedOutPages = {Routes.welcome, Routes.intro, Routes.signIn};

const _gatePages = {
  Routes.starting,
  Routes.offline,
  Routes.name,
  Routes.notCaretaker,
  ..._signedOutPages,
};

/// Where someone at [location] must be sent, or null to let them stay.
///
/// Kept apart from the router so it can be tested on its own:
/// - while the app finds out who is signed in: the starting screen;
/// - signed out: the welcome screen and intro the first time, sign-in after;
/// - signed in as someone who is not a caretaker: an explanation;
/// - signed in for the first time: the name step;
/// - otherwise the app, never the sign-in pages: the units of the property
///   last worked on, or Home to choose one.
String? redirectFor({
  required AuthStatus status,
  required AppUser? user,
  required bool introSeen,
  required String location,
  bool propertyChosen = false,
}) {
  switch (status) {
    case AuthStatus.starting:
      return location == Routes.starting ? null : Routes.starting;

    case AuthStatus.unreachable:
      return location == Routes.offline ? null : Routes.offline;

    case AuthStatus.signedOut:
      if (_signedOutPages.contains(location)) return null;

      return introSeen ? Routes.signIn : Routes.welcome;

    case AuthStatus.signedIn:
      if (user == null) return Routes.signIn;

      if (!user.isCaretaker) {
        return location == Routes.notCaretaker ? null : Routes.notCaretaker;
      }

      if (user.needsName) return location == Routes.name ? null : Routes.name;

      if (!_gatePages.contains(location)) return null;

      return propertyChosen ? Routes.units : Routes.home;
  }
}
