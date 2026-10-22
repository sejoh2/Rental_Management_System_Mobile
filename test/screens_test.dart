import 'package:caretaker_app/core/theme/app_theme.dart';
import 'package:caretaker_app/features/landing/intro_page.dart';
import 'package:caretaker_app/features/landing/welcome_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget inApp(Widget page, {Brightness brightness = Brightness.light}) {
  return MaterialApp(theme: buildTheme(brightness), home: page);
}

void main() {
  for (final brightness in Brightness.values) {
    testWidgets('the welcome screen shows the way in (${brightness.name})', (
      tester,
    ) async {
      await tester.pumpWidget(
        inApp(const WelcomePage(), brightness: brightness),
      );

      expect(
        find.text('Your property work, done from your phone.'),
        findsOneWidget,
      );
      expect(find.text('Get started'), findsOneWidget);
      expect(find.text('I already have an account'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('the intro moves through its three slides', (tester) async {
    await tester.pumpWidget(inApp(const IntroPage()));

    expect(find.text('Meter readings, with proof'), findsOneWidget);
    expect(find.text('Next'), findsOneWidget);
    expect(find.text('Skip'), findsOneWidget);

    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();
    expect(find.text('Maintenance and expenses'), findsOneWidget);

    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();
    expect(find.text('Your work, under your name'), findsOneWidget);
    expect(
      find.text('Sign in'),
      findsOneWidget,
      reason: 'the last slide leads to sign-in',
    );
  });
}
