import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/api_client.dart';
import '../../core/app_scope.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text.dart';
import '../../core/theme/app_theme.dart';
import '../../data/tenant_repository.dart';
import '../../data/unit_repository.dart';
import '../../data/water_repository.dart';
import '../../models/caretaker_property.dart';
import '../../models/service_charge.dart';
import '../../models/tenant.dart';
import '../../models/unit.dart';
import '../../utils/format.dart';
import '../../widgets/cards.dart';
import '../../widgets/fields.dart';
import '../../widgets/message_box.dart';
import 'move_in_costs.dart';

/// Adds a tenant to a vacant unit, with what they owe on the day they move
/// in (as on the web), or edits a tenant's details.
/// Only for a caretaker who may manage tenants (level 2).
class TenantFormPage extends StatefulWidget {
  const TenantFormPage({
    super.key,
    required this.property,
    this.tenant,
    this.unitId,
  });

  final CaretakerProperty property;

  /// Set when editing.
  final Tenant? tenant;

  /// The unit to start with, when opened from a vacant unit.
  final String? unitId;

  @override
  State<TenantFormPage> createState() => _TenantFormPageState();
}

class _TenantFormPageState extends State<TenantFormPage> {
  late final _name = TextEditingController(text: widget.tenant?.fullName ?? '');
  late final _phone = TextEditingController(text: widget.tenant?.phone ?? '');
  late final _email = TextEditingController(text: widget.tenant?.email ?? '');
  late final _nationalId = TextEditingController(
    text: widget.tenant?.nationalId ?? '',
  );

  /// Made once for this tenant: sending again after a dropped connection never adds them twice.
  final _saveKey = ApiClient.newSaveKey();

  DateTime _moveIn = DateTime.now();
  List<Unit>? _vacant;
  late String? _unitId = widget.unitId;

  /// The property's service charges, for the move-in costs. Null while
  /// loading; a failure leaves them out of the total, with a note.
  List<ServiceCharge>? _charges;
  bool _chargesFailed = false;
  bool _saving = false;
  String? _error;
  bool _started = false;

  bool get _editing => widget.tenant != null;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    if (!_started) {
      _started = true;
      if (!_editing) {
        _loadUnits();
        _loadCharges();
      }
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _email.dispose();
    _nationalId.dispose();
    super.dispose();
  }

  Future<void> _loadUnits() async {
    try {
      final units = await WaterRepository(
        AppScope.read(context).api,
      ).listUnits(widget.property.id);
      // A tenant can only move into a vacant unit.
      final vacant = units.where((unit) => unit.isVacant).toList()
        ..sort((a, b) => a.unitNumber.compareTo(b.unitNumber));

      if (!mounted) return;

      setState(() {
        _vacant = vacant;
        if (!vacant.any((unit) => unit.id == _unitId)) _unitId = null;
      });
    } on ApiException catch (failure) {
      if (mounted) setState(() => _error = failure.message);
    }
  }

  Future<void> _loadCharges() async {
    try {
      final charges = await UnitRepository(
        AppScope.read(context).api,
      ).serviceCharges(widget.property.id);

      if (mounted) setState(() => _charges = charges);
    } on ApiException {
      if (mounted) setState(() => _chargesFailed = true);
    }
  }

  String? _optional(TextEditingController controller) {
    final text = controller.text.trim();

    return text.isEmpty ? null : text;
  }

  bool get _ready =>
      !_saving &&
      _name.text.trim().length >= 2 &&
      _phone.text.replaceAll(' ', '').length >= 9 &&
      (_editing || _unitId != null);

  Future<void> _save() async {
    setState(() {
      _saving = true;
      _error = null;
    });

    final repository = TenantRepository(AppScope.read(context).api);

    try {
      if (_editing) {
        await repository.update(
          widget.tenant!.id,
          fullName: _name.text.trim(),
          phone: _phone.text.replaceAll(' ', ''),
          email: _optional(_email),
          nationalId: _optional(_nationalId),
        );
      } else {
        await repository.create(
          widget.property.id,
          unitId: _unitId!,
          fullName: _name.text.trim(),
          phone: _phone.text.replaceAll(' ', ''),
          email: _optional(_email),
          nationalId: _optional(_nationalId),
          moveInDate: dayKey(_moveIn),
          saveKey: _saveKey,
        );
      }

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _editing
                ? 'Details saved.'
                : '${_name.text.trim()} added. Their first bills are ready.',
          ),
        ),
      );
      Navigator.pop(context, true);
    } on ApiException catch (failure) {
      if (mounted) {
        setState(() {
          _error = failure.message;
          _saving = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final vacant = _vacant;
    final unit = vacant?.where((item) => item.id == _unitId).firstOrNull;

    return Scaffold(
      appBar: AppBar(title: Text(_editing ? 'Edit details' : 'Add a tenant')),
      body: ListView(
        padding: const EdgeInsets.all(AppSpace.page),
        children: [
          if (!_editing) ...[
            if (vacant == null && _error == null)
              const LoadingView()
            else if (vacant != null && vacant.isEmpty)
              const NoteBox(
                'Every unit has a tenant. A unit becomes free when its tenant moves out.',
              )
            else if (vacant != null)
              SelectField<String>(
                label: 'House',
                value: _unitId,
                options: {
                  for (final unit in vacant)
                    unit.id:
                        'House ${unit.unitNumber} · ${unit.typeLabel} · ${formatKes(unit.monthlyRent)}',
                },
                onChanged: (value) => setState(() => _unitId = value),
              ),
            const SizedBox(height: AppSpace.lg),
          ],
          TextField(
            controller: _name,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(
              labelText: 'Full names',
              hintText: 'e.g. Grace Wanjiru',
            ),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: AppSpace.lg),
          TextField(
            controller: _phone,
            keyboardType: TextInputType.phone,
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[0-9+ ]')),
            ],
            decoration: const InputDecoration(
              labelText: 'Phone number',
              hintText: '0712 345 678',
              helperText:
                  'Their M-Pesa payments from this number are matched to them.',
            ),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: AppSpace.lg),
          TextField(
            controller: _nationalId,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'ID number (optional)',
            ),
          ),
          const SizedBox(height: AppSpace.lg),
          TextField(
            controller: _email,
            keyboardType: TextInputType.emailAddress,
            decoration: const InputDecoration(labelText: 'Email (optional)'),
          ),
          if (!_editing) ...[
            const SizedBox(height: AppSpace.lg),
            DateField(
              label: 'Move-in date',
              value: _moveIn,
              lastDate: DateTime.now().add(const Duration(days: 60)),
              onChanged: (date) => setState(() => _moveIn = date),
            ),
            if (unit != null) ...[
              const SizedBox(height: AppSpace.lg),
              _MoveInSummary(
                property: widget.property,
                unit: unit,
                moveIn: _moveIn,
                charges: _charges,
                chargesFailed: _chargesFailed,
              ),
            ],
            const SizedBox(height: AppSpace.md),
            const NoteBox(
              'A tenancy agreement is made from the owner’s default template when you save.',
            ),
          ],
          if (_error != null) ...[
            const SizedBox(height: AppSpace.lg),
            ErrorBox(_error!),
          ],
          const SizedBox(height: AppSpace.xl),
          FilledButton(
            onPressed: _ready ? _save : null,
            child: Text(
              _saving
                  ? 'Saving...'
                  : (_editing ? 'Save details' : 'Add tenant'),
            ),
          ),
        ],
      ),
    );
  }
}

/// What the tenant will owe on day one. Rent and deposits come from the
/// unit, not from this form.
class _MoveInSummary extends StatelessWidget {
  const _MoveInSummary({
    required this.property,
    required this.unit,
    required this.moveIn,
    required this.charges,
    required this.chargesFailed,
  });

  final CaretakerProperty property;
  final Unit unit;
  final DateTime moveIn;
  final List<ServiceCharge>? charges;
  final bool chargesFailed;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final costs = MoveInCosts.of(
      policy: property.moveInBilling,
      unit: unit,
      moveIn: moveIn,
      charges: charges ?? const [],
    );
    final dueDay = property.rentDueDay;

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Due at move-in for House ${unit.unitNumber}',
            style: AppText.label.copyWith(color: colors.ink),
          ),
          const SizedBox(height: 4),
          Text(
            'Monthly rent is ${formatKes(unit.monthlyRent)}. This property bills a '
            'mid-month move-in as ${moveInRuleLabel(property.moveInBilling)}.',
            style: AppText.small.copyWith(color: colors.inkFaint),
          ),
          const SizedBox(height: AppSpace.sm),
          for (final (label, amount) in costs.rows)
            Container(
              padding: const EdgeInsets.symmetric(vertical: 8),
              decoration: BoxDecoration(
                border: Border(bottom: BorderSide(color: colors.lineSoft)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      label,
                      style: AppText.small.copyWith(
                        color: colors.inkSoft,
                        fontSize: 13,
                      ),
                    ),
                  ),
                  Text(
                    formatKes(amount),
                    style: AppText.amount.copyWith(
                      color: colors.ink,
                      fontSize: 13.5,
                    ),
                  ),
                ],
              ),
            ),
          Padding(
            padding: const EdgeInsets.only(top: 10),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'Total',
                    style: AppText.label.copyWith(color: colors.ink),
                  ),
                ),
                Text(
                  formatKes(costs.total),
                  style: AppText.amount.copyWith(
                    color: colors.ink,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          if (chargesFailed) ...[
            const SizedBox(height: AppSpace.sm),
            Text(
              'The property’s service charges could not be loaded, so they are not in this '
              'total. They are still billed when the tenant is added.',
              style: AppText.small.copyWith(color: colors.warning),
            ),
          ] else if (charges == null) ...[
            const SizedBox(height: AppSpace.sm),
            Text(
              'Checking the service charges...',
              style: AppText.small.copyWith(color: colors.inkFaint),
            ),
          ] else if (costs.later.isNotEmpty) ...[
            const SizedBox(height: AppSpace.sm),
            Text(
              'Not due now: ${costs.later.map((row) => '${row.$1} ${formatKes(row.$2)}').join(', ')} '
              'every month. First billed on ${formatDay(costs.firstBilling)} with that month’s rent'
              '${dueDay == null ? '' : ', due on day $dueDay'}.',
              style: AppText.small.copyWith(color: colors.inkFaint),
            ),
          ],
        ],
      ),
    );
  }
}
