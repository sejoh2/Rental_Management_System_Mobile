import 'package:flutter/material.dart';

import '../../core/api_client.dart';
import '../../core/app_scope.dart';
import '../../core/live_controller.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text.dart';
import '../../core/theme/app_theme.dart';
import '../../data/expense_repository.dart';
import '../../models/caretaker_property.dart';
import '../../models/electricity_bill.dart';
import '../../utils/format.dart';
import '../../widgets/cards.dart';
import '../../widgets/message_box.dart';
import '../../widgets/month_switcher.dart';
import '../../widgets/status_chip.dart';

/// The amounts to save: what was typed, where it differs from the bill
/// already entered. As on the web, an empty box leaves the bill as it is;
/// 0 removes a bill that has not been paid. Units without a tenant are not
/// billed, so nothing typed for them is sent.
Map<String, double> electricityChanges(
  List<ElectricityBill> bills,
  Map<String, String> typed,
) {
  final changes = <String, double>{};

  for (final bill in bills) {
    final text = (typed[bill.unitId] ?? '').trim();

    if (text.isEmpty || bill.tenantId == null) continue;

    final value = parseNumber(text);

    if (value != null && value != bill.amount) changes[bill.unitId] = value;
  }

  return changes;
}

/// Typing the month's electricity amount for each unit billed that way.
/// Units billed a fixed amount, or not at all, are not listed. Shown in the
/// Water & Electricity tab.
class ElectricityPage extends StatefulWidget {
  const ElectricityPage({super.key, required this.property});

  final CaretakerProperty property;

  @override
  State<ElectricityPage> createState() => _ElectricityPageState();
}

class _ElectricityPageState extends State<ElectricityPage> with LiveRefresh {
  @override
  Set<String> get liveAreas => const {'billing', 'units', 'tenants'};

  @override
  String? get livePropertyId => widget.property.id;

  @override
  Future<void> liveReload() =>
      _saving || _changes().isNotEmpty ? Future<void>.value() : _load();

  DateTime _month = monthOf(DateTime.now());
  ElectricityMonth? _data;

  /// One field per unit, keyed by unit ID.
  final Map<String, TextEditingController> _fields = {};
  String? _error;
  bool _saving = false;
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    if (!_started) {
      _started = true;
      listenLive(AppScope.read(context).live);
      _load();
    }
  }

  @override
  void dispose() {
    for (final field in _fields.values) {
      field.dispose();
    }
    super.dispose();
  }

  Future<void> _load() async {
    final month = _month;

    setState(() => _error = null);

    try {
      final data = await ExpenseRepository(
        AppScope.read(context).api,
      ).electricity(widget.property.id, monthKey(month));

      if (!mounted || month != _month) return;

      for (final field in _fields.values) {
        field.dispose();
      }
      // Empty boxes: the amount entered before shows inside each one.
      _fields
        ..clear()
        ..addAll({
          for (final bill in data.bills) bill.unitId: TextEditingController(),
        });

      setState(() => _data = data);
    } on ApiException catch (failure) {
      if (mounted && month == _month) setState(() => _error = failure.message);
    }
  }

  void _changeMonth(DateTime month) {
    setState(() {
      _month = month;
      _data = null;
    });
    _load();
  }

  Map<String, double> _changes() => electricityChanges(
    _data?.bills ?? const <ElectricityBill>[],
    {for (final entry in _fields.entries) entry.key: entry.value.text},
  );

  Future<void> _save() async {
    final changes = _changes();

    setState(() {
      _saving = true;
      _error = null;
    });

    try {
      await ExpenseRepository(
        AppScope.read(context).api,
      ).saveElectricity(widget.property.id, monthKey(_month), changes);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${changes.length} ${changes.length == 1 ? 'bill' : 'bills'} saved.',
          ),
        ),
      );
      await _load();
    } on ApiException catch (failure) {
      if (mounted) setState(() => _error = failure.message);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final data = _data;
    final changed = data == null ? 0 : _changes().length;

    return Scaffold(
      bottomNavigationBar: data == null || data.bills.isEmpty
          ? null
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpace.page,
                  AppSpace.sm,
                  AppSpace.page,
                  AppSpace.md,
                ),
                child: FilledButton(
                  onPressed: changed == 0 || _saving ? null : _save,
                  child: Text(
                    _saving
                        ? 'Saving...'
                        : (changed == 0
                              ? 'No changes'
                              : 'Save $changed ${changed == 1 ? 'bill' : 'bills'}'),
                  ),
                ),
              ),
            ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppSpace.sm,
          AppSpace.sm,
          AppSpace.sm,
          AppSpace.xl,
        ),
        children: [
          MonthSwitcher(month: _month, onChanged: _changeMonth),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpace.sm),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (_error != null) ...[
                  ErrorBox(_error!),
                  const SizedBox(height: AppSpace.md),
                ],
                if (data == null && _error == null)
                  const LoadingView()
                else if (data != null && data.bills.isEmpty)
                  const EmptyView(
                    icon: Icons.bolt_outlined,
                    title: 'Nothing to enter',
                    message:
                        'No unit in this property has its electricity typed in each month. '
                        'Units with a fixed amount are billed with rent.',
                  )
                else if (data != null) ...[
                  NoteBox(
                    'Type what each unit owes for electricity in ${monthLabel(_month)}. The tenant living there '
                    'is billed exactly that amount. To correct a bill, type the new amount; type 0 to remove a '
                    'bill that has not been paid. An empty box leaves the bill as it is.',
                  ),
                  const SizedBox(height: AppSpace.md),
                  for (final bill in data.bills) ...[
                    AppCard(
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'House ${bill.unitNumber}',
                                  style: AppText.label.copyWith(
                                    color: colors.ink,
                                  ),
                                ),
                                Text(
                                  bill.tenantName ?? 'Vacant - not billed',
                                  style: AppText.small.copyWith(
                                    color: colors.inkSoft,
                                  ),
                                ),
                                if (bill.amount != null)
                                  Text(
                                    'Billed ${formatKes(bill.amount!)}',
                                    style: AppText.small.copyWith(
                                      color: colors.inkFaint,
                                    ),
                                  ),
                                if (bill.status != null) ...[
                                  const SizedBox(height: 6),
                                  switch (bill.status) {
                                    'paid' => const StatusChip(
                                      'Paid',
                                      tone: Tone.success,
                                    ),
                                    'partial' => StatusChip(
                                      '${formatKes(bill.amountPaid)} paid',
                                      tone: Tone.warning,
                                    ),
                                    _ => const StatusChip(
                                      'Unpaid',
                                      tone: Tone.danger,
                                    ),
                                  },
                                ],
                              ],
                            ),
                          ),
                          const SizedBox(width: AppSpace.md),
                          SizedBox(
                            width: 150,
                            child: TextField(
                              controller: _fields[bill.unitId]!,
                              enabled: bill.tenantId != null,
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                    decimal: true,
                                  ),
                              style: AppText.amount.copyWith(
                                color: colors.ink,
                                fontSize: 16,
                              ),
                              decoration: InputDecoration(
                                labelText: bill.amount == null
                                    ? 'Amount'
                                    : 'New amount',
                                hintText: bill.amount == null
                                    ? null
                                    : formatNumber(bill.amount!),
                                prefixText: 'KES ',
                              ),
                              onChanged: (_) => setState(() {}),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppSpace.sm),
                  ],
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
