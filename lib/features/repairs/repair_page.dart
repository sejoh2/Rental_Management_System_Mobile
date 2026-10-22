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

/// One repair, and moving it along as on the web: take it on, start the
/// work, change the priority, worker or estimate, mark it done (with or
/// without a cost, and who pays), cancel it, and tell the tenant about a
/// charge by SMS. Returns true to the list if it changed.
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
  bool _busy = false;
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    if (!_started) {
      _started = true;
      _refresh();
    }
  }

  /// Looks the repair up again; opening it also clears its "new" mark.
  Future<void> _refresh() async {
    final services = AppScope.read(context);

    try {
      final repair = await RepairRepository(services.api).get(widget.repair.id);

      services.notices.seen(repair.id);

      if (mounted) setState(() => _repair = repair);
    } on ApiException {
      // The repair as listed is still shown.
    }
  }

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

  Future<void> _quick(
    Future<Repair> Function(RepairRepository repository) call,
    String done,
  ) async {
    final messenger = ScaffoldMessenger.of(context);

    setState(() => _busy = true);

    try {
      final updated = await call(RepairRepository(AppScope.read(context).api));

      if (!mounted) return;

      setState(() {
        _repair = updated;
        _changed = true;
      });
      messenger.showSnackBar(SnackBar(content: Text(done)));
    } on ApiException catch (failure) {
      messenger.showSnackBar(SnackBar(content: Text(failure.message)));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final me = AppScope.of(context).auth.user?.id;
    final repair = _repair;
    final priority = repairPriorityChip(repair);
    final mine = repair.isFor(me);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) Navigator.of(context).pop(_changed);
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Maintenance request'),
          actions: [
            if (repair.isOpen)
              IconButton(
                tooltip: 'Change priority, worker or estimate',
                icon: const Icon(Icons.edit_outlined),
                onPressed: () => _act(_EditSheet(repair: repair)),
              ),
          ],
        ),
        body: RefreshIndicator(
          onRefresh: _refresh,
          child: ListView(
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
                      ? 'Common area'
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
                    _Line(
                      'Handled by',
                      mine
                          ? 'You'
                          : repair.assignedCaretakerId != null
                          ? (repair.assignedCaretakerName ?? 'A caretaker')
                          : 'The owner',
                    ),
                    if ((repair.vendorName ?? '').isNotEmpty)
                      _Line('Worker', repair.vendorName!),
                    if (repair.estimatedCost != null)
                      _Line('Estimate', formatKes(repair.estimatedCost!)),
                    if (repair.actualCost != null)
                      _Line('Cost', formatKes(repair.actualCost!)),
                    _Line(
                      'Paid by',
                      repair.chargeToTenant
                          ? (repair.chargeTiming == 'move_out'
                                ? 'Tenant, at move-out'
                                : 'Tenant')
                          : 'Owner',
                    ),
                    if (repair.resolvedAt != null)
                      _Line('Resolved on', formatDay(repair.resolvedAt!)),
                    if ((repair.resolutionNotes ?? '').isNotEmpty)
                      _Line('Notes', repair.resolutionNotes!),
                    if ((repair.cancellationReason ?? '').isNotEmpty)
                      _Line('Cancelled', repair.cancellationReason!),
                  ],
                ),
              ),
              if (repair.status == 'resolved' && repair.costRecorded) ...[
                const SizedBox(height: AppSpace.md),
                NoteBox(
                  '${formatKes(repair.actualCost ?? 0)} was recorded as an expense'
                  '${repair.tenantChargeId == null
                      ? '. It is the owner’s cost.'
                      : repair.chargeTiming == 'move_out'
                      ? ' and charged to the tenant, to be deducted from their deposit at move-out.'
                      : ' and charged to the tenant.'}',
                ),
              ],
              if (repair.tenantChargeId != null) ...[
                const SectionLabel('Tell the tenant'),
                AppCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        repair.chargeSmsSentAt == null
                            ? 'The tenant has not been sent an SMS about this charge. Nothing is sent automatically.'
                            : 'SMS about this charge sent on ${formatDay(repair.chargeSmsSentAt!)}.',
                        style: AppText.small.copyWith(
                          color: colors.inkSoft,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: AppSpace.md),
                      OutlinedButton.icon(
                        onPressed: _busy
                            ? null
                            : () => _quick(
                                (repository) =>
                                    repository.sendChargeSms(repair.id),
                                'SMS sent to the tenant.',
                              ),
                        icon: const Icon(Icons.sms_outlined),
                        label: Text(
                          repair.chargeSmsSentAt == null
                              ? 'Send SMS'
                              : 'Send SMS again',
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              if (repair.isOpen) ...[
                const SizedBox(height: AppSpace.xl),
                if (!mine && me != null) ...[
                  OutlinedButton.icon(
                    onPressed: _busy
                        ? null
                        : () => _quick(
                            (repository) => repository.update(repair.id, {
                              'assigned_caretaker_id': int.tryParse(me) ?? me,
                            }),
                            'You are handling this request.',
                          ),
                    icon: const Icon(Icons.assignment_ind_outlined),
                    label: const Text('I’ll handle it'),
                  ),
                  const SizedBox(height: AppSpace.sm),
                ],
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
                  label: const Text('Mark as resolved'),
                ),
                const SizedBox(height: AppSpace.sm),
                TextButton(
                  style: TextButton.styleFrom(foregroundColor: colors.danger),
                  onPressed: () => _act(_CancelSheet(repair: repair)),
                  child: const Text('Cancel this request'),
                ),
              ],
            ],
          ),
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

/// The frame of the action sheets: a title, the fields, the error and the button.
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

String _amountText(double? value) =>
    value == null ? '' : formatNumber(value).replaceAll(',', '');

/// Priority, the outside worker and the estimate, while the repair is open.
class _EditSheet extends StatefulWidget {
  const _EditSheet({required this.repair});

  final Repair repair;

  @override
  State<_EditSheet> createState() => _EditSheetState();
}

class _EditSheetState extends State<_EditSheet> with _Updating {
  late String _priority = widget.repair.priority;
  late final _vendor = TextEditingController(
    text: widget.repair.vendorName ?? '',
  );
  late final _estimate = TextEditingController(
    text: _amountText(widget.repair.estimatedCost),
  );

  @override
  void dispose() {
    _vendor.dispose();
    _estimate.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _Sheet(
      title: 'Change the request',
      children: [
        SelectField<String>(
          label: 'Priority',
          value: _priority,
          options: RepairLabels.priorities,
          onChanged: (value) => setState(() => _priority = value ?? 'normal'),
        ),
        const SizedBox(height: AppSpace.lg),
        TextField(
          controller: _vendor,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(
            labelText: 'Outside worker (optional)',
            hintText: 'e.g. Kamau Repairs',
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
                  'priority': _priority,
                  'assigned_vendor_name': _vendor.text.trim().isEmpty
                      ? null
                      : _vendor.text.trim(),
                  'estimated_cost': parseNumber(_estimate.text),
                }),
          child: Text(saving ? 'Saving...' : 'Save changes'),
        ),
      ],
    );
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
  late final _estimate = TextEditingController(
    text: _amountText(widget.repair.estimatedCost),
  );

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
            labelText: 'Outside worker (optional)',
            hintText: 'e.g. Kamau Repairs',
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

/// Done, as on the web: the cost is optional (without one nothing is
/// recorded in Expenses), and who pays was chosen when it was reported and
/// can still be changed here.
class _DoneSheet extends StatefulWidget {
  const _DoneSheet({required this.repair});

  final Repair repair;

  @override
  State<_DoneSheet> createState() => _DoneSheetState();
}

class _DoneSheetState extends State<_DoneSheet> with _Updating {
  late final _cost = TextEditingController(
    text: _amountText(widget.repair.actualCost),
  );
  late final _notes = TextEditingController(
    text: widget.repair.resolutionNotes ?? '',
  );
  late String _payer = widget.repair.chargeToTenant ? 'tenant' : 'owner';
  late String _timing = widget.repair.chargeTiming ?? 'now';

  @override
  void dispose() {
    _cost.dispose();
    _notes.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final repair = widget.repair;
    final cost = parseNumber(_cost.text) ?? 0;
    // Only a repair in a house with a tenant can be charged to a tenant.
    final canChargeTenant =
        repair.unitId != null && repair.unitTenantName != null;
    final chargeTenant = canChargeTenant && _payer == 'tenant';
    final atMoveOut = _timing == 'move_out';
    final tenantName = repair.unitTenantName ?? 'the tenant';

    final explained = cost > 0
        ? 'When you save: ${formatKes(cost)} is recorded as a repairs expense for the property. '
              '${chargeTenant ? '$tenantName is also charged ${formatKes(cost)}. ${atMoveOut ? 'It is not collected during their stay and does not count as arrears; it is deducted from their deposit when they move out.' : 'It is paid from their credit or their next payment; anything still unpaid is deducted from their deposit at move-out.'} No SMS is sent automatically: open this request again and tap "Send SMS" to tell them.' : 'The tenant is not charged, so it is the owner’s cost.'} '
              'The cost cannot be changed afterwards.'
        : 'Enter the actual cost to record it as an expense. Without a cost, nothing is recorded in Expenses.';

    return _Sheet(
      title: 'Mark as resolved',
      children: [
        AmountField(
          controller: _cost,
          label: 'Actual cost (optional)',
          helper: 'Leave empty if it cost nothing.',
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: AppSpace.lg),
        if (canChargeTenant) ...[
          SelectField<String>(
            label: 'Who pays for this repair',
            value: _payer,
            options: {'owner': 'Owner', 'tenant': 'Tenant ($tenantName)'},
            helper:
                'Choose the tenant when they caused the damage. Normal wear is the owner’s cost.',
            onChanged: (value) => setState(() => _payer = value ?? 'owner'),
          ),
          if (_payer == 'tenant') ...[
            const SizedBox(height: AppSpace.lg),
            SelectField<String>(
              label: 'How the tenant pays',
              value: _timing,
              options: RepairLabels.chargeTimings,
              onChanged: (value) => setState(() => _timing = value ?? 'now'),
            ),
          ],
        ] else
          Text(
            repair.unitId != null
                ? 'No tenant lives in this unit now, so the cost cannot be charged to a tenant.'
                : 'This is a common-area repair, so the cost is the owner’s and cannot be charged to a tenant.',
            style: AppText.small.copyWith(color: colors.inkFaint),
          ),
        const SizedBox(height: AppSpace.lg),
        TextField(
          controller: _notes,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(
            labelText: 'Resolution notes (optional)',
            hintText: 'e.g. Glass replaced',
          ),
        ),
        const SizedBox(height: AppSpace.lg),
        Text(explained, style: AppText.small.copyWith(color: colors.inkSoft)),
        if (error != null) ...[
          const SizedBox(height: AppSpace.lg),
          ErrorBox(error!),
        ],
        const SizedBox(height: AppSpace.xl),
        FilledButton(
          onPressed: saving
              ? null
              : () => update(repair.id, {
                  'status': 'resolved',
                  'actual_cost': cost > 0 ? cost : null,
                  'charge_to_tenant': chargeTenant,
                  'charge_timing': chargeTenant ? _timing : 'now',
                  'resolution_notes': _notes.text.trim().isEmpty
                      ? null
                      : _notes.text.trim(),
                }),
          child: Text(saving ? 'Saving...' : 'Mark as resolved'),
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
      title: 'Cancel this request',
      children: [
        TextField(
          controller: _reason,
          autofocus: true,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(
            labelText: 'Why is it cancelled',
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
          onPressed: saving || _reason.text.trim().length < 2
              ? null
              : () => update(widget.repair.id, {
                  'status': 'cancelled',
                  'cancellation_reason': _reason.text.trim(),
                }),
          child: Text(saving ? 'Saving...' : 'Cancel request'),
        ),
      ],
    );
  }
}
