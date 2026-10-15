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

const _methods = {
  'cash': 'Cash',
  'mpesa': 'M-Pesa (to a personal number)',
  'bank': 'Bank deposit',
  'other': 'Other',
};

const _accounts = {
  'rent': 'Rent and deposits',
  'water': 'Water',
  'electricity': 'Electricity',
  'service': 'Service charges',
};

/// Records money a tenant handed over in person. Shown only when the owner
/// has allowed this caretaker to record payments in the property.
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
          '${formatKes(amount)} from ${widget.tenant.fullName}, ${_methods[_method]!.toLowerCase()}, '
          'on ${formatDay(_received)}. It is recorded under your name and the owner sees it.',
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
        receivedAt: DateTime(
          _received.year,
          _received.month,
          _received.day,
          12,
        ),
        reference: _reference.text.trim().isEmpty
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
          const SizedBox(height: AppSpace.xl),
          AmountField(
            controller: _amount,
            label: 'Amount received',
            autofocus: true,
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: AppSpace.lg),
          SelectField<String>(
            label: 'How it was paid',
            value: _method,
            options: _methods,
            onChanged: (value) => setState(() => _method = value ?? 'cash'),
          ),
          const SizedBox(height: AppSpace.lg),
          SelectField<String>(
            label: 'Paid towards',
            value: _account,
            options: _accounts,
            helper:
                'Applied to the tenant’s bills of this kind, as on the web; anything extra is kept as credit.',
            onChanged: (value) => setState(() => _account = value ?? 'rent'),
          ),
          const SizedBox(height: AppSpace.lg),
          DateField(
            label: 'Date received',
            value: _received,
            lastDate: DateTime.now(),
            onChanged: (date) => setState(() => _received = date),
          ),
          const SizedBox(height: AppSpace.lg),
          TextField(
            controller: _reference,
            textCapitalization: TextCapitalization.characters,
            decoration: const InputDecoration(
              labelText: 'Reference (optional)',
              hintText: 'e.g. M-Pesa code or slip number',
            ),
          ),
          const SizedBox(height: AppSpace.lg),
          TextField(
            controller: _notes,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(labelText: 'Note (optional)'),
          ),
          if (_error != null) ...[
            const SizedBox(height: AppSpace.lg),
            ErrorBox(_error!),
          ],
          const SizedBox(height: AppSpace.xl),
          FilledButton(
            onPressed: _value != null && !_saving ? _confirmAndSave : null,
            child: Text(_saving ? 'Saving...' : 'Record payment'),
          ),
        ],
      ),
    );
  }
}
