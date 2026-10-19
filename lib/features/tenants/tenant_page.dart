import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/api_client.dart';
import '../../core/app_scope.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text.dart';
import '../../core/theme/app_theme.dart';
import '../../data/tenant_repository.dart';
import '../../models/app_file.dart';
import '../../models/caretaker_property.dart';
import '../../models/tenant.dart';
import '../../utils/format.dart';
import '../../widgets/attachments.dart';
import '../../widgets/fields.dart';
import '../../widgets/cards.dart';
import '../../widgets/message_box.dart';
import '../../widgets/status_chip.dart';
import 'record_payment_page.dart';
import 'tenant_form_page.dart';

const _periods = {
  'this_month': 'This month',
  'last_3_months': 'Last 3 months',
  'this_year': 'This year',
};

/// One tenant: what they owe, their details, bills and payments, documents.
/// Returns true to the list if something changed.
class TenantPage extends StatefulWidget {
  const TenantPage({super.key, required this.property, required this.tenantId});

  final CaretakerProperty property;
  final String tenantId;

  @override
  State<TenantPage> createState() => _TenantPageState();
}

class _TenantPageState extends State<TenantPage> {
  Tenant? _tenant;
  TenantStatement? _statement;
  String _period = 'this_month';
  String? _error;
  bool _changed = false;
  bool _started = false;

  late TenantRepository _repository;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _repository = TenantRepository(AppScope.read(context).api);

    if (!_started) {
      _started = true;
      _load();
    }
  }

  Future<void> _load() async {
    setState(() => _error = null);

    try {
      final results = await Future.wait<Object>([
        _repository.get(widget.tenantId),
        _repository.statement(widget.tenantId, _period),
      ]);

      if (!mounted) return;

      setState(() {
        _tenant = results[0] as Tenant;
        _statement = results[1] as TenantStatement;
      });
    } on ApiException catch (failure) {
      if (mounted) setState(() => _error = failure.message);
    }
  }

  Future<void> _changePeriod(String period) async {
    setState(() {
      _period = period;
      _statement = null;
    });

    try {
      final statement = await _repository.statement(widget.tenantId, period);

      if (mounted && period == _period) setState(() => _statement = statement);
    } on ApiException catch (failure) {
      if (mounted) setState(() => _error = failure.message);
    }
  }

  bool _busy = false;

  /// Records that the tenant said they are leaving, on the date chosen.
  Future<void> _markNotice(Tenant tenant) async {
    final date = await showModalBottomSheet<DateTime>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _NoticeSheet(tenant: tenant),
    );

    if (date == null || !mounted) return;

    await _changeNotice(tenant, date, 'Notice recorded.');
  }

  Future<void> _cancelNotice(Tenant tenant) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Cancel the notice?'),
        content: Text(
          '${tenant.fullName} stays as a tenant, as if no notice was given.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Keep it'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Cancel notice'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    await _changeNotice(tenant, null, 'Notice cancelled.');
  }

  Future<void> _changeNotice(Tenant tenant, DateTime? date, String done) async {
    final messenger = ScaffoldMessenger.of(context);

    setState(() => _busy = true);

    try {
      await _repository.setNotice(tenant.id, date);
      _changed = true;
      messenger.showSnackBar(SnackBar(content: Text(done)));
      await _load();
    } on ApiException catch (failure) {
      messenger.showSnackBar(SnackBar(content: Text(failure.message)));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// The statement for the period shown, as a PDF, opened in the phone's
  /// PDF viewer (from there it can be shared or printed).
  Future<void> _downloadStatement(Tenant tenant) async {
    final messenger = ScaffoldMessenger.of(context);

    setState(() => _busy = true);

    try {
      final bytes = await _repository.statementPdf(tenant.id, _period);
      final name =
          'statement-${tenant.unitNumber}-${tenant.fullName}-$_period'
              .replaceAll(RegExp(r'[^A-Za-z0-9-]+'), '-');

      await openPdf(bytes, name);
    } on ApiException catch (failure) {
      messenger.showSnackBar(SnackBar(content: Text(failure.message)));
    } on Exception {
      messenger.showSnackBar(
        const SnackBar(content: Text('The PDF could not be opened.')),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
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
    final tenant = _tenant;
    final property = widget.property;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) Navigator.of(context).pop(_changed);
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(tenant?.fullName ?? 'Tenant'),
          actions: [
            if (tenant != null && property.canManageTenants && tenant.isCurrent)
              IconButton(
                tooltip: 'Edit details',
                icon: const Icon(Icons.edit_outlined),
                onPressed: () =>
                    _open(TenantFormPage(property: property, tenant: tenant)),
              ),
          ],
        ),
        body: tenant == null
            ? (_error != null
                  ? ErrorView(message: _error!, onRetry: _load)
                  : const LoadingView())
            : RefreshIndicator(
                onRefresh: _load,
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpace.page,
                    AppSpace.md,
                    AppSpace.page,
                    AppSpace.xxl,
                  ),
                  children: [
                    _BalanceCard(tenant: tenant),
                    // As on the web: nothing to record for someone who has left and owes nothing.
                    if (property.canRecordPayments &&
                        (tenant.isCurrent || tenant.owes)) ...[
                      const SizedBox(height: AppSpace.md),
                      FilledButton.icon(
                        onPressed: () =>
                            _open(RecordPaymentPage(tenant: tenant)),
                        icon: const Icon(Icons.payments_outlined),
                        label: const Text('Record a payment'),
                      ),
                    ],
                    if (property.canManageTenants && tenant.isCurrent) ...[
                      const SizedBox(height: AppSpace.sm),
                      OutlinedButton.icon(
                        onPressed: _busy
                            ? null
                            : () => tenant.status == 'notice_given'
                                  ? _cancelNotice(tenant)
                                  : _markNotice(tenant),
                        icon: Icon(
                          tenant.status == 'notice_given'
                              ? Icons.undo
                              : Icons.event_busy_outlined,
                        ),
                        label: Text(
                          tenant.status == 'notice_given'
                              ? 'Cancel notice'
                              : 'Mark notice given',
                        ),
                      ),
                    ],
                    const SectionLabel('Details'),
                    AppCard(
                      padding: EdgeInsets.zero,
                      child: Column(
                        children: [
                          _DetailRow(
                            icon: Icons.phone_outlined,
                            label: 'Phone',
                            value: tenant.phone,
                            onTap: () =>
                                launchUrl(Uri.parse('tel:${tenant.phone}')),
                          ),
                          if (tenant.paymentPhone != null &&
                              tenant.paymentPhone != tenant.phone)
                            _DetailRow(
                              icon: Icons.phone_android_outlined,
                              label: 'Pays from',
                              value: tenant.paymentPhone!,
                            ),
                          _DetailRow(
                            icon: Icons.door_front_door_outlined,
                            label: 'House',
                            value: tenant.unitNumber,
                          ),
                          _DetailRow(
                            icon: Icons.sell_outlined,
                            label: 'Monthly rent',
                            value: formatKes(tenant.monthlyRent),
                          ),
                          if (tenant.moveInDate != null)
                            _DetailRow(
                              icon: Icons.login,
                              label: 'Moved in',
                              value: formatDay(tenant.moveInDate!),
                            ),
                          if (tenant.status == 'notice_given' &&
                              tenant.noticeDate != null)
                            _DetailRow(
                              icon: Icons.event_busy_outlined,
                              label: 'Notice given',
                              value: formatDay(tenant.noticeDate!),
                            ),
                          if (tenant.moveOutDate != null)
                            _DetailRow(
                              icon: Icons.logout,
                              label: 'Moved out',
                              value: formatDay(tenant.moveOutDate!),
                            ),
                          _DetailRow(
                            icon: Icons.savings_outlined,
                            label: 'Rent deposit',
                            value: tenant.rentDepositDue > 0
                                ? formatKes(tenant.rentDepositDue)
                                : 'None',
                          ),
                          _DetailRow(
                            icon: Icons.water_drop_outlined,
                            label: 'Water deposit',
                            value: tenant.waterDepositDue > 0
                                ? formatKes(tenant.waterDepositDue)
                                : 'None',
                          ),
                          if ((tenant.waterPaymentReference ?? '').isNotEmpty)
                            _DetailRow(
                              icon: Icons.tag,
                              label: 'Water M-Pesa account',
                              value: tenant.waterPaymentReference!,
                            ),
                          if ((tenant.nationalId ?? '').isNotEmpty)
                            _DetailRow(
                              icon: Icons.badge_outlined,
                              label: 'ID number',
                              value: tenant.nationalId!,
                            ),
                          if ((tenant.email ?? '').isNotEmpty)
                            _DetailRow(
                              icon: Icons.mail_outline,
                              label: 'Email',
                              value: tenant.email!,
                            ),
                        ],
                      ),
                    ),
                    SectionLabel(
                      'Bills and payments',
                      trailing: DropdownButton<String>(
                        value: _period,
                        underline: const SizedBox.shrink(),
                        isDense: true,
                        style: AppText.small.copyWith(
                          color: colors.accentInk,
                          fontWeight: FontWeight.w700,
                        ),
                        items: [
                          for (final entry in _periods.entries)
                            DropdownMenuItem(
                              value: entry.key,
                              child: Text(entry.value),
                            ),
                        ],
                        onChanged: (value) {
                          if (value != null && value != _period) {
                            _changePeriod(value);
                          }
                        },
                      ),
                    ),
                    _StatementCard(statement: _statement),
                    const SizedBox(height: AppSpace.sm),
                    OutlinedButton.icon(
                      onPressed: _busy ? null : () => _downloadStatement(tenant),
                      icon: const Icon(Icons.picture_as_pdf_outlined),
                      label: Text(
                        'Statement PDF (${_periods[_period]!.toLowerCase()})',
                      ),
                    ),
                    if (property.canManageTenants) ...[
                      const SectionLabel('Documents'),
                      AppCard(
                        child: AttachmentsSection(
                          kind: FileKind.tenantDocument,
                          targetId: tenant.id,
                          emptyText:
                              'No documents yet. Add the ID copy or the signed agreement, as a photo or a PDF.',
                          addLabel: 'Add a document',
                          labelHint: 'ID copy',
                        ),
                      ),
                    ],
                  ],
                ),
              ),
      ),
    );
  }
}

class _BalanceCard extends StatelessWidget {
  const _BalanceCard({required this.tenant});

  final Tenant tenant;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'House ${tenant.unitNumber}',
                  style: AppText.small.copyWith(
                    color: colors.inkSoft,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              StatusChip(
                tenant.statusLabel,
                tone: switch (tenant.status) {
                  'notice_given' => Tone.warning,
                  'moved_out' || 'inactive' => Tone.neutral,
                  _ => Tone.success,
                },
              ),
            ],
          ),
          const SizedBox(height: AppSpace.md),
          Text(
            tenant.owes
                ? 'Owes'
                : (tenant.creditBalance > 0 ? 'Paid ahead' : 'Paid up'),
            style: AppText.small.copyWith(color: colors.inkFaint),
          ),
          const SizedBox(height: 2),
          Text(
            formatKes(tenant.owes ? tenant.balance : tenant.creditBalance),
            style: AppText.figure.copyWith(
              fontSize: 28,
              color: tenant.owes
                  ? colors.danger
                  : (tenant.creditBalance > 0 ? colors.success : colors.ink),
            ),
          ),
          if (tenant.owes && tenant.creditBalance > 0)
            Text(
              'Plus ${formatKes(tenant.creditBalance)} paid ahead, used for the next bills.',
              style: AppText.small.copyWith(color: colors.inkSoft),
            ),
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({
    required this.icon,
    required this.label,
    required this.value,
    this.onTap,
  });

  final IconData icon;
  final String label;
  final String value;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpace.lg,
          vertical: 12,
        ),
        child: Row(
          children: [
            Icon(icon, size: 19, color: colors.inkFaint),
            const SizedBox(width: 12),
            // Both may wrap: a long label never pushes the row off the screen.
            Flexible(
              child: Text(
                label,
                style: AppText.small.copyWith(
                  color: colors.inkSoft,
                  fontSize: 13,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                value,
                textAlign: TextAlign.right,
                style: AppText.label.copyWith(
                  color: onTap == null ? colors.ink : colors.accentInk,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatementCard extends StatelessWidget {
  const _StatementCard({required this.statement});

  final TenantStatement? statement;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final data = statement;

    if (data == null) {
      return const AppCard(child: SizedBox(height: 80, child: LoadingView()));
    }

    if (data.charges.isEmpty && data.payments.isEmpty) {
      return AppCard(
        child: Text(
          'No bills or payments in this period.',
          style: AppText.small.copyWith(color: colors.inkFaint),
        ),
      );
    }

    StatusChip chip(StatementCharge charge) => switch (charge.status) {
      'paid' => const StatusChip('Paid', tone: Tone.success),
      'partial' => const StatusChip('Part paid', tone: Tone.warning),
      'void' => const StatusChip('Cancelled'),
      'held' => const StatusChip('At move-out', tone: Tone.info),
      _ => const StatusChip('Unpaid', tone: Tone.danger),
    };

    return AppCard(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final charge in data.charges)
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpace.lg,
                vertical: 12,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          charge.label,
                          style: AppText.label.copyWith(
                            color: colors.ink,
                            fontSize: 13.5,
                          ),
                        ),
                        if (charge.dueDate != null)
                          Text(
                            'Due ${formatDay(charge.dueDate!)}',
                            style: AppText.small.copyWith(
                              color: colors.inkFaint,
                            ),
                          ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        formatKes(charge.amountDue),
                        style: AppText.amount.copyWith(
                          color: colors.ink,
                          fontSize: 13.5,
                        ),
                      ),
                      const SizedBox(height: 4),
                      chip(charge),
                    ],
                  ),
                ],
              ),
            ),
          if (data.payments.isNotEmpty) ...[
            Divider(height: 1, color: colors.line),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpace.lg,
                AppSpace.md,
                AppSpace.lg,
                0,
              ),
              child: Text(
                'PAYMENTS',
                style: AppText.eyebrow.copyWith(color: colors.inkFaint),
              ),
            ),
            for (final payment in data.payments)
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpace.lg,
                  vertical: 10,
                ),
                child: Row(
                  children: [
                    Icon(Icons.south_west, size: 17, color: colors.success),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        [
                          if (payment.receivedAt != null)
                            formatDay(payment.receivedAt!),
                          _methodLabel(payment.method),
                          if ((payment.reference ?? '').isNotEmpty)
                            payment.reference!,
                        ].join(' · '),
                        style: AppText.small.copyWith(color: colors.inkSoft),
                      ),
                    ),
                    Text(
                      formatKes(payment.amount),
                      style: AppText.amount.copyWith(
                        color: colors.success,
                        fontSize: 13.5,
                      ),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: AppSpace.sm),
          ],
        ],
      ),
    );
  }

  String _methodLabel(String method) => switch (method) {
    'mpesa' => 'M-Pesa',
    'cash' => 'Cash',
    'bank' => 'Bank',
    _ => 'Other',
  };
}

/// The date the tenant gave notice, as on the web's "Mark notice given".
class _NoticeSheet extends StatefulWidget {
  const _NoticeSheet({required this.tenant});

  final Tenant tenant;

  @override
  State<_NoticeSheet> createState() => _NoticeSheetState();
}

class _NoticeSheetState extends State<_NoticeSheet> {
  DateTime _date = DateTime.now();

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final tenant = widget.tenant;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpace.xl,
          0,
          AppSpace.xl,
          AppSpace.xl,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Mark notice given',
              style: AppText.title.copyWith(color: colors.ink),
            ),
            const SizedBox(height: AppSpace.sm),
            Text(
              'Records that ${tenant.fullName} has given notice to leave House ${tenant.unitNumber}. '
              'They stay a tenant and keep being billed until the owner moves them out.',
              style: AppText.small.copyWith(color: colors.inkSoft, fontSize: 13),
            ),
            const SizedBox(height: AppSpace.lg),
            DateField(
              label: 'Date notice was given',
              value: _date,
              lastDate: DateTime.now(),
              onChanged: (date) => setState(() => _date = date),
            ),
            const SizedBox(height: AppSpace.xl),
            FilledButton(
              onPressed: () => Navigator.pop(context, _date),
              child: const Text('Mark notice given'),
            ),
          ],
        ),
      ),
    );
  }
}
