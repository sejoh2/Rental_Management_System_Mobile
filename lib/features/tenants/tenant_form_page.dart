import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/api_client.dart';
import '../../core/app_scope.dart';
import '../../core/theme/app_theme.dart';
import '../../data/tenant_repository.dart';
import '../../data/water_repository.dart';
import '../../models/caretaker_property.dart';
import '../../models/tenant.dart';
import '../../models/unit.dart';
import '../../utils/format.dart';
import '../../widgets/fields.dart';
import '../../widgets/message_box.dart';

/// Adds a tenant to a vacant unit, or edits a tenant's details.
/// Only for a caretaker who may manage tenants (level 2).
class TenantFormPage extends StatefulWidget {
  const TenantFormPage({super.key, required this.property, this.tenant});

  final CaretakerProperty property;

  /// Set when editing.
  final Tenant? tenant;

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
  String? _unitId;
  bool _saving = false;
  String? _error;
  bool _started = false;

  bool get _editing => widget.tenant != null;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    if (!_started) {
      _started = true;
      if (!_editing) _loadUnits();
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
      final vacant = units.where((unit) => unit.status == 'vacant').toList()
        ..sort((a, b) => a.unitNumber.compareTo(b.unitNumber));

      if (mounted) setState(() => _vacant = vacant);
    } on ApiException catch (failure) {
      if (mounted) setState(() => _error = failure.message);
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
            const SizedBox(height: AppSpace.md),
            const NoteBox(
              'Their deposits and first month are worked out by the property’s rules when you save, '
              'and appear on their profile.',
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
