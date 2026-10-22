import 'package:flutter/material.dart';

import '../../core/api_client.dart';
import '../../core/app_scope.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text.dart';
import '../../core/theme/app_theme.dart';
import '../../data/repair_repository.dart';
import '../../models/caretaker_property.dart';
import '../../models/repair.dart';
import '../../utils/format.dart';
import '../../widgets/cards.dart';
import '../../widgets/message_box.dart';
import '../../widgets/notices_bell.dart';
import '../../widgets/property_gate.dart';
import '../../widgets/status_chip.dart';
import 'repair_form_page.dart';
import 'repair_page.dart';

/// The Maintenance tab, for the property being worked on.
class RepairsTab extends StatelessWidget {
  const RepairsTab({super.key});

  @override
  Widget build(BuildContext context) {
    return PropertyGate(
      builder: (context, property) => property.canManageMaintenance
          ? RepairsPage(key: ValueKey(property.id), property: property)
          : LockedTab(
              title: 'Maintenance',
              what: 'maintenance',
              property: property,
            ),
    );
  }
}

enum _Filter { open, mine, done, all }

StatusChip repairStatusChip(Repair repair) => switch (repair.status) {
  'in_progress' => const StatusChip('In progress', tone: Tone.info),
  'resolved' => const StatusChip('Resolved', tone: Tone.success),
  'cancelled' => const StatusChip('Cancelled'),
  _ => const StatusChip('Reported', tone: Tone.warning),
};

StatusChip? repairPriorityChip(Repair repair) => switch (repair.priority) {
  'urgent' => const StatusChip('Urgent', tone: Tone.danger),
  'high' => const StatusChip('High', tone: Tone.accent),
  _ => null,
};

class RepairsPage extends StatefulWidget {
  const RepairsPage({super.key, required this.property});

  final CaretakerProperty property;

  @override
  State<RepairsPage> createState() => _RepairsPageState();
}

class _RepairsPageState extends State<RepairsPage> {
  List<Repair>? _repairs;
  String? _error;
  bool _started = false;
  _Filter _filter = _Filter.open;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    if (!_started) {
      _started = true;
      _load();
    }
  }

  Future<void> _load() async {
    setState(() => _error = null);

    try {
      final repairs = await RepairRepository(
        AppScope.read(context).api,
      ).list(widget.property.id);

      if (mounted) setState(() => _repairs = repairs);
    } on ApiException catch (failure) {
      if (mounted) setState(() => _error = failure.message);
    }
  }

  Future<void> _open(Widget page) async {
    await Navigator.of(
      context,
    ).push<bool>(MaterialPageRoute(builder: (_) => page));

    // Always: opening a repair also clears its "new" mark.
    _load();
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final me = AppScope.of(context).auth.user?.id;
    final repairs = _repairs;
    final shown = [
      for (final repair in repairs ?? const <Repair>[])
        if (switch (_filter) {
          _Filter.open => repair.isOpen,
          _Filter.mine => repair.isOpen && repair.isFor(me),
          _Filter.done => !repair.isOpen,
          _Filter.all => true,
        })
          repair,
    ];
    final openCount = repairs?.where((repair) => repair.isOpen).length ?? 0;
    final mineCount =
        repairs?.where((repair) => repair.isOpen && repair.isFor(me)).length ??
        0;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Maintenance'),
        actions: const [NoticesBell()],
        bottom: const PropertyStrip(),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _open(RepairFormPage(property: widget.property)),
        backgroundColor: colors.accent,
        foregroundColor: AppColors.onAccent,
        icon: const Icon(Icons.add),
        label: const Text('Report issue'),
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.fromLTRB(
                  AppSpace.page,
                  AppSpace.md,
                  AppSpace.page,
                  AppSpace.xs,
                ),
                child: Row(
                  children: [
                    for (final (filter, label) in [
                      (
                        _Filter.open,
                        repairs == null ? 'Open' : 'Open ($openCount)',
                      ),
                      (
                        _Filter.mine,
                        repairs == null ? 'Mine' : 'Mine ($mineCount)',
                      ),
                      (_Filter.done, 'Resolved or cancelled'),
                      (_Filter.all, 'All'),
                    ]) ...[
                      ChoiceChip(
                        label: Text(label),
                        selected: _filter == filter,
                        onSelected: (_) => setState(() => _filter = filter),
                      ),
                      const SizedBox(width: AppSpace.sm),
                    ],
                  ],
                ),
              ),
            ),
            if (_error != null)
              SliverFillRemaining(
                child: ErrorView(message: _error!, onRetry: _load),
              )
            else if (repairs == null)
              const SliverFillRemaining(child: LoadingView())
            else if (shown.isEmpty)
              SliverFillRemaining(
                child: EmptyView(
                  icon: Icons.build_outlined,
                  title: _filter == _Filter.open
                      ? 'Nothing waiting'
                      : 'Nothing here',
                  message: switch (_filter) {
                    _Filter.open =>
                      'No open maintenance requests. Report an issue with the button below when something breaks.',
                    _Filter.mine =>
                      'No open request is assigned to you. Open a request and tap "I’ll handle it" to take it on.',
                    _ => 'No maintenance requests in this list.',
                  },
                ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpace.page,
                  AppSpace.sm,
                  AppSpace.page,
                  96,
                ),
                sliver: SliverList.separated(
                  itemCount: shown.length,
                  separatorBuilder: (_, _) =>
                      const SizedBox(height: AppSpace.sm),
                  itemBuilder: (context, index) {
                    final repair = shown[index];
                    final priority = repairPriorityChip(repair);

                    return AppCard(
                      onTap: () => _open(
                        RepairPage(property: widget.property, repair: repair),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  repair.title,
                                  style: AppText.label.copyWith(
                                    color: colors.ink,
                                  ),
                                ),
                              ),
                              if (repair.caretakerNotice != null) ...[
                                const StatusChip('New', tone: Tone.accent),
                                const SizedBox(width: 6),
                              ],
                              repairStatusChip(repair),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            [
                              repair.unitNumber == null
                                  ? 'Common area'
                                  : 'House ${repair.unitNumber}',
                              RepairLabels.categories[repair.category] ??
                                  repair.category,
                              if (repair.createdAt != null)
                                formatDay(repair.createdAt!),
                            ].join(' · '),
                            style: AppText.small.copyWith(
                              color: colors.inkSoft,
                            ),
                          ),
                          if (priority != null ||
                              repair.isFor(me) ||
                              repair.actualCost != null) ...[
                            const SizedBox(height: AppSpace.sm),
                            Row(
                              children: [
                                ?priority,
                                if (repair.isFor(me) && repair.isOpen) ...[
                                  if (priority != null)
                                    const SizedBox(width: 6),
                                  const StatusChip('Yours', tone: Tone.info),
                                ],
                                const Spacer(),
                                if (repair.actualCost != null)
                                  Text(
                                    formatKes(repair.actualCost!),
                                    style: AppText.amount.copyWith(
                                      color: colors.ink,
                                      fontSize: 13.5,
                                    ),
                                  ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}
