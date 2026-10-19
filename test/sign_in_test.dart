import 'package:caretaker_app/core/theme/app_theme.dart';
import 'package:caretaker_app/features/auth/auth_layout.dart';
import 'package:caretaker_app/widgets/brand.dart';
import 'package:caretaker_app/widgets/code_boxes.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget inApp(Widget page, {Brightness brightness = Brightness.light}) {
  return MaterialApp(theme: buildTheme(brightness), home: page);
}

void main() {
  testWidgets('the sign-in screen: the brand panel takes the top half', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      inApp(
        const AuthLayout(
          title: 'Sign in',
          subtitle:
              'Use the phone number the property owner registered for you.',
          children: [Text('form')],
        ),
      ),
    );

    final screen = tester.getSize(find.byType(Scaffold)).height;
    final panel = tester.getSize(find.byType(BrandPanel)).height;

    expect(panel, closeTo(screen / 2, 1));
    expect(
      tester.getTopLeft(find.text('form')).dy,
      greaterThanOrEqualTo(screen / 2),
    );
    expect(tester.takeException(), isNull);
  });

  for (final brightness in Brightness.values) {
    testWidgets(
      'the code is six boxes, filled as you type (${brightness.name})',
      (tester) async {
        final code = TextEditingController();
        final completed = <String>[];

        await tester.pumpWidget(
          inApp(
            Scaffold(
              body: Padding(
                padding: const EdgeInsets.all(24),
                child: CodeBoxes(controller: code, onCompleted: completed.add),
              ),
            ),
            brightness: brightness,
          ),
        );

        // Six empty boxes.
        expect(find.byType(AnimatedContainer), findsNWidgets(6));

        await tester.enterText(find.byType(TextField), '12');
        await tester.pump();
        expect(find.text('1'), findsOneWidget);
        expect(find.text('2'), findsOneWidget);
        expect(completed, isEmpty);

        // Only digits, at most six (a pasted code fills every box).
        await tester.enterText(find.byType(TextField), '12a34567');
        await tester.pump();
        expect(code.text, '123456');
        expect(completed, ['123456']);
        for (final digit in ['1', '2', '3', '4', '5', '6']) {
          expect(find.text(digit), findsOneWidget);
        }

        // Backspace empties the last box.
        await tester.enterText(find.byType(TextField), '12345');
        await tester.pump();
        expect(find.text('6'), findsNothing);
        expect(tester.takeException(), isNull);
      },
    );
  }
}
