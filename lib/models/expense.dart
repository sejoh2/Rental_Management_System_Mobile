import '../core/api_client.dart';
import 'tenant.dart';

/// Money spent on a property: repairs, security, garbage and so on.
class Expense {
  const Expense({
    required this.id,
    required this.category,
    required this.amount,
    required this.date,
    required this.notes,
    required this.status,
    required this.unitNumber,
    required this.createdByName,
    required this.fromRepair,
  });

  factory Expense.fromJson(Json json) {
    return Expense(
      id: '${json['id']}',
      category: json['category'] as String? ?? 'other',
      amount: (json['amount'] as num?)?.toDouble() ?? 0,
      date: parseDay(json['expense_date']),
      notes: json['notes'] as String?,
      status: json['status'] as String? ?? 'active',
      unitNumber: json['unit_number'] as String?,
      createdByName: json['created_by_name'] as String?,
      fromRepair: json['maintenance_request_id'] != null,
    );
  }

  final String id;
  final String category;
  final double amount;
  final DateTime? date;
  final String? notes;

  /// active, or void when cancelled by the owner.
  final String status;

  /// Set when the cost was for one unit only.
  final String? unitNumber;
  final String? createdByName;

  /// Made by a repair being resolved, not typed in.
  final bool fromRepair;

  bool get isVoid => status == 'void';

  String get categoryLabel => ExpenseLabels.categories[category] ?? category;
}

abstract final class ExpenseLabels {
  static const categories = {
    'repairs_maintenance': 'Repairs & maintenance',
    'security': 'Security',
    'garbage': 'Garbage',
    'cleaning': 'Cleaning',
    'utilities': 'Utilities',
    'other': 'Other',
  };
}
