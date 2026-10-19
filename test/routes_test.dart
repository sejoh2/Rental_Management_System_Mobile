import 'package:caretaker_app/app/routes.dart';
import 'package:caretaker_app/core/auth_controller.dart';
import 'package:caretaker_app/models/app_user.dart';
import 'package:flutter_test/flutter_test.dart';

AppUser user({String role = 'caretaker', bool needsName = false}) {
  return AppUser.fromJson({
    'user_id': 7,
    'first_name': 'Mary',
    'last_name': 'Wanjiku',
    'phone': '+254712345678',
    'role': role,
    'needs_name': needsName,
  });
}

String? go(
  String location,
  AuthStatus status, {
  AppUser? who,
  bool introSeen = false,
  bool propertyChosen = false,
}) {
  return redirectFor(
    status: status,
    user: who,
    introSeen: introSeen,
    location: location,
    propertyChosen: propertyChosen,
  );
}

void main() {
  group('while the app finds out who is signed in', () {
    test('everyone waits on the starting screen', () {
      expect(go(Routes.home, AuthStatus.starting), Routes.starting);
      expect(go(Routes.starting, AuthStatus.starting), isNull);
    });

    test('no connection shows the offline screen', () {
      expect(go(Routes.home, AuthStatus.unreachable), Routes.offline);
    });
  });

  group('signed out', () {
    test('the first time: the welcome screen', () {
      expect(go(Routes.home, AuthStatus.signedOut), Routes.welcome);
    });

    test('after the intro was seen: straight to sign-in', () {
      expect(
        go(Routes.home, AuthStatus.signedOut, introSeen: true),
        Routes.signIn,
      );
    });

    test('the welcome, intro and sign-in screens stay open', () {
      for (final page in [Routes.welcome, Routes.intro, Routes.signIn]) {
        expect(go(page, AuthStatus.signedOut), isNull, reason: page);
      }
    });

    test('app pages are never shown', () {
      expect(
        go(Routes.water, AuthStatus.signedOut, introSeen: true),
        Routes.signIn,
      );
      expect(
        go(Routes.profile, AuthStatus.signedOut, introSeen: true),
        Routes.signIn,
      );
    });
  });

  group('signed in', () {
    test('with no property chosen yet: Home, to choose one', () {
      expect(go(Routes.signIn, AuthStatus.signedIn, who: user()), Routes.home);
      expect(go(Routes.welcome, AuthStatus.signedIn, who: user()), Routes.home);
      expect(
        go(Routes.starting, AuthStatus.signedIn, who: user()),
        Routes.home,
      );
    });

    test('with a property chosen before: straight to its units', () {
      expect(
        go(
          Routes.starting,
          AuthStatus.signedIn,
          who: user(),
          propertyChosen: true,
        ),
        Routes.units,
      );
      expect(
        go(
          Routes.signIn,
          AuthStatus.signedIn,
          who: user(),
          propertyChosen: true,
        ),
        Routes.units,
      );
    });

    test('a caretaker can open Home and every tab', () {
      for (final page in [
        Routes.home,
        Routes.units,
        Routes.expenses,
        Routes.repairs,
        Routes.water,
        Routes.profile,
      ]) {
        expect(
          go(page, AuthStatus.signedIn, who: user()),
          isNull,
          reason: page,
        );
      }
    });

    test('the first sign-in asks for the name first', () {
      expect(
        go(Routes.home, AuthStatus.signedIn, who: user(needsName: true)),
        Routes.name,
      );
      expect(
        go(Routes.name, AuthStatus.signedIn, who: user(needsName: true)),
        isNull,
      );
    });

    test('an owner or admin is told the app is for caretakers', () {
      expect(
        go(Routes.home, AuthStatus.signedIn, who: user(role: 'owner')),
        Routes.notCaretaker,
      );
      expect(
        go(Routes.notCaretaker, AuthStatus.signedIn, who: user(role: 'admin')),
        isNull,
      );
    });
  });
}
