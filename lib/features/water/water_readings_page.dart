import 'package:flutter/material.dart';

import '../../core/api_client.dart';
import '../../core/app_scope.dart';
import '../../core/theme/app_colors.dart';
import '../../data/water_repository.dart';
import '../../models/app_file.dart';
import '../../models/caretaker_property.dart';
import '../../models/unit.dart';
import '../../models/water_reading.dart';
import '../../utils/format.dart';
import '../../widgets/attachments.dart';
import '../../widgets/message_box.dart';
import 'reading_forms.dart';
import 'record_reading_page.dart';

/// A month's meter readings for a property: who still has to be read, and
/// what was recorded.
class WaterReadingsPage extends StatefulWidget {
  const WaterReadingsPage({super.key, required this.property});

  final CaretakerProperty property;

  @override
  State<WaterReadingsPage> createState() => _WaterReadingsPageState();
}

class _WaterReadingsPageState extends State<WaterReadingsPage> {
  DateTime _month = monthOf(DateTime.now());

  List<Unit>? _units;
  List<WaterReading>? _readings;
  String? _error;
  bool _loading = true;
  bool _started = false;

  late WaterRepository _repository;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _repository = WaterRepository(AppScope.of(context).api);

    if (!_started) {
      _started = true;
      _load();
    }
  }

  bool get _isCurrentMonth => _month == monthOf(DateTime.now());

  Future<void> _load() async {
    final month = _month;

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final period = billingPeriodOf(month);

      // Both at once: one wait instead of two.
      final results = await Future.wait([
        _repository.listUnits(widget.property.id),
        _repository.listReadings(widget.property.id, period),
      ]);

      // The month was changed while this was loading; that load wins.
      if (!mounted || month != _month) return;

      setState(() {
        _units = results[0] as List<Unit>;
        _readings = results[1] as List<WaterReading>;
      });
    } on ApiException catch (error) {
      if (mounted && month == _month) setState(() => _error = error.message);
    } finally {
      if (mounted && month == _month) setState(() => _loading = false);
    }
  }

  void _changeMonth(int by) {
    setState(() {
      _month = DateTime(_month.year, _month.month + by);
      _readings = null;
    });

    _load();
  }

  Future<void> _open(Widget page) async {
    final changed = await Navigator.of(
      context,
    ).push<bool>(MaterialPageRoute(builder: (_) => page));

    if (changed == true) _load();
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final units = _units;
    final readings = _readings;

    // Readings that still count, grouped by unit, so each unit is looked up once.
    final byUnit = <String, List<WaterReading>>{};

    for (final reading in readings ?? const <WaterReading>[]) {
      if (reading.stillCounts) (byUnit[reading.unitId] ??= []).add(reading);
    }

    // The current tenant's readings of the month for a unit.
    List<WaterReading> readingsOf(Unit unit) => [
      for (final reading in byUnit[unit.id] ?? const <WaterReading>[])
        if (reading.tenantId == unit.tenant?.id) reading,
    ];

    // Only metered units with a tenant are billed for water.
    final metered = [
      for (final unit in units ?? const <Unit>[])
        if (unit.isMetered && unit.isOccupied) unit,
    ];
    final waiting = [
      for (final unit in metered)
        if (readingsOf(unit).isEmpty) unit,
    ];
    final unitsById = {for (final unit in metered) unit.id: unit};

    final recorded = [...?readings]
      // Still-counting readings first; cancelled and rejected ones at the end.
      ..sort(
        (a, b) =>
            (a.stillCounts == b.stillCounts) ? 0 : (a.stillCounts ? -1 : 1),
      );

    // A final reading is a second one, for a tenant already read this month who is moving out.
    bool canTakeFinal(WaterReading reading) {
      final unit = unitsById[reading.unitId];

      if (unit == null ||
          !reading.stillCounts ||
          reading.tenantId != unit.tenant?.id) {
        return false;
      }

      return !readingsOf(unit).any((item) => item.isFinal);
    }

    // Shown in the Water & Electricity tab, under its title.
    return Scaffold(
      body: RefreshIndicator(
        onRefresh: _load,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
                child: Row(
                  children: [
                    IconButton(
                      onPressed: () => _changeMonth(-1),
                      tooltip: 'Previous month',
                      icon: const Icon(Icons.chevron_left),
                    ),
                    Expanded(
                      child: Text(
                        monthLabel(_month),
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: colors.ink,
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    IconButton(
                      // Readings are never recorded for a month that has not started.
                      onPressed: _isCurrentMonth ? null : () => _changeMonth(1),
                      tooltip: 'Next month',
                      icon: const Icon(Icons.chevron_right),
                    ),
                  ],
                ),
              ),
            ),
            if (units != null && readings != null)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                  child: Text(
                    metered.isEmpty
                        ? 'No metered unit has a tenant.'
                        : '${metered.length - waiting.length} of ${metered.length} read',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: colors.inkSoft, fontSize: 13),
                  ),
                ),
              ),
            if (_error != null)
              SliverPadding(
                padding: const EdgeInsets.all(16),
                sliver: SliverToBoxAdapter(child: ErrorBox(_error!)),
              ),
            if (readings == null && _loading)
              const SliverFillRemaining(
                child: Center(child: CircularProgressIndicator()),
              ),
            if (waiting.isNotEmpty && readings != null) ...[
              _heading('To read (${waiting.length})', colors),
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                sliver: SliverList.separated(
                  itemCount: waiting.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final unit = waiting[index];

                    return _WaitingTile(
                      unit: unit,
                      onRecord: () => _open(
                        RecordReadingPage(
                          property: widget.property,
                          unit: unit,
                          month: _month,
                          finalReading: false,
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
            if (recorded.isNotEmpty) ...[
              _heading('Recorded (${recorded.length})', colors),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                sliver: SliverList.separated(
                  itemCount: recorded.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final reading = recorded[index];

                    return _ReadingTile(
                      reading: reading,
                      onTap: () => _showActions(
                        reading,
                        canTakeFinal(reading)
                            ? unitsById[reading.unitId]
                            : null,
                      ),
                    );
                  },
                ),
              ),
            ],
            if (readings != null &&
                recorded.isEmpty &&
                waiting.isEmpty &&
                metered.isNotEmpty)
              SliverFillRemaining(
                child: Center(
                  child: Text(
                    'Nothing recorded for this month.',
                    style: TextStyle(color: colors.inkSoft),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _heading(String text, AppColors colors) {
    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      sliver: SliverToBoxAdapter(
        child: Text(
          text.toUpperCase(),
          style: TextStyle(
            color: colors.inkFaint,
            fontSize: 11,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.6,
          ),
        ),
      ),
    );
  }

  /// The meter photos of a reading, and a way to add one.
  void _showPhotos(WaterReading reading) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ReadingSummary(reading: reading),
              const SizedBox(height: 12),
              AttachmentsSection(
                kind: FileKind.meterPhoto,
                targetId: reading.id,
                emptyText:
                    'No meter photo yet. A photo settles any question about the bill later.',
                addLabel: 'Add a meter photo',
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// What can be done with a recorded reading.
  void _showActions(WaterReading reading, Unit? finalFor) {
    final actions = <(IconData, String, VoidCallback)>[
      (Icons.photo_camera_outlined, 'Meter photos', () => _showPhotos(reading)),
      if (reading.isFlagged)
        (
          Icons.build_outlined,
          'Fix this reading',
          () => _open(FixFlaggedPage(reading: reading)),
        ),
      if (reading.canEdit) ...[
        (
          Icons.edit_outlined,
          'Edit the figures',
          () => _open(EditReadingPage(reading: reading)),
        ),
        (
          Icons.cancel_outlined,
          'Cancel this reading and its bill',
          () => _open(CancelReadingPage(reading: reading)),
        ),
      ],
      if (finalFor != null)
        (
          Icons.logout,
          'Record a final reading (moving out)',
          () => _open(
            RecordReadingPage(
              property: widget.property,
              unit: finalFor,
              month: _month,
              finalReading: true,
            ),
          ),
        ),
    ];

    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) {
        final colors = AppColors.of(sheetContext);

        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ReadingSummary(reading: reading),
                const SizedBox(height: 12),
                if (actions.isEmpty)
                  Text(
                    reading.stillCounts
                        ? 'This reading was settled from the tenant’s deposit at move-out and can no longer be changed here. Ask the owner.'
                        : 'This reading no longer counts.',
                    style: TextStyle(
                      color: colors.inkSoft,
                      fontSize: 13,
                      height: 1.5,
                    ),
                  ),
                for (final (icon, label, action) in actions)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(icon, color: colors.accentInk),
                    title: Text(
                      label,
                      style: TextStyle(
                        color: colors.ink,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    onTap: () {
                      Navigator.pop(sheetContext);
                      action();
                    },
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _WaitingTile extends StatelessWidget {
  const _WaitingTile({required this.unit, required this.onRecord});

  final Unit unit;
  final VoidCallback onRecord;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 10, 10, 10),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'House ${unit.unitNumber}',
                    style: TextStyle(
                      color: colors.ink,
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    unit.tenant?.fullName ?? '',
                    style: TextStyle(color: colors.inkSoft, fontSize: 13),
                  ),
                ],
              ),
            ),
            SizedBox(
              width: 110,
              child: FilledButton(
                onPressed: onRecord,
                style: FilledButton.styleFrom(minimumSize: const Size(0, 42)),
                child: const Text('Record'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ReadingTile extends StatelessWidget {
  const _ReadingTile({required this.reading, required this.onTap});

  final WaterReading reading;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final faded = !reading.stillCounts;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'House ${reading.unitNumber} · ${reading.tenantName ?? 'No tenant'}',
                      style: TextStyle(
                        color: faded ? colors.inkFaint : colors.ink,
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  readingStatusChip(reading),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                '${formatNumber(reading.previousReading)} → ${formatNumber(reading.currentReading)}'
                '${reading.unitsUsed == null ? '' : ' · ${formatNumber(reading.unitsUsed!)} units'}'
                '${reading.billAmount == null ? '' : ' · ${formatKes(reading.billAmount!)}'}',
                style: TextStyle(
                  color: faded ? colors.inkFaint : colors.inkSoft,
                  fontSize: 13,
                ),
              ),
              if (reading.isFinal)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    'Final reading at move-out',
                    style: TextStyle(color: colors.inkFaint, fontSize: 12),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
