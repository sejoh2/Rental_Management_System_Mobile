import 'package:flutter/material.dart';

import '../../core/api_client.dart';
import '../../core/app_scope.dart';
import '../../core/theme/app_theme.dart';
import '../../data/repair_repository.dart';
import '../../data/water_repository.dart';
import '../../models/caretaker_property.dart';
import '../../models/repair.dart';
import '../../models/unit.dart';
import '../../widgets/fields.dart';
import '../../widgets/message_box.dart';

/// Reports something that needs repairing, in a house or the whole property.
class RepairFormPage extends StatefulWidget {
  const RepairFormPage({super.key, required this.property});

  final CaretakerProperty property;

  @override
  State<RepairFormPage> createState() => _RepairFormPageState();
}

class _RepairFormPageState extends State<RepairFormPage> {
  final _title = TextEditingController();
  final _description = TextEditingController();

  /// Made once for this report: sending again after a dropped connection never reports it twice.
  final _saveKey = ApiClient.newSaveKey();

  /// Empty means the whole property.
  String _unitId = '';
  String _category = 'plumbing';
  String _priority = 'normal';

  /// Who pays: owner or tenant. Nothing is charged until it is done with a cost.
  String _payer = 'owner';
  String _timing = 'now';
  List<Unit>? _units;
  bool _saving = false;
  String? _error;
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    if (!_started) {
      _started = true;
      _loadUnits();
    }
  }

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    super.dispose();
  }

  Future<void> _loadUnits() async {
    try {
      final units = await WaterRepository(
        AppScope.read(context).api,
      ).listUnits(widget.property.id);

      if (mounted) {
        setState(() {
          _units = units.where((unit) => unit.status != 'inactive').toList()
            ..sort((a, b) => a.unitNumber.compareTo(b.unitNumber));
        });
      }
    } on ApiException catch (failure) {
      if (mounted) setState(() => _error = failure.message);
    }
  }

  Future<void> _save() async {
    setState(() {
      _saving = true;
      _error = null;
    });

    try {
      await RepairRepository(AppScope.read(context).api).report(
        widget.property.id,
        title: _title.text.trim(),
        description: _description.text.trim().isEmpty
            ? null
            : _description.text.trim(),
        category: _category,
        priority: _priority,
        unitId: _unitId.isEmpty ? null : _unitId,
        chargeToTenant: _tenantName != null && _payer == 'tenant',
        chargeTiming: _timing,
        saveKey: _saveKey,
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Repair reported. The owner sees it now.'),
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

  /// The tenant living in the chosen unit, if any: only they can be charged.
  String? get _tenantName => _units
      ?.where((unit) => unit.id == _unitId)
      .firstOrNull
      ?.tenant
      ?.fullName;

  @override
  Widget build(BuildContext context) {
    final units = _units;
    final tenantName = _tenantName;

    return Scaffold(
      appBar: AppBar(title: const Text('Report a repair')),
      body: ListView(
        padding: const EdgeInsets.all(AppSpace.page),
        children: [
          TextField(
            controller: _title,
            autofocus: true,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(
              labelText: 'What needs repairing',
              hintText: 'e.g. Leaking kitchen tap',
            ),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: AppSpace.lg),
          if (units == null && _error == null)
            const LoadingView()
          else
            SelectField<String>(
              label: 'Where',
              value: _unitId,
              options: {
                '': 'The whole property (shared areas)',
                for (final unit in units ?? const <Unit>[])
                  unit.id: unit.tenant == null
                      ? 'House ${unit.unitNumber}'
                      : 'House ${unit.unitNumber} · ${unit.tenant!.fullName}',
              },
              onChanged: (value) => setState(() => _unitId = value ?? ''),
            ),
          const SizedBox(height: AppSpace.lg),
          SelectField<String>(
            label: 'Kind of repair',
            value: _category,
            options: RepairLabels.categories,
            onChanged: (value) => setState(() => _category = value ?? 'other'),
          ),
          const SizedBox(height: AppSpace.lg),
          SelectField<String>(
            label: 'How urgent',
            value: _priority,
            options: const {
              'low': 'Low: can wait',
              'normal': 'Normal',
              'high': 'High: this week',
              'urgent': 'Urgent: today',
            },
            onChanged: (value) => setState(() => _priority = value ?? 'normal'),
          ),
          if (tenantName != null) ...[
            const SizedBox(height: AppSpace.lg),
            SelectField<String>(
              label: 'Who pays for this repair',
              value: _payer,
              options: {'owner': 'Owner', 'tenant': 'Tenant ($tenantName)'},
              helper:
                  'Choose the tenant when they caused the damage. Nothing is charged until it is done with a cost.',
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
          ],
          const SizedBox(height: AppSpace.lg),
          TextField(
            controller: _description,
            textCapitalization: TextCapitalization.sentences,
            minLines: 3,
            maxLines: 6,
            decoration: const InputDecoration(
              labelText: 'Details (optional)',
              hintText: 'What you saw, since when',
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: AppSpace.lg),
            ErrorBox(_error!),
          ],
          const SizedBox(height: AppSpace.xl),
          FilledButton(
            onPressed: _title.text.trim().length >= 3 && !_saving
                ? _save
                : null,
            child: Text(_saving ? 'Saving...' : 'Report repair'),
          ),
        ],
      ),
    );
  }
}
