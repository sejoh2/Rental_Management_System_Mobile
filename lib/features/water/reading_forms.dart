import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/api_client.dart';
import '../../core/app_scope.dart';
import '../../core/theme/app_colors.dart';
import '../../data/water_repository.dart';
import '../../models/water_reading.dart';
import '../../utils/format.dart';
import '../../widgets/message_box.dart';
import '../../widgets/status_chip.dart';

/// The status of a reading and its bill, worded as on the web.
StatusChip readingStatusChip(WaterReading reading) {
  if (reading.isFlagged) return const StatusChip('Flagged', tone: Tone.danger);

  if (!reading.stillCounts) {
    final cancelled = (reading.notes ?? '').startsWith('Cancelled:');

    return StatusChip(cancelled ? 'Cancelled' : 'Rejected');
  }

  return switch (reading.billStatus) {
    'paid' => const StatusChip('Paid', tone: Tone.success),
    'partial' => const StatusChip('Part paid', tone: Tone.warning),
    'void' => const StatusChip('Bill cancelled'),
    _ => const StatusChip('Unpaid', tone: Tone.warning),
  };
}

/// The figures of a reading, at the top of each form about it.
class ReadingSummary extends StatelessWidget {
  const ReadingSummary({super.key, required this.reading});

  final WaterReading reading;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'House ${reading.unitNumber}',
                style: TextStyle(
                  color: colors.ink,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            readingStatusChip(reading),
          ],
        ),
        if (reading.tenantName != null)
          Text(
            reading.tenantName!,
            style: TextStyle(color: colors.inkSoft, fontSize: 13),
          ),
        const SizedBox(height: 8),
        Text(
          '${formatNumber(reading.previousReading)} → ${formatNumber(reading.currentReading)}'
          '${reading.billAmount == null ? '' : ', a bill of ${formatKes(reading.billAmount!)}'}'
          '${reading.paid > 0 ? ' (${formatKes(reading.paid)} paid)' : ''}',
          style: TextStyle(color: colors.inkSoft, fontSize: 14),
        ),
        if ((reading.notes ?? '').isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(
            reading.notes!,
            style: TextStyle(color: colors.inkFaint, fontSize: 12),
          ),
        ],
      ],
    );
  }
}

/// Shared by the forms below: one action that may fail, then back with true.
mixin _Saving<T extends StatefulWidget> on State<T> {
  bool saving = false;
  String? error;

  WaterRepository get repository => WaterRepository(AppScope.of(context).api);

  Future<void> run(Future<void> Function() action, {String? done}) async {
    setState(() {
      saving = true;
      error = null;
    });

    try {
      await action();

      if (!mounted) return;

      if (done != null) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(done)));
      }
      Navigator.pop(context, true);
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

Widget _numberField(
  TextEditingController controller,
  String label,
  VoidCallback changed, {
  bool autofocus = false,
  String? helper,
}) {
  return TextField(
    controller: controller,
    autofocus: autofocus,
    keyboardType: const TextInputType.numberWithOptions(decimal: true),
    inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))],
    decoration: InputDecoration(
      labelText: label,
      helperText: helper,
      helperMaxLines: 3,
    ),
    onChanged: (_) => changed(),
  );
}

String _plain(double value) => formatNumber(value).replaceAll(',', '');

/// Corrects the figures of a reading; its bill is corrected with them.
class EditReadingPage extends StatefulWidget {
  const EditReadingPage({super.key, required this.reading});

  final WaterReading reading;

  @override
  State<EditReadingPage> createState() => _EditReadingPageState();
}

class _EditReadingPageState extends State<EditReadingPage> with _Saving {
  late final _previous = TextEditingController(
    text: _plain(widget.reading.previousReading),
  );
  late final _current = TextEditingController(
    text: _plain(widget.reading.currentReading),
  );
  final _notes = TextEditingController();

  @override
  void dispose() {
    _previous.dispose();
    _current.dispose();
    _notes.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final reading = widget.reading;
    final previous = parseNumber(_previous.text);
    final current = parseNumber(_current.text);
    final used = previous == null || current == null
        ? null
        : current - previous;
    final rate = reading.ratePerUnit ?? 0;
    final newBill = used == null || used < 0 ? null : used * rate;
    final unchanged =
        previous == reading.previousReading &&
        current == reading.currentReading;

    String explanation() {
      if (used == null) return 'Enter both readings.';
      if (used < 0) {
        return 'The current reading cannot be lower than the previous reading.';
      }

      final paid = reading.paid;
      final bill = newBill!;
      final head =
          '${formatNumber(used)} ${used == 1 ? 'unit' : 'units'} at ${formatKes(rate)}: the bill becomes ${formatKes(bill)}'
          '${reading.billAmount == null ? '' : ' (it was ${formatKes(reading.billAmount!)})'}.';

      if (bill == 0) return '$head Nothing was used, so the bill is cancelled.';
      if (paid > bill) {
        return '$head The tenant paid ${formatKes(paid)}; the ${formatKes(paid - bill)} above the new bill goes back to them as credit.';
      }
      if (paid > 0) {
        return '$head The tenant paid ${formatKes(paid)}, so ${formatKes(bill - paid)} will still be owed.';
      }

      return head;
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Edit reading')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          ReadingSummary(reading: reading),
          const SizedBox(height: 20),
          _numberField(
            _previous,
            'Previous reading',
            () => setState(() {}),
            helper: 'It cannot go below the reading recorded before this one.',
          ),
          const SizedBox(height: 16),
          _numberField(
            _current,
            'Current reading',
            () => setState(() {}),
            autofocus: true,
            helper:
                'If a later reading exists for this unit, it cannot go above where that one starts.',
          ),
          const SizedBox(height: 16),
          Text(
            explanation(),
            style: TextStyle(
              color: used != null && used < 0 ? colors.danger : colors.inkSoft,
              fontSize: 14,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _notes,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(
              labelText: 'Why is it being changed (optional)',
              hintText: 'e.g. Typed 280 instead of 180',
            ),
          ),
          if (error != null) ...[const SizedBox(height: 16), ErrorBox(error!)],
          const SizedBox(height: 20),
          FilledButton(
            onPressed: saving || used == null || used < 0 || unchanged
                ? null
                : () => run(
                    () => repository.editReading(
                      reading.id,
                      previousReading: previous!,
                      currentReading: current!,
                      notes: _notes.text.trim().isEmpty
                          ? null
                          : _notes.text.trim(),
                    ),
                    done: 'Reading corrected.',
                  ),
            child: Text(saving ? 'Saving...' : 'Save correction'),
          ),
        ],
      ),
    );
  }
}

/// Removes a reading that should not have been recorded, with its bill.
class CancelReadingPage extends StatefulWidget {
  const CancelReadingPage({super.key, required this.reading});

  final WaterReading reading;

  @override
  State<CancelReadingPage> createState() => _CancelReadingPageState();
}

class _CancelReadingPageState extends State<CancelReadingPage> with _Saving {
  final _reason = TextEditingController();

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final reading = widget.reading;
    final ready = _reason.text.trim().length >= 3 && !saving;

    return Scaffold(
      appBar: AppBar(title: const Text('Cancel reading')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          ReadingSummary(reading: reading),
          const SizedBox(height: 16),
          Text(
            'The reading and its bill are cancelled. The reading stays on the list, marked Cancelled, and a new one can be recorded for the same month. If only the figures are wrong, use Edit instead.',
            style: TextStyle(color: colors.inkSoft, fontSize: 14, height: 1.5),
          ),
          const SizedBox(height: 10),
          Text(
            reading.paid > 0
                ? 'The tenant paid ${formatKes(reading.paid)} towards this bill. It goes back to them as credit and is used for their other bills.'
                : 'Nothing was paid towards this bill, so no money moves.',
            style: TextStyle(color: colors.inkSoft, fontSize: 14, height: 1.5),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _reason,
            autofocus: true,
            textCapitalization: TextCapitalization.sentences,
            maxLength: 500,
            decoration: const InputDecoration(
              labelText: 'Why is it being cancelled',
              hintText: 'e.g. Recorded for the wrong house',
            ),
            onChanged: (_) => setState(() {}),
          ),
          if (error != null) ...[const SizedBox(height: 8), ErrorBox(error!)],
          const SizedBox(height: 16),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: colors.danger),
            onPressed: ready
                ? () => run(
                    () => repository.cancelReading(
                      reading.id,
                      _reason.text.trim(),
                    ),
                    done: 'Reading cancelled.',
                  )
                : null,
            child: Text(saving ? 'Cancelling...' : 'Cancel reading and bill'),
          ),
        ],
      ),
    );
  }
}

/// A flagged reading (lower than the one before): enter the right figure, or throw it out.
class FixFlaggedPage extends StatefulWidget {
  const FixFlaggedPage({super.key, required this.reading});

  final WaterReading reading;

  @override
  State<FixFlaggedPage> createState() => _FixFlaggedPageState();
}

class _FixFlaggedPageState extends State<FixFlaggedPage> with _Saving {
  final _current = TextEditingController();
  final _notes = TextEditingController();

  @override
  void dispose() {
    _current.dispose();
    _notes.dispose();
    super.dispose();
  }

  String? get _note => _notes.text.trim().isEmpty ? null : _notes.text.trim();

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final reading = widget.reading;
    final corrected = parseNumber(_current.text);
    final valid = corrected != null && corrected >= reading.previousReading;

    return Scaffold(
      appBar: AppBar(title: const Text('Fix reading')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          ReadingSummary(reading: reading),
          const SizedBox(height: 16),
          Text(
            '${formatNumber(reading.currentReading)} is lower than the previous reading of ${formatNumber(reading.previousReading)}, so no bill was made. Enter what the meter really shows, or throw this reading out.',
            style: TextStyle(color: colors.inkSoft, fontSize: 14, height: 1.5),
          ),
          const SizedBox(height: 16),
          _numberField(
            _current,
            'Correct current reading',
            () => setState(() {}),
            autofocus: true,
            helper: 'At least ${formatNumber(reading.previousReading)}.',
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _notes,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(labelText: 'Note (optional)'),
          ),
          if (error != null) ...[const SizedBox(height: 16), ErrorBox(error!)],
          const SizedBox(height: 20),
          FilledButton(
            onPressed: saving || !valid
                ? null
                : () => run(
                    () => repository.correctFlagged(
                      reading.id,
                      corrected,
                      notes: _note,
                    ),
                    done: 'Reading corrected and billed.',
                  ),
            child: Text(saving ? 'Saving...' : 'Save and bill'),
          ),
          const SizedBox(height: 8),
          OutlinedButton(
            onPressed: saving
                ? null
                : () => run(
                    () => repository.rejectFlagged(reading.id, notes: _note),
                    done: 'Reading thrown out.',
                  ),
            child: const Text('Throw this reading out'),
          ),
        ],
      ),
    );
  }
}
