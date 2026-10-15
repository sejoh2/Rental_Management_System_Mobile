import '../core/api_client.dart';
import '../models/electricity_bill.dart';
import '../models/expense.dart';

/// The server calls for expenses and electricity bills.
class ExpenseRepository {
  const ExpenseRepository(this.api);

  final ApiClient api;

  /// One month's expenses for a property.
  Future<List<Expense>> list(String propertyId, DateTime month) async {
    final last = DateTime(month.year, month.month + 1, 0);

    String day(DateTime date) =>
        '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

    final response = await api.get(
      '/api/expenses',
      query: {
        'property_id': propertyId,
        'from_date': day(DateTime(month.year, month.month)),
        'to_date': day(last),
      },
    );

    return [
      for (final row in response['data'] as List? ?? const [])
        Expense.fromJson(row as Json),
    ];
  }

  Future<Expense> create(
    String propertyId, {
    required String category,
    required double amount,
    required String date,
    String? notes,
    String? unitId,
    required String saveKey,
  }) async {
    final response = await api.post(
      '/api/properties/$propertyId/expenses',
      saveKey: saveKey,
      body: {
        'category': category,
        'amount': amount,
        'expense_date': date,
        'notes': ?notes,
        if (unitId != null) 'unit_id': int.parse(unitId),
      },
    );

    return Expense.fromJson(response['data'] as Json);
  }

  /// period: "2026-10"
  Future<ElectricityMonth> electricity(String propertyId, String period) async {
    final response = await api.get(
      '/api/properties/$propertyId/electricity-bills',
      query: {'period': period},
    );

    return ElectricityMonth.fromJson(response['data'] as Json);
  }

  /// Saves the typed amounts; zero removes a bill not paid yet.
  Future<void> saveElectricity(
    String propertyId,
    String period,
    Map<String, double> amountsByUnit,
  ) {
    return api.put(
      '/api/properties/$propertyId/electricity-bills',
      body: {
        'period': period,
        'bills': [
          for (final entry in amountsByUnit.entries)
            {'unit_id': int.parse(entry.key), 'amount': entry.value},
        ],
      },
    );
  }
}
