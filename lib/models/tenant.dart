import '../core/api_client.dart';

double _number(Object? value) => (value as num?)?.toDouble() ?? 0;

/// The day part of a date the server sends ("2026-09-01T21:00:00.000Z" or "2026-09-01").
DateTime? parseDay(Object? value) {
  if (value is! String || value.isEmpty) return null;

  final parsed = DateTime.tryParse(value);

  return parsed?.toLocal();
}

/// Someone renting a unit.
class Tenant {
  const Tenant({
    required this.id,
    required this.unitId,
    required this.unitNumber,
    required this.fullName,
    required this.phone,
    required this.paymentPhone,
    required this.email,
    required this.nationalId,
    required this.moveInDate,
    required this.moveOutDate,
    required this.monthlyRent,
    required this.status,
    required this.balance,
    required this.creditBalance,
  });

  factory Tenant.fromJson(Json json) {
    return Tenant(
      id: '${json['id']}',
      unitId: '${json['unit_id']}',
      unitNumber: json['unit_number'] as String? ?? '',
      fullName: json['full_name'] as String? ?? '',
      phone: json['phone'] as String? ?? '',
      paymentPhone: json['payment_phone'] as String?,
      email: json['email'] as String?,
      nationalId: json['national_id'] as String?,
      moveInDate: parseDay(json['move_in_date']),
      moveOutDate: parseDay(json['move_out_date']),
      monthlyRent: _number(json['monthly_rent']),
      status: json['status'] as String? ?? 'active',
      balance: _number(json['balance']),
      creditBalance: _number(json['credit_balance']),
    );
  }

  final String id;
  final String unitId;
  final String unitNumber;
  final String fullName;
  final String phone;
  final String? paymentPhone;
  final String? email;
  final String? nationalId;
  final DateTime? moveInDate;
  final DateTime? moveOutDate;
  final double monthlyRent;

  /// active, notice_given, moved_out or inactive.
  final String status;

  /// What they owe now; 0 when settled.
  final double balance;

  /// Paid ahead, used for their next bills.
  final double creditBalance;

  bool get isCurrent => status == 'active' || status == 'notice_given';
  bool get owes => balance > 0;

  String get statusLabel => switch (status) {
    'notice_given' => 'Notice given',
    'moved_out' => 'Moved out',
    'inactive' => 'Inactive',
    _ => 'Active',
  };
}

/// One bill on a tenant's statement.
class StatementCharge {
  const StatementCharge({
    required this.id,
    required this.type,
    required this.description,
    required this.dueDate,
    required this.amountDue,
    required this.amountPaid,
    required this.balance,
    required this.status,
  });

  factory StatementCharge.fromJson(Json json) {
    return StatementCharge(
      id: '${json['id']}',
      type: json['charge_type'] as String? ?? '',
      description: json['description'] as String?,
      dueDate: parseDay(json['due_date_text'] ?? json['due_date']),
      amountDue: _number(json['amount_due']),
      amountPaid: _number(json['amount_paid']),
      balance: _number(json['balance']),
      status: json['status'] as String? ?? '',
    );
  }

  final String id;
  final String type;
  final String? description;
  final DateTime? dueDate;
  final double amountDue;
  final double amountPaid;
  final double balance;

  /// open, partial, paid, void or held.
  final String status;

  String get label {
    if (description != null && description!.isNotEmpty) return description!;

    return switch (type) {
      'rent' => 'Rent',
      'rent_deposit' => 'Rent deposit',
      'water' => 'Water',
      'water_deposit' => 'Water deposit',
      'electricity' => 'Electricity',
      'electricity_deposit' => 'Electricity deposit',
      'service' => 'Service charge',
      'repair' => 'Repair',
      _ => type,
    };
  }
}

/// One payment on a tenant's statement.
class StatementPayment {
  const StatementPayment({
    required this.id,
    required this.amount,
    required this.method,
    required this.reference,
    required this.receivedAt,
  });

  factory StatementPayment.fromJson(Json json) {
    return StatementPayment(
      id: '${json['id']}',
      amount: _number(json['amount']),
      method: json['payment_method'] as String? ?? '',
      reference:
          json['reference'] as String? ??
          json['provider_transaction_id'] as String?,
      receivedAt: parseDay(json['received_at']),
    );
  }

  final String id;
  final double amount;
  final String method;
  final String? reference;
  final DateTime? receivedAt;
}

/// A tenant's bills and payments for a period, with what they owe overall.
class TenantStatement {
  const TenantStatement({
    required this.charges,
    required this.payments,
    required this.outstanding,
    required this.credit,
  });

  factory TenantStatement.fromJson(Json json) {
    return TenantStatement(
      charges: [
        for (final row in json['charges'] as List? ?? const [])
          StatementCharge.fromJson(row as Json),
      ],
      payments: [
        for (final row in json['payments'] as List? ?? const [])
          StatementPayment.fromJson(row as Json),
      ],
      outstanding: _number(json['outstanding_balance']),
      credit: _number(json['credit_balance']),
    );
  }

  final List<StatementCharge> charges;
  final List<StatementPayment> payments;
  final double outstanding;
  final double credit;
}
