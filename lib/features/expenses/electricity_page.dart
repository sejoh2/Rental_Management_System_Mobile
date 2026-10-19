import 'package:flutter/material.dart';

import '../../core/api_client.dart';
import '../../core/app_scope.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text.dart';
import '../../core/theme/app_theme.dart';
import '../../data/expense_repository.dart';
import '../../models/caretaker_property.dart';
import '../../models/electricity_bill.dart';
import '../../utils/format.dart';
import '../../widgets/cards.dart';
import '../../widgets/fields.dart';
import '../../widgets/message_box.dart';
import '../../widgets/month_switcher.dart';
import '../../widgets/property_gate.dart';
import '../../widgets/status_chip.dart';

/// Electricity bills, opened from More, for the property being worked on.
class ElectricityTab extends StatelessWidget {
  const ElectricityTab({super.key});

  @override
  Widget build(BuildContext context) {
    return PropertyGate(
      builder: (context, property) =>
          ElectricityPage(key: ValueKey(property.id), property: property),
    );
  }
}

/// Typing the month's electricity amount for each unit billed that way.
/// Units billed a fixed amount, or not at all, are not listed.
class ElectricityPage extends StatefulWidget {
  const ElectricityPage({super.key, required this.property});

  final CaretakerProperty property;

  @override
  State<ElectricityPage> createState() => _ElectricityPageState();
}

class _ElectricityPageState extends State<ElectricityPage> {
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
      _fields
        ..clear()
        ..addAll({
          for (final bill in data.bills)
            bill.unitId: TextEditingController(
              text: bill.amount == null
                  ? ''
                  : formatNumber(bill.amount!).replaceAll(',', ''),
            ),
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

  /// The amounts that differ from what is saved.
  Map<String, double> _changes() {
    final changes = <String, double>{};

    for (final bill in _data?.bills ?? const <ElectricityBill>[]) {
      final typed = _fields[bill.unitId]?.text ?? '';
      final value = typed.trim().isEmpty ? 0.0 : parseNumber(typed);

      if (value != null && value != (bill.amount ?? 0)) {
        changes[bill.unitId] = value;
      }
    }

    return changes;
  }

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
      appBar: AppBar(
        title: const Text('Electricity bills'),
        bottom: const PropertyStrip(),
      ),
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
                  const NoteBox(
                    'Type each unit’s amount for the month. Leaving it empty, or 0, removes a bill not paid yet.',
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
                                  bill.tenantName ?? 'No tenant',
                                  style: AppText.small.copyWith(
                                    color: colors.inkSoft,
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
                            child: AmountField(
                              controller: _fields[bill.unitId]!,
                              label: 'Amount',
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
