import 'package:flutter/material.dart';

import '../../core/api_client.dart';
import '../../core/app_scope.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text.dart';
import '../../core/theme/app_theme.dart';
import '../../data/repair_repository.dart';
import '../../models/caretaker_property.dart';
import '../../models/repair.dart';
import '../../utils/format.dart';
import '../../widgets/cards.dart';
import '../../widgets/fields.dart';
import '../../widgets/message_box.dart';
import 'repairs_page.dart';

/// One repair, and moving it along: start work, mark done (with the cost and
/// who pays), or cancel. Returns true to the list if it changed.
class RepairPage extends StatefulWidget {
  const RepairPage({super.key, required this.property, required this.repair});

  final CaretakerProperty property;
  final Repair repair;

  @override
  State<RepairPage> createState() => _RepairPageState();
}

class _RepairPageState extends State<RepairPage> {
  late Repair _repair = widget.repair;
  bool _changed = false;

  Future<void> _act(Widget sheet) async {
    final updated = await showModalBottomSheet<Repair>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => sheet,
    );

    if (updated != null && mounted) {
      setState(() {
        _repair = updated;
        _changed = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final repair = _repair;
    final priority = repairPriorityChip(repair);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) Navigator.of(context).pop(_changed);
      },
      child: Scaffold(
        appBar: AppBar(title: const Text('Repair')),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(
            AppSpace.page,
            AppSpace.lg,
            AppSpace.page,
            AppSpace.xxl,
          ),
          children: [
            Row(
              children: [
                repairStatusChip(repair),
                if (priority != null) ...[const SizedBox(width: 6), priority],
              ],
            ),
            const SizedBox(height: AppSpace.md),
            Text(
              repair.title,
              style: AppText.headline.copyWith(color: colors.ink),
            ),
            const SizedBox(height: 4),
            Text(
              [
                repair.unitNumber == null
                    ? 'Whole property'
                    : 'House ${repair.unitNumber}',
                if (repair.unitTenantName != null) repair.unitTenantName!,
                RepairLabels.categories[repair.category] ?? repair.category,
              ].join(' · '),
              style: AppText.small.copyWith(
                color: colors.inkSoft,
                fontSize: 13,
              ),
            ),
            if ((repair.description ?? '').isNotEmpty) ...[
              const SizedBox(height: AppSpace.lg),
              Text(
                repair.description!,
                style: AppText.text.copyWith(color: colors.ink),
              ),
            ],
            const SectionLabel('Record'),
            AppCard(
              child: Column(
                children: [
                  _Line(
                    'Reported',
                    [
                      if (repair.createdAt != null)
                        formatDay(repair.createdAt!),
                      if (repair.reporterName != null) repair.reporterName!,
                    ].join(' · '),
                  ),
                  if (repair.vendorName != null)
                    _Line('Done by', repair.vendorName!),
                  if (repair.estimatedCost != null)
                    _Line('Estimate', formatKes(repair.estimatedCost!)),
                  if (repair.actualCost != null)
                    _Line('Cost', formatKes(repair.actualCost!)),
                  if (repair.status == 'resolved')
                    _Line(
                      'Paid by',
                      repair.chargeToTenant
                          ? (repair.chargeTiming == 'move_out'
                                ? 'Tenant, at move-out'
                                : 'Tenant')
                          : 'Owner',
                    ),
                  if (repair.resolvedAt != null)
                    _Line('Done on', formatDay(repair.resolvedAt!)),
                  if ((repair.resolutionNotes ?? '').isNotEmpty)
                    _Line('Notes', repair.resolutionNotes!),
                  if ((repair.cancellationReason ?? '').isNotEmpty)
                    _Line('Cancelled', repair.cancellationReason!),
                ],
              ),
            ),
            if (repair.isOpen) ...[
              const SizedBox(height: AppSpace.xl),
              if (repair.status == 'reported') ...[
                OutlinedButton.icon(
                  onPressed: () => _act(_StartSheet(repair: repair)),
                  icon: const Icon(Icons.construction_outlined),
                  label: const Text('Start the work'),
                ),
                const SizedBox(height: AppSpace.sm),
              ],
              FilledButton.icon(
                onPressed: () => _act(_DoneSheet(repair: repair)),
                icon: const Icon(Icons.check_circle_outline),
                label: const Text('Mark as done'),
              ),
              const SizedBox(height: AppSpace.sm),
              TextButton(
                style: TextButton.styleFrom(foregroundColor: colors.danger),
                onPressed: () => _act(_CancelSheet(repair: repair)),
                child: const Text('Cancel this repair'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _Line extends StatelessWidget {
  const _Line(this.label, this.value);

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 92,
            child: Text(
              label,
              style: AppText.small.copyWith(color: colors.inkFaint),
            ),
          ),
          Expanded(
            child: Text(value, style: AppText.text.copyWith(color: colors.ink)),
          ),
        ],
      ),
    );
  }
}

/// The frame of the three action sheets: a title, the fields, the error and the button.
class _Sheet extends StatelessWidget {
  const _Sheet({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(
            AppSpace.xl,
            0,
            AppSpace.xl,
            AppSpace.xl,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(title, style: AppText.title.copyWith(color: colors.ink)),
              const SizedBox(height: AppSpace.lg),
              ...children,
            ],
          ),
        ),
      ),
    );
  }
}

mixin _Updating<T extends StatefulWidget> on State<T> {
  bool saving = false;
  String? error;

  Future<void> update(String repairId, Map<String, Object?> changes) async {
    setState(() {
      saving = true;
      error = null;
    });

    try {
      final updated = await RepairRepository(
        AppScope.read(context).api,
      ).update(repairId, changes);

      if (mounted) Navigator.pop(context, updated);
    } on ApiException catch (failure) {
      if (mounted) {
        setState(() {
          error = failure.message;
          saving = false;
        });
      }
    }
  }
}

class _StartSheet extends StatefulWidget {
  const _StartSheet({required this.repair});

  final Repair repair;

  @override
  State<_StartSheet> createState() => _StartSheetState();
}

class _StartSheetState extends State<_StartSheet> with _Updating {
  late final _vendor = TextEditingController(
    text: widget.repair.vendorName ?? '',
  );
  final _estimate = TextEditingController();

  @override
  void dispose() {
    _vendor.dispose();
    _estimate.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _Sheet(
      title: 'Start the work',
      children: [
        TextField(
          controller: _vendor,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(
            labelText: 'Who is doing it (optional)',
            hintText: 'e.g. Otieno Plumbing',
          ),
        ),
        const SizedBox(height: AppSpace.lg),
        AmountField(controller: _estimate, label: 'Estimated cost (optional)'),
        if (error != null) ...[
          const SizedBox(height: AppSpace.lg),
          ErrorBox(error!),
        ],
        const SizedBox(height: AppSpace.xl),
        FilledButton(
          onPressed: saving
              ? null
              : () => update(widget.repair.id, {
                  'status': 'in_progress',
                  if (_vendor.text.trim().isNotEmpty)
                    'assigned_vendor_name': _vendor.text.trim(),
                  if (parseNumber(_estimate.text) != null)
                    'estimated_cost': parseNumber(_estimate.text),
                }),
          child: Text(saving ? 'Saving...' : 'Mark as in progress'),
        ),
      ],
    );
  }
}

class _DoneSheet extends StatefulWidget {
  const _DoneSheet({required this.repair});

  final Repair repair;

  @override
  State<_DoneSheet> createState() => _DoneSheetState();
}

class _DoneSheetState extends State<_DoneSheet> with _Updating {
  final _cost = TextEditingController();
  final _notes = TextEditingController();

  /// owner, tenant_now or tenant_move_out
  String _payer = 'owner';

  @override
  void dispose() {
    _cost.dispose();
    _notes.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final repair = widget.repair;
    final cost = parseNumber(_cost.text);
    // Only a repair in a house with a tenant can be charged to a tenant.
    final hasTenant = repair.unitId != null && repair.unitTenantName != null;

    return _Sheet(
      title: 'Mark as done',
      children: [
        AmountField(
          controller: _cost,
          label: 'What it cost',
          autofocus: true,
          helper: 'Recorded as an expense of the property.',
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: AppSpace.lg),
        SelectField<String>(
          label: 'Who pays',
          value: _payer,
          options: {
            'owner': 'The owner',
            if (hasTenant)
              'tenant_now':
                  '${repair.unitTenantName}, added to their bills now',
            if (hasTenant)
              'tenant_move_out':
                  '${repair.unitTenantName}, taken from the deposit at move-out',
          },
          helper: hasTenant
              ? null
              : 'Only a repair in a house with a tenant can be charged to a tenant.',
          onChanged: (value) => setState(() => _payer = value ?? 'owner'),
        ),
        const SizedBox(height: AppSpace.lg),
        TextField(
          controller: _notes,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(
            labelText: 'What was done (optional)',
          ),
        ),
        if (error != null) ...[
          const SizedBox(height: AppSpace.lg),
          ErrorBox(error!),
        ],
        const SizedBox(height: AppSpace.xl),
        FilledButton(
          onPressed: saving || cost == null
              ? null
              : () => update(repair.id, {
                  'status': 'resolved',
                  'actual_cost': cost,
                  'charge_to_tenant': _payer != 'owner',
                  if (_payer != 'owner')
                    'charge_timing': _payer == 'tenant_move_out'
                        ? 'move_out'
                        : 'now',
                  if (_notes.text.trim().isNotEmpty)
                    'resolution_notes': _notes.text.trim(),
                }),
          child: Text(saving ? 'Saving...' : 'Mark as done'),
        ),
      ],
    );
  }
}

class _CancelSheet extends StatefulWidget {
  const _CancelSheet({required this.repair});

  final Repair repair;

  @override
  State<_CancelSheet> createState() => _CancelSheetState();
}

class _CancelSheetState extends State<_CancelSheet> with _Updating {
  final _reason = TextEditingController();

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);

    return _Sheet(
      title: 'Cancel this repair',
      children: [
        TextField(
          controller: _reason,
          autofocus: true,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(
            labelText: 'Why',
            hintText: 'e.g. Reported twice',
          ),
          onChanged: (_) => setState(() {}),
        ),
        if (error != null) ...[
          const SizedBox(height: AppSpace.lg),
          ErrorBox(error!),
        ],
        const SizedBox(height: AppSpace.xl),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: colors.danger),
          onPressed: saving || _reason.text.trim().length < 3
              ? null
              : () => update(widget.repair.id, {
                  'status': 'cancelled',
                  'cancellation_reason': _reason.text.trim(),
                }),
          child: Text(saving ? 'Saving...' : 'Cancel repair'),
        ),
      ],
    );
  }
}
