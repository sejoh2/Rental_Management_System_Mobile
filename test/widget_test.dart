import 'package:caretaker_app/core/api_client.dart';
import 'package:caretaker_app/models/app_user.dart';
import 'package:caretaker_app/models/caretaker_property.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'IDs are kept as text, whether the server sends a number or a string',
    () {
      final fromNumber = AppUser.fromJson({'user_id': 42, 'role': 'caretaker'});
      final fromText = AppUser.fromJson({
        'user_id': 'usr_8f3a',
        'role': 'caretaker',
      });

      expect(fromNumber.id, '42');
      expect(fromText.id, 'usr_8f3a');
    },
  );

  test('a user who has not entered a name is asked for it', () {
    final user = AppUser.fromJson({
      'user_id': 1,
      'first_name': 'New',
      'last_name': 'User',
      'needs_name': true,
      'role': 'caretaker',
    });

    expect(user.needsName, isTrue);
    expect(user.isCaretaker, isTrue);
    expect(user.fullName, 'New User');
  });

  test('a property carries what the caretaker may do in it', () {
    final property = CaretakerProperty.fromJson({
      'id': 1,
      'name': 'Test Apartment',
      'location': 'Nairobi',
      'total_units': 10,
      'occupied_units': 7,
      'water_billing_method': 'per_unit_metered',
      'can_manage_tenants': true,
      'can_record_payments': false,
    });

    expect(property.id, '1');
    expect(property.vacantUnits, 3);
    expect(property.readsMeters, isTrue);
    expect(property.canManageTenants, isTrue);
    expect(property.canRecordPayments, isFalse);
  });

  test('each thing being saved gets its own key the server accepts', () {
    final first = ApiClient.newSaveKey();
    final second = ApiClient.newSaveKey();

    expect(first, matches(RegExp(r'^[0-9a-f]{32}$')));
    expect(first, isNot(second));
  });
}
