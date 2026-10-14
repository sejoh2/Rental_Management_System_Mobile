import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/api_client.dart';
import '../../core/app_scope.dart';
import '../../core/app_theme.dart';
import '../../data/water_repository.dart';
import '../../models/caretaker_property.dart';
import '../../models/unit.dart';
import '../../utils/format.dart';
import '../../widgets/message_box.dart';

/// Records one meter reading for the tenant living in a unit.
///
/// Returns true to the screen before it when a reading was saved.
class RecordReadingPage extends StatefulWidget {
  const RecordReadingPage({
    super.key,
    required this.property,
    required this.unit,
    required this.month,
    required this.finalReading,
  });

  final CaretakerProperty property;
  final Unit unit;
  final DateTime month;

  /// A second reading this month, taken because the tenant is moving out.
  final bool finalReading;

  @override
  State<RecordReadingPage> createState() => _RecordReadingPageState();
}

class _RecordReadingPageState extends State<RecordReadingPage> {
  final _previous = TextEditingController();
  final _current = TextEditingController();
  final _notes = TextEditingController();

  /// Made once for this reading: sending it again (after a dropped
  /// connection) can never save it twice.
  final _saveKey = ApiClient.newSaveKey();

  late WaterRepository _repository;
  bool _started = false;

  /// What the meter last showed; null when the unit was never read.
  double? _lastRecorded;
  bool _loadingPrevious = true;
  String? _loadError;

  bool _saving = false;
  String? _error;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _repository = WaterRepository(AppScope.of(context).api);

    if (!_started) {
      _started = true;
      _loadPrevious();
    }
  }

  @override
  void dispose() {
    _previous.dispose();
    _current.dispose();
    _notes.dispose();
    super.dispose();
  }

  Future<void> _loadPrevious() async {
    setState(() {
      _loadingPrevious = true;
      _loadError = null;
    });

    try {
      final last = await _repository.previousReading(
        widget.property.id,
        widget.unit.id,
        billingPeriodOf(widget.month),
      );

      if (!mounted) return;

      setState(() {
        _lastRecorded = last;
        if (last != null) {
          _previous.text = formatNumber(last).replaceAll(',', '');
        }
      });
    } on ApiException catch (error) {
      if (mounted) setState(() => _loadError = error.message);
    } finally {
      if (mounted) setState(() => _loadingPrevious = false);
    }
  }

  double? get _previousValue => parseNumber(_previous.text);
  double? get _currentValue => parseNumber(_current.text);

  /// It may be raised, for water used while the unit stood empty, but never lowered.
  bool get _previousTooLow {
    final previous = _previousValue;

    return _lastRecorded != null &&
        previous != null &&
        previous < _lastRecorded!;
  }

  double? get _used {
    final previous = _previousValue;
    final current = _currentValue;

    return previous == null || current == null ? null : current - previous;
  }

  Future<void> _save() async {
    setState(() {
      _saving = true;
      _error = null;
    });

    try {
      final reading = await _repository.submitReading(
        propertyId: widget.property.id,
        unitId: widget.unit.id,
        billingPeriod: billingPeriodOf(widget.month),
        currentReading: _currentValue!,
        previousReading: _previousValue,
        notes: _notes.text.trim().isEmpty ? null : _notes.text.trim(),
        finalReading: widget.finalReading,
        saveKey: _saveKey,
      );

      if (!mounted) return;

      if (reading.isFlagged) {
        await showDialog<void>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: const Text('Saved, but flagged'),
            content: Text(
              '${formatNumber(reading.currentReading)} is lower than the previous reading of '
              '${formatNumber(reading.previousReading)}, so no bill was made. Fix it from the list when you have the right figure.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('OK'),
              ),
            ],
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'House ${widget.unit.unitNumber}: ${formatNumber(reading.unitsUsed ?? 0)} units, '
              '${formatKes(reading.billAmount ?? 0)} billed.',
            ),
          ),
        );
      }

      if (mounted) Navigator.pop(context, true);
    } on ApiException catch (error) {
      if (mounted) {
        setState(() {
          _error = error.message;
          _saving = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final unit = widget.unit;
    final rate = unit.waterRatePerUnit ?? widget.property.waterRatePerUnit ?? 0;
    final used = _used;
    final firstReading =
        !_loadingPrevious && _loadError == null && _lastRecorded == null;

    final ready =
        !_saving &&
        !_loadingPrevious &&
        _loadError == null &&
        _currentValue != null &&
        _previousValue != null &&
        !_previousTooLow;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.finalReading ? 'Final reading' : 'Record reading'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            'House ${unit.unitNumber}',
            style: TextStyle(
              color: colors.ink,
              fontSize: 20,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            '${unit.tenant?.fullName ?? ''} · ${monthLabel(widget.month)}'
            '${unit.meterNumber == null || unit.meterNumber!.isEmpty ? '' : ' · Meter ${unit.meterNumber}'}',
            style: TextStyle(color: colors.inkSoft, fontSize: 13),
          ),
          if (widget.finalReading) ...[
            const SizedBox(height: 10),
            Text(
              'The tenant is moving out. This reading starts from their earlier reading this month.',
              style: TextStyle(
                color: colors.inkSoft,
                fontSize: 13,
                height: 1.5,
              ),
            ),
          ],
          const SizedBox(height: 20),
          if (_loadError != null) ...[
            ErrorBox(_loadError!),
            const SizedBox(height: 10),
            OutlinedButton(
              onPressed: _loadPrevious,
              child: const Text('Try again'),
            ),
            const SizedBox(height: 16),
          ],
          TextField(
            controller: _previous,
            enabled: !_loadingPrevious && _loadError == null,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
            ],
            decoration: InputDecoration(
              labelText: 'Previous reading',
              hintText: _loadingPrevious ? 'Loading...' : 'e.g. 120',
              helperMaxLines: 3,
              helperText: firstReading
                  ? 'This unit has never been read. Enter what the meter showed when the tenant moved in.'
                  : _lastRecorded == null
                  ? null
                  : 'The last reading recorded (${formatNumber(_lastRecorded!)}). It can be raised if water was used while the unit stood empty, but not lowered.',
              errorText: _previousTooLow
                  ? 'It cannot be lower than ${formatNumber(_lastRecorded!)}.'
                  : null,
            ),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _current,
            autofocus: true,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
            ],
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
            decoration: const InputDecoration(
              labelText: 'Current reading',
              hintText: 'What the meter shows now',
            ),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: colors.surface,
              border: Border.all(color: colors.line),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              used == null
                  ? 'Rate: ${formatKes(rate)} per unit.'
                  : used < 0
                  ? 'The current reading is lower than the previous one. It will be saved as flagged and not billed until it is fixed.'
                  : '${formatNumber(used)} ${used == 1 ? 'unit' : 'units'} at ${formatKes(rate)}, so the bill will be ${formatKes(used * rate)}.',
              style: TextStyle(
                color: used != null && used < 0
                    ? colors.warning
                    : colors.inkSoft,
                fontSize: 14,
                height: 1.5,
              ),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _notes,
            textCapitalization: TextCapitalization.sentences,
            maxLines: 2,
            decoration: const InputDecoration(
              labelText: 'Note (optional)',
              hintText: 'e.g. Meter glass cracked',
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: 16),
            ErrorBox(_error!),
          ],
          const SizedBox(height: 20),
          FilledButton(
            onPressed: ready ? _save : null,
            child: Text(_saving ? 'Saving...' : 'Save reading'),
          ),
        ],
      ),
    );
  }
}
