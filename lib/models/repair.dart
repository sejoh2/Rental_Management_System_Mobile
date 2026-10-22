import '../core/api_client.dart';
import 'tenant.dart';

/// A maintenance request: something broken, and its repair.
class Repair {
  const Repair({
    required this.id,
    required this.unitId,
    required this.unitNumber,
    required this.unitTenantName,
    required this.title,
    required this.description,
    required this.category,
    required this.priority,
    required this.status,
    required this.reporterName,
    required this.vendorName,
    required this.estimatedCost,
    required this.actualCost,
    required this.chargeToTenant,
    required this.chargeTiming,
    required this.resolutionNotes,
    required this.cancellationReason,
    required this.createdAt,
    required this.resolvedAt,
    this.propertyId = '',
    this.propertyName,
    this.assignedCaretakerId,
    this.assignedCaretakerName,
    this.expenseId,
    this.tenantChargeId,
    this.chargeSmsSentAt,
    this.caretakerNotice,
    this.caretakerNoticeAt,
  });

  factory Repair.fromJson(Json json) {
    return Repair(
      id: '${json['id']}',
      unitId: json['unit_id'] == null ? null : '${json['unit_id']}',
      unitNumber: json['unit_number'] as String?,
      unitTenantName: json['unit_tenant_name'] as String?,
      title: json['title'] as String? ?? '',
      description: json['description'] as String?,
      category: json['category'] as String? ?? 'other',
      priority: json['priority'] as String? ?? 'normal',
      status: json['status'] as String? ?? 'reported',
      reporterName: json['reporter_name'] as String?,
      vendorName: json['assigned_vendor_name'] as String?,
      estimatedCost: (json['estimated_cost'] as num?)?.toDouble(),
      actualCost: (json['actual_cost'] as num?)?.toDouble(),
      chargeToTenant: json['charge_to_tenant'] == true,
      chargeTiming: json['charge_timing'] as String?,
      resolutionNotes: json['resolution_notes'] as String?,
      cancellationReason: json['cancellation_reason'] as String?,
      createdAt: parseDay(json['created_at']),
      resolvedAt: parseDay(json['resolved_at']),
      propertyId: '${json['property_id'] ?? ''}',
      propertyName: json['property_name'] as String?,
      assignedCaretakerId: json['assigned_caretaker_id'] == null
          ? null
          : '${json['assigned_caretaker_id']}',
      assignedCaretakerName: (json['assigned_caretaker_name'] as String?)
          ?.trim(),
      expenseId: json['expense_id'] == null ? null : '${json['expense_id']}',
      tenantChargeId: json['tenant_charge_id'] == null
          ? null
          : '${json['tenant_charge_id']}',
      chargeSmsSentAt: DateTime.tryParse(
        json['charge_sms_sent_at'] as String? ?? '',
      )?.toLocal(),
      caretakerNotice: json['caretaker_notice'] as String?,
      caretakerNoticeAt: DateTime.tryParse(
        json['caretaker_notice_at'] as String? ?? '',
      )?.toLocal(),
    );
  }

  final String id;
  final String? unitId;
  final String? unitNumber;
  final String? unitTenantName;
  final String title;
  final String? description;
  final String category;

  /// low, normal, high or urgent.
  final String priority;

  /// reported, in_progress, resolved or cancelled.
  final String status;
  final String? reporterName;
  final String? vendorName;
  final double? estimatedCost;
  final double? actualCost;
  final bool chargeToTenant;

  /// now or move_out, when the tenant pays.
  final String? chargeTiming;
  final String? resolutionNotes;
  final String? cancellationReason;
  final DateTime? createdAt;
  final DateTime? resolvedAt;

  final String propertyId;
  final String? propertyName;

  /// The caretaker handling it; null when the owner handles it.
  final String? assignedCaretakerId;
  final String? assignedCaretakerName;

  /// Set once the cost is recorded as an expense; it is then fixed.
  final String? expenseId;

  /// Set when the cost was charged to the tenant.
  final String? tenantChargeId;

  /// When the tenant was last sent an SMS about the charge.
  final DateTime? chargeSmsSentAt;

  /// New for the caretaker until opened: reported (by the owner) or
  /// assigned (given to them by the owner).
  final String? caretakerNotice;
  final DateTime? caretakerNoticeAt;

  bool get isOpen => status == 'reported' || status == 'in_progress';

  bool get costRecorded => expenseId != null;

  bool isFor(String? caretakerId) =>
      caretakerId != null && assignedCaretakerId == caretakerId;
}

/// The words used for repairs, as on the web.
abstract final class RepairLabels {
  static const categories = {
    'plumbing': 'Plumbing',
    'electrical': 'Electrical',
    'water': 'Water',
    'structural': 'Structural',
    'security': 'Security',
    'cleaning': 'Cleaning',
    'appliance': 'Appliance',
    'other': 'Other',
  };

  static const priorities = {
    'low': 'Low',
    'normal': 'Normal',
    'high': 'High',
    'urgent': 'Urgent',
  };

  /// Who pays, as on the web.
  static const payers = {'owner': 'Owner', 'tenant': 'Tenant'};

  static const chargeTimings = {
    'now': 'Now: from their credit or next payment',
    'move_out': 'At move-out: deducted from their deposit',
  };

  static const statuses = {
    'reported': 'Reported',
    'in_progress': 'In progress',
    'resolved': 'Resolved',
    'cancelled': 'Cancelled',
  };
}
