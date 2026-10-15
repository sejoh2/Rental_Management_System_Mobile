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
import '../../widgets/property_gate.dart';
import '../../widgets/status_chip.dart';
import 'home_summary.dart';

/// Where the caretaker lands: the property being worked on, how this month is
/// going, the quick actions and what needs attention.
class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return PropertyGate(
      // A new key when the property changes, so its figures load afresh.
      builder: (context, property) =>
          _HomeView(key: ValueKey(property.id), property: property),
    );
  }
}

class _HomeView extends StatefulWidget {
  const _HomeView({super.key, required this.property});

  final CaretakerProperty property;

  @override
  State<_HomeView> createState() => _HomeViewState();
}

class _HomeViewState extends State<_HomeView> {
  final DateTime _month = monthOf(DateTime.now());

  HomeSummary? _summary;
  String? _error;
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

    setState(() => _error = null);

    try {
      final water = WaterRepository(api);

      // All three at once: one wait instead of three. The first failure is the one reported.
      final results = await Future.wait<Object>([
        water.listUnits(property.id),
        property.readsMeters
            ? water.listReadings(property.id, billingPeriodOf(_month))
            : Future.value(const <WaterReading>[]),
        PropertyRepository(api).openRepairs(property.id),
      ]);

      final units = results[0] as List<Unit>;
      final readings = results[1] as List<WaterReading>;
      final openRepairs = results[2] as int;

      if (!mounted) return;

      setState(() {
        _summary = HomeSummary.from(
          units: units,
          readings: readings,
          openRepairs: openRepairs,
        );
      });
    } on ApiException catch (failure) {
      if (mounted) setState(() => _error = failure.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final services = AppScope.of(context);
    final colors = AppColors.of(context);
    final user = services.auth.user;
    final property = widget.property;
    final several = (services.properties.properties?.length ?? 0) > 1;
    final summary = _summary;

    return Scaffold(
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async {
            await Future.wait([_load(), services.properties.load()]);
          },
          child: ListView(
            padding: const EdgeInsets.fromLTRB(
              AppSpace.page,
              AppSpace.lg,
              AppSpace.page,
              AppSpace.xxl,
            ),
            children: [
              Text(
                '${_greeting()}${user == null || user.firstName.isEmpty ? '' : ', ${user.firstName}'}',
                style: AppText.small.copyWith(
                  color: colors.inkSoft,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 6),
              _PropertyHeader(property: property, canSwitch: several),
              const SizedBox(height: AppSpace.sm),
              _Permissions(property: property),
              SectionLabel(monthLabel(_month)),
              if (_error != null)
                ErrorView(message: _error!, onRetry: _load)
              else if (summary == null)
                const AppCard(child: SizedBox(height: 92, child: LoadingView()))
              else
                _MonthCard(property: property, summary: summary),
              const SectionLabel('Quick actions'),
              AppCard(
                padding: EdgeInsets.zero,
                child: Column(
                  children: [
                    if (property.readsMeters) ...[
                      NavRow(
                        icon: Icons.water_drop_outlined,
                        title: 'Record a meter reading',
                        subtitle: summary == null || summary.unitsToRead == 0
                            ? 'Water readings for this month'
                            : summary.unitsLeftToRead == 0
                            ? 'All ${summary.unitsToRead} houses read this month'
                            : '${summary.unitsLeftToRead} of ${summary.unitsToRead} houses still to read',
                        onTap: () => context.go(Routes.water),
                      ),
                      const Divider(height: 1),
                    ],
                    NavRow(
                      icon: Icons.build_outlined,
                      title: 'Report a repair',
                      subtitle: 'Something broken in a house or shared area',
                      onTap: () => context.go(Routes.repairs),
                    ),
                    const Divider(height: 1),
                    NavRow(
                      icon: Icons.receipt_long_outlined,
                      title: 'Add an expense',
                      subtitle: 'With a photo of the receipt',
                      onTap: () => context.go(Routes.expenses),
                    ),
                    const Divider(height: 1),
                    NavRow(
                      icon: Icons.people_outline,
                      title: property.canRecordPayments
                          ? 'Tenants and payments'
                          : 'Tenants',
                      subtitle: property.canRecordPayments
                          ? 'Who owes, and recording money handed to you'
                          : 'Who lives where, and who owes',
                      onTap: () => context.go(Routes.tenants),
                    ),
                  ],
                ),
              ),
              if (summary != null &&
                  (summary.flaggedReadings > 0 || summary.openRepairs > 0)) ...[
                const SectionLabel('Needs attention'),
                AppCard(
                  padding: EdgeInsets.zero,
                  child: Column(
                    children: [
                      if (summary.flaggedReadings > 0)
                        NavRow(
                          icon: Icons.warning_amber_rounded,
                          title:
                              '${summary.flaggedReadings} ${summary.flaggedReadings == 1 ? 'reading needs' : 'readings need'} fixing',
                          subtitle:
                              'Lower than the reading before, so not billed yet',
                          trailing: const StatusChip(
                            'Flagged',
                            tone: Tone.danger,
                          ),
                          onTap: () => context.go(Routes.water),
                        ),
                      if (summary.flaggedReadings > 0 &&
                          summary.openRepairs > 0)
                        const Divider(height: 1),
                      if (summary.openRepairs > 0)
                        NavRow(
                          icon: Icons.build_circle_outlined,
                          title:
                              '${summary.openRepairs} open ${summary.openRepairs == 1 ? 'repair' : 'repairs'}',
                          subtitle: 'Reported or in progress',
                          trailing: const StatusChip(
                            'Open',
                            tone: Tone.warning,
                          ),
                          onTap: () => context.go(Routes.repairs),
                        ),
                    ],
                  ),
                ),
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

class _PropertyHeader extends StatelessWidget {
  const _PropertyHeader({required this.property, required this.canSwitch});

  final CaretakerProperty property;
  final bool canSwitch;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);

    final title = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          property.name,
          style: AppText.headline.copyWith(color: colors.ink),
        ),
        if (property.location.isNotEmpty) ...[
          const SizedBox(height: 2),
          Text(
            property.location,
            style: AppText.small.copyWith(color: colors.inkFaint, fontSize: 13),
          ),
        ],
      ],
    );

    if (!canSwitch) return title;

    return InkWell(
      onTap: () => showPropertyPicker(context),
      borderRadius: BorderRadius.circular(AppSpace.controlRadius),
      child: Row(
        children: [
          Expanded(child: title),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
            decoration: BoxDecoration(
              border: Border.all(color: colors.line),
              borderRadius: BorderRadius.circular(AppSpace.controlRadius),
              color: colors.surface,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Switch',
                  style: AppText.small.copyWith(
                    color: colors.ink,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(width: 4),
                Icon(Icons.unfold_more, size: 16, color: colors.inkSoft),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// What this caretaker may do here, set by the owner.
class _Permissions extends StatelessWidget {
  const _Permissions({required this.property});

  final CaretakerProperty property;

  @override
  Widget build(BuildContext context) {
    return Wrap(
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
    );
  }
}

class _MonthCard extends StatelessWidget {
  const _MonthCard({required this.property, required this.summary});

  final CaretakerProperty property;
  final HomeSummary summary;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final allRead = summary.unitsToRead > 0 && summary.unitsLeftToRead == 0;

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (property.readsMeters)
                Expanded(
                  child: StatTile(
                    label: 'Readings done',
                    value: '${summary.unitsRead}/${summary.unitsToRead}',
                    tone: allRead ? colors.success : null,
                  ),
                ),
              Expanded(
                child: StatTile(
                  label: 'Open repairs',
                  value: '${summary.openRepairs}',
                  tone: summary.openRepairs > 0 ? colors.warning : null,
                ),
              ),
              Expanded(
                child: StatTile(
                  label: 'Occupied',
                  value: '${summary.occupiedUnits}/${summary.totalUnits}',
                ),
              ),
            ],
          ),
          if (property.readsMeters && summary.unitsToRead > 0) ...[
            const SizedBox(height: AppSpace.lg),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: summary.unitsRead / summary.unitsToRead,
                minHeight: 6,
                backgroundColor: colors.lineSoft,
                color: allRead ? colors.success : colors.accent,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
