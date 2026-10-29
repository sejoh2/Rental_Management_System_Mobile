import 'package:flutter/material.dart';

import '../../core/api_client.dart';
import '../../core/app_scope.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text.dart';
import '../../core/theme/app_theme.dart';
import '../../data/tenant_repository.dart';
import '../../models/tenant.dart';
import '../../utils/format.dart';
import '../../widgets/fields.dart';
import '../../widgets/message_box.dart';

/// The same words as the web's "Record manual payment".
const paymentMethods = {
  'cash': 'Cash',
  'mpesa': 'M-Pesa',
  'bank': 'Bank transfer',
  'other': 'Other',
};

const paymentAccounts = {
  'rent': 'Rent',
  'water': 'Water',
  'electricity': 'Electricity',
  'service': 'Service charges',
};

/// What each choice of "Apply to" settles, as the web explains it.
const paymentAccountHints = {
  'rent':
      'Settles the rent deposit first, then rent. It also covers the water and electricity deposits '
      'and bills, but only if this property has no separate account for them, and service charges '
      'if the property has them paid into the rent account.',
  'water':
      'Settles the water deposit and water bills, and service charges if the property has them paid '
      'into the water account.',
  'electricity':
      'Settles the electricity deposit and electricity bills, and service charges if the property has '
      'them paid into the electricity account.',
  'service':
      'Settles service charges, such as garbage or security, and repairs charged to the tenant.',
};

/// An M-Pesa receipt number as the server keeps it: no spaces, capitals.
String normalizeReceipt(String text) =>
    text.replaceAll(RegExp(r'\s+'), '').toUpperCase();

/// Why the receipt number cannot be saved yet, or null when it can. Money
/// paid by M-Pesa must carry its receipt number (TJU4K8P2QX), so the same
/// money is never counted twice; other methods do not need one. The same
/// rule as the web and the server.
String? receiptProblem(String method, String text) {
  if (method != 'mpesa') return null;

  final receipt = normalizeReceipt(text);

  if (receipt.isEmpty) return 'Enter the M-Pesa receipt number.';

  return RegExp(r'^[A-Z0-9]{8,12}$').hasMatch(receipt)
      ? null
      : 'An M-Pesa receipt number is 10 letters and digits, for example TJU4K8P2QX.';
}

/// When a payment was received: now for today (so the receipt shows the
/// real time), midday for an earlier day. As on the web.
DateTime receivedAtFor(DateTime day, DateTime now) {
  final today = DateTime(now.year, now.month, now.day);

  return DateTime(day.year, day.month, day.day) == today
      ? now
      : DateTime(day.year, day.month, day.day, 12);
}

/// Records cash, or any payment that did not come through M-Pesa
/// matching. Shown only when the owner has allowed this caretaker to record
/// payments in the property.
class RecordPaymentPage extends StatefulWidget {
  const RecordPaymentPage({super.key, required this.tenant});

  final Tenant tenant;

  @override
  State<RecordPaymentPage> createState() => _RecordPaymentPageState();
}

class _RecordPaymentPageState extends State<RecordPaymentPage> {
  final _amount = TextEditingController();
  final _reference = TextEditingController();
  final _notes = TextEditingController();

  /// Made once for this payment: sending again after a dropped connection never records it twice.
  final _saveKey = ApiClient.newSaveKey();

  String _method = 'cash';
  String _account = 'rent';
  DateTime _received = DateTime.now();
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _amount.dispose();
    _reference.dispose();
    _notes.dispose();
    super.dispose();
  }

  double? get _value {
    final value = parseNumber(_amount.text);

    return value == null || value <= 0 ? null : value;
  }

  Future<void> _confirmAndSave() async {
    final amount = _value!;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Record this payment?'),
        content: Text(
          '${formatKes(amount)} from ${widget.tenant.fullName}, ${paymentMethods[_method]!.toLowerCase()}, '
          'for ${paymentAccounts[_account]!.toLowerCase()}, on ${formatDay(_received)}. '
          'It is recorded under your name and the owner sees it.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Check again'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Record it'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() {
      _saving = true;
      _error = null;
    });

    try {
      await TenantRepository(AppScope.read(context).api).recordPayment(
        widget.tenant.id,
        amount: amount,
        method: _method,
        accountFor: _account,
        receivedAt: receivedAtFor(_received, DateTime.now()),
        reference: _method == 'mpesa'
            ? normalizeReceipt(_reference.text)
            : _reference.text.trim().isEmpty
            ? null
            : _reference.text.trim(),
        notes: _notes.text.trim().isEmpty ? null : _notes.text.trim(),
        saveKey: _saveKey,
      );

      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('${formatKes(amount)} recorded.')));
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
    final colors = AppColors.of(context);
    final tenant = widget.tenant;

    return Scaffold(
      appBar: AppBar(title: const Text('Record a payment')),
      body: ListView(
        padding: const EdgeInsets.all(AppSpace.page),
        children: [
          Text(
            tenant.fullName,
            style: AppText.title.copyWith(color: colors.ink),
          ),
          Text(
            'House ${tenant.unitNumber} · ${tenant.owes ? 'owes ${formatKes(tenant.balance)}' : 'nothing owed'}',
            style: AppText.small.copyWith(color: colors.inkSoft),
          ),
          const SizedBox(height: AppSpace.md),
          NoteBox(
            'For cash, or any payment that didn’t come through M-Pesa auto-matching. '
            'This is applied straight to ${tenant.fullName}’s balance for House ${tenant.unitNumber}, deposits first.',
          ),
          const SizedBox(height: AppSpace.xl),
          AmountField(
            controller: _amount,
            label: 'Amount',
            autofocus: true,
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: AppSpace.lg),
          DateField(
            label: 'Date received',
            value: _received,
            lastDate: DateTime.now(),
            onChanged: (date) => setState(() => _received = date),
          ),
          const SizedBox(height: AppSpace.lg),
          SelectField<String>(
            label: 'Payment method',
            value: _method,
            options: paymentMethods,
            onChanged: (value) => setState(() => _method = value ?? 'cash'),
          ),
          const SizedBox(height: AppSpace.lg),
          SelectField<String>(
            label: 'Apply to',
            value: _account,
            options: paymentAccounts,
            onChanged: (value) => setState(() => _account = value ?? 'rent'),
          ),
          const SizedBox(height: AppSpace.sm),
          Text(
            '${paymentAccountHints[_account]} Anything left over is kept as credit for the next bill.',
            style: AppText.small.copyWith(color: colors.inkFaint),
          ),
          const SizedBox(height: AppSpace.lg),
          TextField(
            controller: _reference,
            textCapitalization: TextCapitalization.characters,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              labelText: _method == 'mpesa'
                  ? 'M-Pesa receipt number'
                  : 'Reference (optional)',
              hintText: _method == 'mpesa'
                  ? 'e.g. TJU4K8P2QX'
                  : 'e.g. receipt or transaction number',
              helperText: _method == 'mpesa'
                  ? 'Required for M-Pesa. It is at the start of the tenant’s M-Pesa message.'
                  : null,
              helperMaxLines: 2,
              errorText: _method == 'mpesa' && _reference.text.trim().isNotEmpty
                  ? receiptProblem(_method, _reference.text)
                  : null,
            ),
          ),
          const SizedBox(height: AppSpace.lg),
          TextField(
            controller: _notes,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(
              labelText: 'Notes (optional)',
              hintText: 'e.g. Paid in person at the office',
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: AppSpace.lg),
            ErrorBox(_error!),
          ],
          const SizedBox(height: AppSpace.xl),
          FilledButton(
            onPressed:
                _value != null &&
                    receiptProblem(_method, _reference.text) == null &&
                    !_saving
                ? _confirmAndSave
                : null,
            child: Text(_saving ? 'Recording...' : 'Record payment'),
          ),
        ],
      ),
    );
  }
}
