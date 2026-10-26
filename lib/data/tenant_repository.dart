import '../core/api_client.dart';
import '../models/tenant.dart';
import '../utils/format.dart';

/// The server calls for tenants, their statements and payments.
class TenantRepository {
  const TenantRepository(this.api);

  final ApiClient api;

  Future<List<Tenant>> list(String propertyId) async {
    final response = await api.get('/api/properties/$propertyId/tenants');

    return [
      for (final row in response['data'] as List? ?? const [])
        Tenant.fromJson(row as Json),
    ];
  }

  Future<Tenant> get(String tenantId) async {
    final response = await api.get('/api/tenants/$tenantId');

    return Tenant.fromJson(response['data'] as Json);
  }

  /// Moves a tenant into a vacant unit. Their deposits and first bills are
  /// worked out by the server.
  Future<Tenant> create(
    String propertyId, {
    required String unitId,
    required String fullName,
    required String phone,
    String? email,
    String? nationalId,
    required String moveInDate,
    required String saveKey,
  }) async {
    final response = await api.post(
      '/api/properties/$propertyId/tenants',
      saveKey: saveKey,
      body: {
        'unit_id': unitId,
        'full_name': fullName,
        'phone': phone,
        'email': ?email,
        'national_id': ?nationalId,
        'move_in_date': moveInDate,
      },
    );

    return Tenant.fromJson(response['data'] as Json);
  }

  Future<Tenant> update(
    String tenantId, {
    required String fullName,
    required String phone,
    String? email,
    String? nationalId,
  }) async {
    final response = await api.patch(
      '/api/tenants/$tenantId',
      body: {
        'full_name': fullName,
        'phone': phone,
        'email': email,
        'national_id': nationalId,
      },
    );

    return Tenant.fromJson(response['data'] as Json);
  }

  /// The tenant has said they are leaving ([date]), or, with null, has
  /// changed their mind. They stay a tenant until the owner moves them out.
  Future<Tenant> setNotice(String tenantId, DateTime? date) async {
    final response = await api.patch(
      '/api/tenants/$tenantId',
      body: date == null
          ? {'status': 'active', 'notice_date': null}
          : {'status': 'notice_given', 'notice_date': dayKey(date)},
    );

    return Tenant.fromJson(response['data'] as Json);
  }

  /// The statement as a PDF, as the owner downloads it on the web.
  Future<List<int>> statementPdf(String tenantId, String period) {
    return api.download(
      '/api/reports/tenants/$tenantId/statement/download',
      query: {'period': period},
    );
  }

  /// period: this_month, last_month, last_3_months, last_6_months or this_year.
  Future<TenantStatement> statement(String tenantId, String period) async {
    final response = await api.get(
      '/api/reports/tenants/$tenantId/statement',
      query: {'period': period},
    );

    return TenantStatement.fromJson(response['data'] as Json);
  }

  /// Records money handed over in person. Only for a caretaker the owner has
  /// allowed to record payments in this property.
  Future<void> recordPayment(
    String tenantId, {
    required double amount,
    required String method,
    required String accountFor,
    required DateTime receivedAt,
    String? reference,
    String? notes,
    required String saveKey,
  }) {
    return api.post(
      '/api/tenants/$tenantId/payments/manual',
      saveKey: saveKey,
      body: {
        'amount': amount,
        'payment_method': method,
        'account_for': accountFor,
        'received_at': receivedAt.toUtc().toIso8601String(),
        'reference': ?reference,
        'notes': ?notes,
      },
    );
  }
}
