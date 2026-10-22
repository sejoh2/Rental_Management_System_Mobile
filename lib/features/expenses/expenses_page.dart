import 'package:flutter/material.dart';

import '../../core/api_client.dart';
import '../../core/app_scope.dart';
import '../../core/live_controller.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text.dart';
import '../../core/theme/app_theme.dart';
import '../../data/expense_repository.dart';
import '../../models/app_file.dart';
import '../../models/caretaker_property.dart';
import '../../models/expense.dart';
import '../../utils/format.dart';
import '../../widgets/attachments.dart';
import '../../widgets/cards.dart';
import '../../widgets/message_box.dart';
import '../../widgets/month_switcher.dart';
import '../../widgets/notices_bell.dart';
import '../../widgets/property_gate.dart';
import '../../widgets/status_chip.dart';
import 'expense_form_page.dart';

/// The Expenses tab, for the property being worked on.
class ExpensesTab extends StatelessWidget {
  const ExpensesTab({super.key});

  @override
  Widget build(BuildContext context) {
    return PropertyGate(
      builder: (context, property) => property.canAddExpenses
          ? ExpensesPage(key: ValueKey(property.id), property: property)
          : LockedTab(title: 'Expenses', what: 'expenses', property: property),
    );
  }
}

/// A month's spending on the property, with the receipts.
class ExpensesPage extends StatefulWidget {
  const ExpensesPage({super.key, required this.property});

  final CaretakerProperty property;

  @override
  State<ExpensesPage> createState() => _ExpensesPageState();
}

class _ExpensesPageState extends State<ExpensesPage> with LiveRefresh {
  @override
  Set<String> get liveAreas => const {'expenses'};

  @override
  String? get livePropertyId => widget.property.id;

  @override
  Future<void> liveReload() => _load();

  DateTime _month = monthOf(DateTime.now());
  List<Expense>? _expenses;
  String? _error;
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

  Future<void> _load() async {
    final month = _month;

    setState(() => _error = null);

    try {
      final expenses = await ExpenseRepository(
        AppScope.read(context).api,
      ).list(widget.property.id, month);

      // The month was changed while this was loading; that load wins.
      if (mounted && month == _month) setState(() => _expenses = expenses);
    } on ApiException catch (failure) {
      if (mounted && month == _month) setState(() => _error = failure.message);
    }
  }

  void _changeMonth(DateTime month) {
    setState(() {
      _month = month;
      _expenses = null;
    });
    _load();
  }

  Future<void> _add() async {
    final added = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => ExpenseFormPage(property: widget.property),
      ),
    );

    if (added == true) _load();
  }

  void _show(Expense expense) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) {
        final colors = AppColors.of(sheetContext);

        return SafeArea(
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
                Text(
                  expense.categoryLabel,
                  style: AppText.title.copyWith(color: colors.ink),
                ),
                const SizedBox(height: 4),
                Text(
                  formatKes(expense.amount),
                  style: AppText.figure.copyWith(color: colors.ink),
                ),
                const SizedBox(height: AppSpace.sm),
                Text(
                  [
                    if (expense.date != null) formatDay(expense.date!),
                    expense.unitNumber == null
                        ? 'Whole property'
                        : 'House ${expense.unitNumber}',
                    if (expense.createdByName != null)
                      'by ${expense.createdByName}',
                  ].join(' · '),
                  style: AppText.small.copyWith(color: colors.inkSoft),
                ),
                if ((expense.notes ?? '').isNotEmpty) ...[
                  const SizedBox(height: AppSpace.md),
                  Text(
                    expense.notes!,
                    style: AppText.text.copyWith(color: colors.ink),
                  ),
                ],
                const SectionLabel('Receipts'),
                AttachmentsSection(
                  kind: FileKind.expenseReceipt,
                  targetId: expense.id,
                  emptyText: 'No receipt yet.',
                  addLabel: 'Add a receipt',
                  labelHint: 'Receipt',
                  canAdd: !expense.isVoid,
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final expenses = _expenses;
    final active =
        expenses?.where((expense) => !expense.isVoid) ?? const <Expense>[];
    final total = active.fold<double>(
      0,
      (sum, expense) => sum + expense.amount,
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('Expenses'),
        actions: const [NoticesBell()],
        bottom: const PropertyStrip(),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _add,
        backgroundColor: colors.accent,
        foregroundColor: AppColors.onAccent,
        icon: const Icon(Icons.add),
        label: const Text('Add expense'),
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(
            AppSpace.sm,
            AppSpace.sm,
            AppSpace.sm,
            96,
          ),
          children: [
            MonthSwitcher(month: _month, onChanged: _changeMonth),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpace.sm),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (_error != null)
                    ErrorView(message: _error!, onRetry: _load)
                  else if (expenses == null)
                    const LoadingView()
                  else if (expenses.isEmpty)
                    const EmptyView(
                      icon: Icons.receipt_long_outlined,
                      title: 'No expenses this month',
                      message:
                          'Add what you spend on the property, with a photo of the receipt.',
                    )
                  else ...[
                    AppCard(
                      child: StatTile(
                        label: 'Spent in ${monthLabel(_month)}',
                        value: formatKes(total),
                      ),
                    ),
                    const SizedBox(height: AppSpace.md),
                    for (final expense in expenses) ...[
                      AppCard(
                        onTap: () => _show(expense),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    expense.categoryLabel,
                                    style: AppText.label.copyWith(
                                      color: expense.isVoid
                                          ? colors.inkFaint
                                          : colors.ink,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    [
                                      if (expense.date != null)
                                        formatDay(expense.date!),
                                      if (expense.unitNumber != null)
                                        'House ${expense.unitNumber}',
                                      if ((expense.notes ?? '').isNotEmpty)
                                        expense.notes!,
                                    ].join(' · '),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: AppText.small.copyWith(
                                      color: colors.inkSoft,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: AppSpace.md),
                            expense.isVoid
                                ? const StatusChip('Cancelled')
                                : Text(
                                    formatKes(expense.amount),
                                    style: AppText.amount.copyWith(
                                      color: colors.ink,
                                      fontSize: 14,
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
      ),
    );
  }
}
