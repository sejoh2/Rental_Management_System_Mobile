import 'dart:convert';

import 'package:caretaker_app/app/app.dart';
import 'package:caretaker_app/core/api_client.dart';
import 'package:caretaker_app/core/app_scope.dart';
import 'package:caretaker_app/core/auth_controller.dart';
import 'package:caretaker_app/core/notices_controller.dart';
import 'package:caretaker_app/core/preferences.dart';
import 'package:caretaker_app/core/properties_controller.dart';
import 'package:caretaker_app/core/session_store.dart';
import 'package:caretaker_app/data/property_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// A session kept in memory: the phone's protected storage is not there in tests.
class _MemorySession extends SessionStore {
  @override
  Future<void> load() async {
    accessToken = 'access';
    refreshToken = 'refresh';
  }

  @override
  Future<void> save({required String access, required String refresh}) async {
    accessToken = access;
    refreshToken = refresh;
  }

  @override
  Future<void> clear() async {
    accessToken = null;
    refreshToken = null;
  }
}

const _tenant = {
  'id': 7,
  'unit_id': 1,
  'unit_number': 'A1',
  'full_name': 'Grace Wanjiru',
  'phone': '+254712000111',
  'payment_phone': '+254712000111',
  'move_in_date': '2026-03-01',
  'monthly_rent': 9000,
  'status': 'notice_given',
  'notice_date': '2026-10-15',
  'balance': 2500,
  'credit_balance': 0,
  'rent_deposit_due': 9000,
  'water_deposit_due': 1000,
  'water_payment_reference': 'A1-GRACE',
};

Map<String, dynamic> _unit(int id, String number, {bool occupied = false}) => {
  'id': id,
  'property_id': 1,
  'unit_number': number,
  'unit_type': 'one_bedroom',
  'block_or_floor': 'Ground',
  'monthly_rent': 9000,
  'rent_deposit': 9000,
  'water_deposit': 1000,
  'water_billing_method': 'per_unit_metered',
  'water_rate_per_unit': 150,
  'water_meter_number': 'M-$number',
  'electricity_billing_method': 'entered',
  'electricity_monthly_charge': null,
  'electricity_deposit': 2000,
  'status': occupied ? 'occupied' : 'vacant',
  'current_tenant': occupied
      ? {
          'tenant_id': 7,
          'full_name': 'Grace Wanjiru',
          'status': 'notice_given',
          'balance': 2500,
        }
      : null,
};

const _repair = {
  'id': 4,
  'property_id': 1,
  'property_name': 'Green Court',
  'unit_id': 1,
  'unit_number': 'A1',
  'unit_tenant_name': 'Grace Wanjiru',
  'title': 'Leaking kitchen tap',
  'category': 'plumbing',
  'priority': 'urgent',
  'status': 'reported',
  'reporter_name': 'Alice Wanjiru',
  'assigned_caretaker_id': 11,
  'caretaker_notice': 'assigned',
  'caretaker_notice_at': '2026-10-19T08:00:00.000Z',
  'created_at': '2026-10-19T08:00:00.000Z',
};

Map<String, dynamic> _property(int id, String name) => {
  'id': id,
  'name': name,
  'location': 'Thika',
  'total_units': 2,
  'occupied_units': 1,
  'water_billing_method': 'per_unit_metered',
  'water_rate_per_unit': 150,
  'move_in_billing': 'prorated',
  'rent_due_day': 5,
  'permission_level': 'level_2',
  'can_manage_tenants': true,
  'can_record_payments': true,
  'permissions': {
    'can_read_meters': true,
    'can_enter_electricity': true,
    'can_manage_maintenance': true,
    'can_add_expenses': true,
    'can_view_tenants': true,
    'can_manage_tenants': true,
    'can_record_payments': true,
  },
};

/// The server, as the caretaker app sees it.
http.Response _answer(http.Request request) {
  final path = request.url.path;

  Object? data;

  if (path == '/api/auth/me') {
    return http.Response(
      jsonEncode({
        'success': true,
        'user': {
          'user_id': 11,
          'first_name': 'Cate',
          'last_name': 'Taker',
          'phone': '+254722000003',
          'role': 'caretaker',
        },
        'subscription': {'read_only': true},
        'owner': {'full_name': 'Alice Wanjiru', 'phone': '+254711000001'},
      }),
      200,
    );
  }

  if (path == '/api/caretaker/properties') {
    data = [_property(1, 'Green Court'), _property(2, 'Blue Court')];
  } else if (RegExp(r'^/api/properties/\d+/units$').hasMatch(path)) {
    data = [_unit(1, 'A1', occupied: true), _unit(2, 'A2')];
  } else if (path == '/api/units/1') {
    data = _unit(1, 'A1', occupied: true);
  } else if (path == '/api/units/2') {
    data = _unit(2, 'A2');
  } else if (RegExp(r'^/api/properties/\d+/tenants$').hasMatch(path)) {
    data = [
      _tenant,
      {
        ..._tenant,
        'id': 8,
        'full_name': 'Old Tenant',
        'status': 'moved_out',
        'move_out_date': '2026-08-31',
        'balance': 0,
      },
    ];
  } else if (path == '/api/tenants/7') {
    data = _tenant;
  } else if (path.startsWith('/api/reports/tenants/7/statement')) {
    data = {
      'charges': [
        {
          'id': 1,
          'charge_type': 'rent',
          'amount_due': 9000,
          'amount_paid': 6500,
          'balance': 2500,
          'status': 'partial',
          'due_date': '2026-10-05',
        },
      ],
      'payments': [],
      'outstanding_balance': 2500,
      'credit_balance': 0,
    };
  } else if (path == '/api/files') {
    data = [];
  } else if (path == '/api/maintenance/notices') {
    data = [_repair];
  } else if (path == '/api/maintenance') {
    data = [_repair];
  } else if (path == '/api/maintenance/4') {
    data = _repair;
  } else if (RegExp(r'^/api/properties/\d+/water-readings$').hasMatch(path)) {
    data = [];
  } else if (RegExp(
    r'^/api/properties/\d+/electricity-bills$',
  ).hasMatch(path)) {
    data = {
      'period': '2026-10',
      'bills': [
        {
          'unit_id': 1,
          'unit_number': 'A1',
          'tenant_id': 7,
          'tenant_name': 'Grace Wanjiru',
          'amount': 1500,
          'amount_paid': 0,
          'status': 'open',
        },
        {
          'unit_id': 2,
          'unit_number': 'A2',
          'tenant_id': null,
          'tenant_name': null,
          'amount': null,
          'amount_paid': 0,
          'status': null,
        },
      ],
    };
  } else if (RegExp(r'^/api/properties/\d+/service-charges$').hasMatch(path)) {
    data = [];
  } else if (path == '/api/expenses') {
    data = [];
  } else {
    return http.Response(
      jsonEncode({'success': false, 'error': 'Not in the test: $path'}),
      404,
    );
  }

  return http.Response(jsonEncode({'success': true, 'data': data}), 200);
}

Future<AppServices> _services() async {
  SharedPreferences.setMockInitialValues({});

  final preferences = AppPreferences();

  await preferences.load();

  final session = _MemorySession();
  final api = ApiClient(
    baseUrl: 'http://test',
    session: session,
    httpClient: MockClient((request) async => _answer(request)),
  );
  final auth = AuthController(api: api, session: session);
  final properties = PropertiesController(
    repository: PropertyRepository(api),
    preferences: preferences,
  );

  auth.addListener(() {
    if (auth.status == AuthStatus.signedIn && properties.properties == null) {
      properties.load();
    }
  });

  return AppServices(
    api: api,
    auth: auth,
    preferences: preferences,
    properties: properties,
    notices: NoticesController(api: api, auth: auth, properties: properties),
  );
}

void main() {
  for (final brightness in Brightness.values) {
    testWidgets('a caretaker goes through every screen (${brightness.name})', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1080, 2340);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      tester.platformDispatcher.platformBrightnessTestValue = brightness;
      addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);

      final services = await _services();

      await tester.pumpWidget(CaretakerApp(services: services));
      await services.auth.start();
      await tester.pumpAndSettle();

      // Home: two properties to choose from, nothing chosen yet.
      expect(find.text('Choose the property to work on.'), findsOneWidget);
      expect(find.text('Green Court'), findsOneWidget);
      expect(find.text('Blue Court'), findsOneWidget);
      expect(tester.takeException(), isNull);

      await tester.tap(find.text('Green Court'));
      await tester.pumpAndSettle();

      // Units, with the read-only banner and the bell.
      expect(
        find.textContaining('read-only until the owner pays'),
        findsOneWidget,
      );
      expect(find.text('Grace Wanjiru'), findsOneWidget);
      expect(find.text('Former tenants'), findsOneWidget);
      expect(find.text('Change'), findsOneWidget);
      expect(tester.takeException(), isNull);

      await tester.ensureVisible(find.text('Former tenants'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Former tenants'));
      await tester.pumpAndSettle();
      expect(find.text('Old Tenant'), findsOneWidget);
      await tester.ensureVisible(find.text('All'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('All'));
      await tester.pumpAndSettle();

      // A unit, then its tenant.
      await tester.tap(find.text('Grace Wanjiru'));
      await tester.pumpAndSettle();
      expect(find.text('House A1'), findsOneWidget);
      expect(find.text('Rent deposit'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.text('Amount typed in each month'),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('M-A1'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.scrollUntilVisible(
        find.text('Grace Wanjiru'),
        -300,
        scrollable: find.byType(Scrollable).first,
      );

      await tester.tap(find.text('Grace Wanjiru'));
      await tester.pumpAndSettle();
      expect(find.text('Cancel notice'), findsOneWidget);
      expect(find.text('Record a payment'), findsOneWidget);
      expect(find.text('A1-GRACE'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.textContaining('Statement PDF'),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      expect(tester.takeException(), isNull);

      // The payment form, with the web's words.
      await tester.scrollUntilVisible(
        find.text('Record a payment'),
        -300,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.text('Record a payment'));
      await tester.pumpAndSettle();
      expect(find.text('Apply to'), findsOneWidget);
      expect(
        find.textContaining('kept as credit for the next bill'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
      await tester.pageBack();
      await tester.pumpAndSettle();
      await tester.pageBack();
      await tester.pumpAndSettle();
      await tester.pageBack();
      await tester.pumpAndSettle();

      // A vacant unit: add a tenant there, with the move-in costs.
      await tester.tap(find.text('Vacant').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Add a tenant here'));
      await tester.pumpAndSettle();
      // The keyboard opens: the form keeps all the room above it (the
      // keyboard's height is taken away once, not twice).
      tester.view.viewInsets = const FakeViewPadding(bottom: 900);
      await tester.pumpAndSettle();
      final form = find
          .ancestor(
            of: find.text('Full names'),
            matching: find.byType(Scrollable),
          )
          .first;
      // 780 tall, keyboard 300: the form reaches down to the keyboard's top
      // (480), with no empty gap above it.
      expect(tester.getBottomLeft(form).dy, closeTo(480, 1));
      expect(tester.getSize(form).height, greaterThan(200));
      expect(
        find.text('Profile'),
        findsNothing,
        reason: 'tabs hidden while typing',
      );
      tester.view.resetViewInsets();
      await tester.pumpAndSettle();
      expect(find.text('Due at move-in for House A2'), findsOneWidget);
      expect(find.text('Electricity deposit'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pageBack();
      await tester.pumpAndSettle();
      await tester.pageBack();
      await tester.pumpAndSettle();

      // Expenses.
      await tester.tap(find.text('Expenses').last);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);

      // Repairs: the new one, given to this caretaker.
      await tester.tap(find.text('Maintenance').last);
      await tester.pumpAndSettle();
      expect(find.text('Leaking kitchen tap'), findsOneWidget);
      expect(find.text('New'), findsOneWidget);
      expect(find.text('Yours'), findsOneWidget);
      await tester.tap(find.textContaining('Mine'));
      await tester.pumpAndSettle();
      expect(find.text('Leaking kitchen tap'), findsOneWidget);
      await tester.tap(find.text('Leaking kitchen tap'));
      await tester.pumpAndSettle();
      expect(find.text('You'), findsOneWidget);
      expect(find.text('I’ll handle it'), findsNothing);
      await tester.tap(find.text('Mark as resolved'));
      await tester.pumpAndSettle();
      expect(find.text('Actual cost (optional)'), findsOneWidget);
      expect(find.text('Who pays for this repair'), findsOneWidget);
      expect(tester.takeException(), isNull);
      Navigator.of(tester.element(find.text('Actual cost (optional)'))).pop();
      await tester.pumpAndSettle();
      await tester.pageBack();
      await tester.pumpAndSettle();

      // Water & Electricity.
      await tester.tap(find.text('Water & Power'));
      await tester.pumpAndSettle();
      expect(find.text('Water & Electricity'), findsOneWidget);
      await tester.tap(find.text('Electricity'));
      await tester.pumpAndSettle();
      expect(find.text('Vacant - not billed'), findsOneWidget);
      expect(find.text('No changes'), findsOneWidget);
      expect(tester.takeException(), isNull);

      // Profile.
      await tester.tap(find.text('Profile'));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('Call Alice Wanjiru'),
        300,
        scrollable: find.byType(Scrollable).last,
      );
      expect(find.text('Call Alice Wanjiru'), findsOneWidget);
      expect(find.text('Manage tenants'), findsNWidgets(2));
      expect(find.text('Record payments'), findsNWidgets(2));
      expect(tester.takeException(), isNull);

      // The bell: the repair was opened, so nothing is new now; the list
      // looks again when it opens.
      expect(find.byTooltip('Notifications'), findsOneWidget);
      await tester.tap(find.byTooltip('Notifications'));
      await tester.pumpAndSettle();
      expect(find.text('The owner assigned you a request'), findsOneWidget);
      expect(tester.takeException(), isNull);

      services.notices.dispose();
    });
  }
}
