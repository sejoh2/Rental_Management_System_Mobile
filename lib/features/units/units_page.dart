import 'package:flutter/material.dart';

import '../../core/api_client.dart';
import '../../core/app_scope.dart';
import '../../core/theme/app_colors.dart';
import '../../data/water_repository.dart';
import '../../models/caretaker_property.dart';
import '../../models/unit.dart';
import '../../utils/format.dart';
import '../../widgets/message_box.dart';
import '../../widgets/status_chip.dart';
import '../../widgets/property_gate.dart';

/// The units of a property, who lives in each, and what they owe.
class UnitsPage extends StatefulWidget {
  const UnitsPage({super.key, required this.property});

  final CaretakerProperty property;

  @override
  State<UnitsPage> createState() => _UnitsPageState();
}

enum _Filter { all, occupied, vacant, owing }

class _UnitsPageState extends State<UnitsPage> {
  List<Unit>? _units;
  String? _error;
  bool _loading = true;
  bool _started = false;
  _Filter _filter = _Filter.all;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    if (!_started) {
      _started = true;
      _load();
    }
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final units = await WaterRepository(
        AppScope.of(context).api,
      ).listUnits(widget.property.id);

      // Units the owner took out of use are not shown to the caretaker.
      if (mounted) {
        setState(
          () => _units = units
              .where((unit) => unit.status != 'inactive')
              .toList(),
        );
      }
    } on ApiException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  bool _matches(Unit unit) {
    return switch (_filter) {
      _Filter.all => true,
      _Filter.occupied => unit.isOccupied,
      _Filter.vacant => !unit.isOccupied,
      _Filter.owing => (unit.tenant?.balance ?? 0) > 0,
    };
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final units = _units;
    final shown = units?.where(_matches).toList() ?? const <Unit>[];

    return Scaffold(
      appBar: AppBar(title: const Text('Units'), bottom: const PropertyStrip()),
      body: RefreshIndicator(
        onRefresh: _load,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
                child: Row(
                  children: [
                    for (final (filter, label) in const [
                      (_Filter.all, 'All'),
                      (_Filter.occupied, 'Occupied'),
                      (_Filter.vacant, 'Vacant'),
                      (_Filter.owing, 'Owing'),
                    ]) ...[
                      ChoiceChip(
                        label: Text(label),
                        selected: _filter == filter,
                        onSelected: (_) => setState(() => _filter = filter),
                      ),
                      const SizedBox(width: 8),
                    ],
                  ],
                ),
              ),
            ),
            if (_error != null)
              SliverPadding(
                padding: const EdgeInsets.all(16),
                sliver: SliverToBoxAdapter(child: ErrorBox(_error!)),
              ),
            if (units == null && _loading)
              const SliverFillRemaining(
                child: Center(child: CircularProgressIndicator()),
              ),
            if (units != null && shown.isEmpty)
              SliverFillRemaining(
                child: Center(
                  child: Text(
                    'No units here.',
                    style: TextStyle(color: colors.inkSoft),
                  ),
                ),
              ),
            // Built only as they scroll into view, so a large property stays light.
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              sliver: SliverList.separated(
                itemCount: shown.length,
                separatorBuilder: (_, _) => const SizedBox(height: 8),
                itemBuilder: (context, index) => _UnitTile(shown[index]),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _UnitTile extends StatelessWidget {
  const _UnitTile(this.unit);

  final Unit unit;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final tenant = unit.tenant;
    final owes = (tenant?.balance ?? 0) > 0;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
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
                  const SizedBox(height: 2),
                  Text(
                    [unit.typeLabel, unit.floor, formatKes(unit.monthlyRent)]
                        .whereType<String>()
                        .where((part) => part.isNotEmpty)
                        .join(' · '),
                    style: TextStyle(color: colors.inkFaint, fontSize: 12),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    tenant == null ? 'No tenant' : tenant.fullName,
                    style: TextStyle(
                      color: tenant == null ? colors.inkFaint : colors.inkSoft,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                if (!unit.isOccupied)
                  const StatusChip('Vacant')
                else if (owes)
                  const StatusChip('Owing', tone: Tone.danger)
                else
                  const StatusChip('Paid up', tone: Tone.success),
                if (owes) ...[
                  const SizedBox(height: 6),
                  Text(
                    formatKes(tenant!.balance),
                    style: TextStyle(
                      color: colors.danger,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}
