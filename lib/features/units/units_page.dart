import 'package:flutter/material.dart';

import '../../core/api_client.dart';
import '../../core/app_scope.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text.dart';
import '../../core/theme/app_theme.dart';
import '../../data/tenant_repository.dart';
import '../../data/water_repository.dart';
import '../../models/caretaker_property.dart';
import '../../models/tenant.dart';
import '../../models/unit.dart';
import '../../utils/format.dart';
import '../../widgets/cards.dart';
import '../../widgets/message_box.dart';
import '../../widgets/notices_bell.dart';
import '../../widgets/property_gate.dart';
import '../../widgets/status_chip.dart';
import '../tenants/tenant_form_page.dart';
import '../tenants/tenant_page.dart';
import 'unit_page.dart';

enum UnitFilter { all, occupied, vacant, owing, former }

/// Which units a filter and a search show. Kept apart from the screen so
/// it can be tested on its own. The search matches the house, the tenant's
/// name or the unit type.
List<Unit> unitsShown(List<Unit> units, UnitFilter filter, String search) {
  final query = search.trim().toLowerCase();

  return [
    for (final unit in units)
      if (switch (filter) {
            UnitFilter.all || UnitFilter.former => true,
            UnitFilter.occupied => unit.isOccupied,
            UnitFilter.vacant => !unit.isOccupied,
            UnitFilter.owing => (unit.tenant?.balance ?? 0) > 0,
          } &&
          (query.isEmpty ||
              unit.unitNumber.toLowerCase().contains(query) ||
              (unit.tenant?.fullName.toLowerCase().contains(query) ?? false) ||
              unit.typeLabel.toLowerCase().contains(query)))
        unit,
  ];
}

/// The units of the property, who lives in each and what they owe. A unit
/// opens its details and its tenant. Tenants who have moved out are under
/// "Former tenants".
class UnitsPage extends StatefulWidget {
  const UnitsPage({super.key, required this.property});

  final CaretakerProperty property;

  @override
  State<UnitsPage> createState() => _UnitsPageState();
}

class _UnitsPageState extends State<UnitsPage> {
  final _search = TextEditingController();

  List<Unit>? _units;
  List<Tenant>? _former;
  String? _error;
  bool _started = false;
  UnitFilter _filter = UnitFilter.all;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    if (!_started) {
      _started = true;
      _load();
    }
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final api = AppScope.read(context).api;

    setState(() => _error = null);

    try {
      final results = await Future.wait<Object>([
        WaterRepository(api).listUnits(widget.property.id),
        TenantRepository(api).list(widget.property.id),
      ]);

      if (!mounted) return;

      setState(() {
        // Units the owner took out of use are not shown to the caretaker.
        _units =
            (results[0] as List<Unit>)
                .where((unit) => unit.status != 'inactive')
                .toList()
              ..sort((a, b) => a.unitNumber.compareTo(b.unitNumber));
        _former =
            (results[1] as List<Tenant>)
                .where((tenant) => !tenant.isCurrent)
                .toList()
              ..sort(
                (a, b) => (b.moveOutDate ?? DateTime(2000)).compareTo(
                  a.moveOutDate ?? DateTime(2000),
                ),
              );
      });
    } on ApiException catch (failure) {
      if (mounted) setState(() => _error = failure.message);
    }
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
    final former = _former;
    final query = _search.text.trim().toLowerCase();
    final shown = units == null
        ? const <Unit>[]
        : unitsShown(units, _filter, _search.text);
    final formerShown = [
      for (final tenant in former ?? const <Tenant>[])
        if (query.isEmpty ||
            tenant.fullName.toLowerCase().contains(query) ||
            tenant.unitNumber.toLowerCase().contains(query))
          tenant,
    ];
    final owing =
        units?.where((unit) => (unit.tenant?.balance ?? 0) > 0).length ?? 0;
    final vacant = units?.where((unit) => !unit.isOccupied).length ?? 0;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Units'),
        actions: const [NoticesBell()],
        bottom: const PropertyStrip(),
      ),
      floatingActionButton: widget.property.canManageTenants
          ? FloatingActionButton.extended(
              onPressed: () => _open(TenantFormPage(property: widget.property)),
              backgroundColor: colors.accent,
              foregroundColor: AppColors.onAccent,
              icon: const Icon(Icons.person_add_alt_1_outlined),
              label: const Text('Add tenant'),
            )
          : null,
      body: RefreshIndicator(
        // Also looks again for properties the owner has just added.
        onRefresh: () => Future.wait([
          _load(),
          AppScope.read(context).properties.load(),
        ]),
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpace.page,
                  AppSpace.md,
                  AppSpace.page,
                  0,
                ),
                child: TextField(
                  controller: _search,
                  textInputAction: TextInputAction.search,
                  decoration: InputDecoration(
                    hintText: 'Search house or tenant',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: _search.text.isEmpty
                        ? null
                        : IconButton(
                            icon: const Icon(Icons.close),
                            onPressed: () => setState(_search.clear),
                          ),
                  ),
                  onChanged: (_) => setState(() {}),
                ),
              ),
            ),
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
                      (UnitFilter.all, 'All'),
                      (UnitFilter.occupied, 'Occupied'),
                      (UnitFilter.vacant, units == null ? 'Vacant' : 'Vacant ($vacant)'),
                      (UnitFilter.owing, units == null ? 'Owing' : 'Owing ($owing)'),
                      (UnitFilter.former, 'Former tenants'),
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
            else if (units == null)
              const SliverFillRemaining(child: LoadingView())
            else if (_filter == UnitFilter.former)
              formerShown.isEmpty
                  ? const SliverFillRemaining(
                      child: EmptyView(
                        icon: Icons.history,
                        title: 'No former tenants',
                        message:
                            'Tenants the owner has moved out are listed here, with their last statement.',
                      ),
                    )
                  : SliverPadding(
                      padding: const EdgeInsets.fromLTRB(
                        AppSpace.page,
                        AppSpace.sm,
                        AppSpace.page,
                        96,
                      ),
                      sliver: SliverList.separated(
                        itemCount: formerShown.length,
                        separatorBuilder: (_, _) =>
                            const SizedBox(height: AppSpace.sm),
                        itemBuilder: (context, index) {
                          final tenant = formerShown[index];

                          return _FormerTile(
                            tenant: tenant,
                            onTap: () => _open(
                              TenantPage(
                                property: widget.property,
                                tenantId: tenant.id,
                              ),
                            ),
                          );
                        },
                      ),
                    )
            else if (shown.isEmpty)
              SliverFillRemaining(
                child: EmptyView(
                  icon: Icons.door_front_door_outlined,
                  title: units.isEmpty ? 'No units yet' : 'Nothing here',
                  message: units.isEmpty
                      ? 'The owner adds the units on the web.'
                      : 'No unit matches this search or filter.',
                ),
              )
            else
              // Built only as they scroll into view, so a large property stays light.
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
                    final unit = shown[index];

                    return _UnitTile(
                      unit: unit,
                      onTap: () => _open(
                        UnitPage(property: widget.property, unit: unit),
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

class _UnitTile extends StatelessWidget {
  const _UnitTile({required this.unit, required this.onTap});

  final Unit unit;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final tenant = unit.tenant;
    final owes = (tenant?.balance ?? 0) > 0;

    return AppCard(
      onTap: onTap,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpace.lg,
        vertical: 14,
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 21,
            backgroundColor: unit.isOccupied
                ? colors.accentSoft
                : colors.lineSoft,
            child: Text(
              unit.unitNumber,
              maxLines: 1,
              style: AppText.small.copyWith(
                color: unit.isOccupied ? colors.accentInk : colors.inkSoft,
                fontWeight: FontWeight.w800,
                fontSize: 11.5,
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  tenant == null ? 'Vacant' : tenant.fullName,
                  style: AppText.label.copyWith(
                    color: tenant == null ? colors.inkSoft : colors.ink,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  [
                    'House ${unit.unitNumber}',
                    unit.typeLabel,
                    formatKes(unit.monthlyRent),
                  ].where((part) => part.isNotEmpty).join(' · '),
                  style: AppText.small.copyWith(color: colors.inkFaint),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpace.sm),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              if (!unit.isOccupied)
                const StatusChip('Vacant')
              else if (owes)
                Text(
                  formatKes(tenant!.balance),
                  style: AppText.amount.copyWith(
                    color: colors.danger,
                    fontSize: 13.5,
                  ),
                )
              else
                const StatusChip('Paid up', tone: Tone.success),
              if (tenant?.status == 'notice_given') ...[
                const SizedBox(height: 4),
                const StatusChip('Notice given', tone: Tone.warning),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _FormerTile extends StatelessWidget {
  const _FormerTile({required this.tenant, required this.onTap});

  final Tenant tenant;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);

    return AppCard(
      onTap: onTap,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpace.lg,
        vertical: 14,
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  tenant.fullName,
                  style: AppText.label.copyWith(color: colors.ink),
                ),
                const SizedBox(height: 2),
                Text(
                  [
                    'House ${tenant.unitNumber}',
                    if (tenant.moveOutDate != null)
                      'moved out ${formatDay(tenant.moveOutDate!)}',
                  ].join(' · '),
                  style: AppText.small.copyWith(color: colors.inkFaint),
                ),
              ],
            ),
          ),
          if (tenant.owes)
            Text(
              formatKes(tenant.balance),
              style: AppText.amount.copyWith(
                color: colors.danger,
                fontSize: 13.5,
              ),
            )
          else
            StatusChip(tenant.statusLabel),
        ],
      ),
    );
  }
}
