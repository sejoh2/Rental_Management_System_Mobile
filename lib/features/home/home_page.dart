import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../app/routes.dart';
import '../../core/api_client.dart';
import '../../core/app_scope.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text.dart';
import '../../core/theme/app_theme.dart';
import '../../data/property_repository.dart';
import '../../data/water_repository.dart';
import '../../models/caretaker_property.dart';
import '../../models/unit.dart';
import '../../models/water_reading.dart';
import '../../utils/format.dart';
import '../../widgets/cards.dart';
import '../../widgets/message_box.dart';
import '../../widgets/notices_bell.dart';
import '../../widgets/status_chip.dart';
import 'home_summary.dart';

/// Home: the properties the caretaker looks after, each with what is left
/// to do this month. Choosing one opens its tabs. This is the one place to
/// switch property. With a single property there is nothing to choose, so
/// it opens straight away.
class HomePage extends StatelessWidget {
  const HomePage({super.key});

  void _choose(BuildContext context, CaretakerProperty property) {
    AppScope.read(context).properties.select(property);
    context.go(Routes.units);
  }

  @override
  Widget build(BuildContext context) {
    final services = AppScope.of(context);
    final colors = AppColors.of(context);
    final controller = services.properties;
    final list = controller.properties;
    final user = services.auth.user;

    if (list != null && list.length == 1) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (context.mounted) _choose(context, list.single);
      });
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Home'),
        actions: [
          const NoticesBell(),
          IconButton(
            tooltip: 'Profile',
            onPressed: () => context.go(Routes.profile),
            icon: CircleAvatar(
              radius: 15,
              backgroundColor: colors.accentSoft,
              child: Text(
                user == null || user.fullName.isEmpty
                    ? '?'
                    : user.fullName.characters.first.toUpperCase(),
                style: AppText.small.copyWith(
                  color: colors.accentInk,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: SafeArea(
        child: list == null
            ? (controller.error != null
                  ? ErrorView(
                      message: controller.error!,
                      onRetry: controller.load,
                    )
                  : const LoadingView())
            : list.isEmpty
            ? EmptyView(
                icon: Icons.home_work_outlined,
                title: 'No property yet',
                message:
                    'You are not assigned to any property yet. Ask the owner to add you, then check again.',
                actionLabel: 'Check again',
                onAction: controller.load,
              )
            : RefreshIndicator(
                onRefresh: controller.load,
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpace.page,
                    AppSpace.md,
                    AppSpace.page,
                    AppSpace.xxl,
                  ),
                  children: [
                    Text(
                      '${_greeting()}${user == null || user.firstName.isEmpty ? '' : ', ${user.firstName}'}',
                      style: AppText.headline.copyWith(color: colors.ink),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Choose the property to work on.',
                      style: AppText.small.copyWith(
                        color: colors.inkSoft,
                        fontSize: 14,
                      ),
                    ),
                    SectionLabel(monthLabel(DateTime.now())),
                    for (final property in list) ...[
                      _PropertyCard(
                        // A new key per property, so each loads its own figures.
                        key: ValueKey(property.id),
                        property: property,
                        current:
                            controller.hasChosen &&
                            controller.selected?.id == property.id,
                        onTap: () => _choose(context, property),
                      ),
                      const SizedBox(height: AppSpace.md),
                    ],
                  ],
                ),
              ),
      ),
    );
  }

  String _greeting() {
    final hour = DateTime.now().hour;

    if (hour < 12) return 'Good morning';
    if (hour < 17) return 'Good afternoon';

    return 'Good evening';
  }
}

/// One property: its name, occupancy, what the caretaker may do, and the
/// month's to-do (readings left, open repairs, readings to fix).
class _PropertyCard extends StatefulWidget {
  const _PropertyCard({
    super.key,
    required this.property,
    required this.current,
    required this.onTap,
  });

  final CaretakerProperty property;
  final bool current;
  final VoidCallback onTap;

  @override
  State<_PropertyCard> createState() => _PropertyCardState();
}

class _PropertyCardState extends State<_PropertyCard> {
  HomeSummary? _summary;
  bool _failed = false;
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    if (!_started) {
      _started = true;
      _load();
    }
  }

  Future<void> _load() async {
    final api = AppScope.read(context).api;
    final property = widget.property;
    final month = monthOf(DateTime.now());

    try {
      final water = WaterRepository(api);
      // All three at once: one wait instead of three.
      final results = await Future.wait<Object>([
        water.listUnits(property.id),
        property.readsMeters
            ? water.listReadings(property.id, billingPeriodOf(month))
            : Future.value(const <WaterReading>[]),
        PropertyRepository(api).openRepairs(property.id),
      ]);

      if (!mounted) return;

      setState(() {
        _summary = HomeSummary.from(
          units: results[0] as List<Unit>,
          readings: results[1] as List<WaterReading>,
          openRepairs: results[2] as int,
        );
      });
    } on ApiException {
      // The card still opens the property; only the to-do line is missing.
      if (mounted) setState(() => _failed = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final property = widget.property;
    final summary = _summary;

    final todo = summary == null
        ? null
        : [
            if (property.readsMeters && summary.unitsToRead > 0)
              summary.unitsLeftToRead == 0
                  ? 'All readings done'
                  : '${summary.unitsLeftToRead} ${summary.unitsLeftToRead == 1 ? 'reading' : 'readings'} left',
            if (summary.flaggedReadings > 0)
              '${summary.flaggedReadings} to fix',
            summary.openRepairs == 0
                ? 'No open maintenance'
                : '${summary.openRepairs} open ${summary.openRepairs == 1 ? 'request' : 'requests'}',
          ].join(' · ');

    return AppCard(
      onTap: widget.onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const IconBadge(icon: Icons.apartment_outlined),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      property.name,
                      style: AppText.title.copyWith(color: colors.ink),
                    ),
                    if (property.location.isNotEmpty)
                      Text(
                        property.location,
                        style: AppText.small.copyWith(color: colors.inkFaint),
                      ),
                  ],
                ),
              ),
              if (widget.current)
                const StatusChip('Last opened', tone: Tone.accent)
              else
                Icon(Icons.chevron_right, color: colors.inkFaint),
            ],
          ),
          const SizedBox(height: AppSpace.md),
          Text(
            '${property.occupiedUnits} of ${property.totalUnits} units occupied',
            style: AppText.small.copyWith(color: colors.inkSoft, fontSize: 13),
          ),
          const SizedBox(height: 4),
          Text(
            todo ??
                (_failed
                    ? 'Open to see this month’s work'
                    : 'Checking this month...'),
            style: AppText.label.copyWith(
              color:
                  summary != null &&
                      (summary.unitsLeftToRead > 0 ||
                          summary.flaggedReadings > 0 ||
                          summary.openRepairs > 0)
                  ? colors.warning
                  : colors.inkSoft,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: AppSpace.md),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              StatusChip(
                property.canManageTenants ? 'Adds tenants' : 'Views tenants',
                tone: Tone.info,
              ),
              if (property.canRecordPayments)
                const StatusChip('Records payments', tone: Tone.warning),
            ],
          ),
        ],
      ),
    );
  }
}
