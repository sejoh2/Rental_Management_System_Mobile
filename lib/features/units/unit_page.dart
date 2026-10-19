import 'package:flutter/material.dart';

import '../../core/api_client.dart';
import '../../core/app_scope.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text.dart';
import '../../core/theme/app_theme.dart';
import '../../data/unit_repository.dart';
import '../../models/caretaker_property.dart';
import '../../models/unit.dart';
import '../../utils/format.dart';
import '../../widgets/cards.dart';
import '../../widgets/message_box.dart';
import '../../widgets/status_chip.dart';
import '../tenants/tenant_form_page.dart';
import '../tenants/tenant_page.dart';

/// One unit: who lives there and what they owe, the rent and deposits, and
/// how water and electricity are billed. Opens the tenant, or (for a
/// caretaker who adds tenants) adds one to a vacant unit. Changing the unit
/// itself is the owner's, on the web. Returns true if something changed.
class UnitPage extends StatefulWidget {
  const UnitPage({super.key, required this.property, required this.unit});

  final CaretakerProperty property;

  /// As listed; the details are looked up again when the page opens.
  final Unit unit;

  @override
  State<UnitPage> createState() => _UnitPageState();
}

class _UnitPageState extends State<UnitPage> {
  late Unit _unit = widget.unit;
  String? _error;
  bool _changed = false;
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    if (!_started) {
      _started = true;
      _load();
    }
  }

  Future<void> _load() async {
    setState(() => _error = null);

    try {
      final unit = await UnitRepository(
        AppScope.read(context).api,
      ).get(widget.unit.id);

      if (mounted) setState(() => _unit = unit);
    } on ApiException catch (failure) {
      if (mounted) setState(() => _error = failure.message);
    }
  }

  Future<void> _open(Widget page) async {
    final changed = await Navigator.of(
      context,
    ).push<bool>(MaterialPageRoute(builder: (_) => page));

    if (changed == true) {
      _changed = true;
      _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final unit = _unit;
    final tenant = unit.tenant;
    final property = widget.property;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) Navigator.of(context).pop(_changed);
      },
      child: Scaffold(
        appBar: AppBar(title: Text('House ${unit.unitNumber}')),
        body: RefreshIndicator(
          onRefresh: _load,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(
              AppSpace.page,
              AppSpace.md,
              AppSpace.page,
              AppSpace.xxl,
            ),
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      [
                        unit.typeLabel,
                        if ((unit.floor ?? '').isNotEmpty) unit.floor!,
                      ].join(' · '),
                      style: AppText.small.copyWith(
                        color: colors.inkSoft,
                        fontSize: 13,
                      ),
                    ),
                  ),
                  unit.isOccupied
                      ? const StatusChip('Occupied', tone: Tone.success)
                      : const StatusChip('Vacant'),
                ],
              ),
              if (_error != null) ...[
                const SizedBox(height: AppSpace.md),
                ErrorBox(_error!),
              ],
              const SectionLabel('Tenant'),
              if (tenant != null)
                AppCard(
                  onTap: () => _open(
                    TenantPage(property: property, tenantId: tenant.id),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              tenant.fullName,
                              style: AppText.title.copyWith(color: colors.ink),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              tenant.balance > 0
                                  ? 'Owes ${formatKes(tenant.balance)}'
                                  : 'Paid up',
                              style: AppText.label.copyWith(
                                color: tenant.balance > 0
                                    ? colors.danger
                                    : colors.success,
                              ),
                            ),
                            if (tenant.status == 'notice_given') ...[
                              const SizedBox(height: 6),
                              const StatusChip(
                                'Notice given',
                                tone: Tone.warning,
                              ),
                            ],
                          ],
                        ),
                      ),
                      Text(
                        'Open',
                        style: AppText.small.copyWith(
                          color: colors.accentInk,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Icon(Icons.chevron_right, color: colors.accentInk),
                    ],
                  ),
                )
              else
                AppCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        'No one lives here now.',
                        style: AppText.text.copyWith(color: colors.inkSoft),
                      ),
                      if (property.canManageTenants && unit.isVacant) ...[
                        const SizedBox(height: AppSpace.md),
                        FilledButton.icon(
                          onPressed: () => _open(
                            TenantFormPage(property: property, unitId: unit.id),
                          ),
                          icon: const Icon(Icons.person_add_alt_1_outlined),
                          label: const Text('Add a tenant here'),
                        ),
                      ],
                    ],
                  ),
                ),
              const SectionLabel('Rent and deposits'),
              AppCard(
                padding: EdgeInsets.zero,
                child: Column(
                  children: [
                    _Row('Monthly rent', formatKes(unit.monthlyRent)),
                    _Row(
                      'Rent deposit',
                      unit.rentDeposit > 0
                          ? formatKes(unit.rentDeposit)
                          : 'None',
                    ),
                    _Row(
                      'Water deposit',
                      unit.waterDeposit > 0
                          ? formatKes(unit.waterDeposit)
                          : 'None',
                    ),
                    _Row(
                      'Electricity deposit',
                      (unit.electricityDeposit ?? 0) > 0
                          ? formatKes(unit.electricityDeposit!)
                          : 'None',
                      last: true,
                    ),
                  ],
                ),
              ),
              const SectionLabel('Water and electricity'),
              AppCard(
                padding: EdgeInsets.zero,
                child: Column(
                  children: [
                    _Row(
                      'Water',
                      unit.waterLabel(propertyRate: property.waterRatePerUnit),
                    ),
                    if (unit.isMetered)
                      _Row(
                        'Meter number',
                        (unit.meterNumber ?? '').isEmpty
                            ? 'Not set'
                            : unit.meterNumber!,
                      ),
                    _Row('Electricity', unit.electricityLabel, last: true),
                  ],
                ),
              ),
              const SizedBox(height: AppSpace.md),
              Text(
                'The owner sets the rent, deposits and billing on the web.',
                style: AppText.small.copyWith(color: colors.inkFaint),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row(this.label, this.value, {this.last = false});

  final String label;
  final String value;
  final bool last;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpace.lg, vertical: 12),
      decoration: BoxDecoration(
        border: last
            ? null
            : Border(bottom: BorderSide(color: colors.lineSoft)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: AppText.small.copyWith(color: colors.inkSoft, fontSize: 13),
          ),
          const SizedBox(width: AppSpace.md),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: AppText.label.copyWith(color: colors.ink),
            ),
          ),
        ],
      ),
    );
  }
}
