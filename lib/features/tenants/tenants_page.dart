import 'package:flutter/material.dart';

import '../../core/api_client.dart';
import '../../core/app_scope.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text.dart';
import '../../core/theme/app_theme.dart';
import '../../data/tenant_repository.dart';
import '../../models/caretaker_property.dart';
import '../../models/tenant.dart';
import '../../utils/format.dart';
import '../../widgets/cards.dart';
import '../../widgets/message_box.dart';
import '../../widgets/property_gate.dart';
import '../../widgets/status_chip.dart';
import 'tenant_form_page.dart';
import 'tenant_page.dart';

/// The Tenants tab, for the property being worked on.
class TenantsTab extends StatelessWidget {
  const TenantsTab({super.key});

  @override
  Widget build(BuildContext context) {
    return PropertyGate(
      builder: (context, property) =>
          TenantsPage(key: ValueKey(property.id), property: property),
    );
  }
}

enum _Filter { current, owing, movedOut, all }

/// Everyone renting in the property: search by name, house or phone.
class TenantsPage extends StatefulWidget {
  const TenantsPage({super.key, required this.property});

  final CaretakerProperty property;

  @override
  State<TenantsPage> createState() => _TenantsPageState();
}

class _TenantsPageState extends State<TenantsPage> {
  final _search = TextEditingController();

  List<Tenant>? _tenants;
  String? _error;
  bool _started = false;
  _Filter _filter = _Filter.current;

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
    setState(() => _error = null);

    try {
      final tenants = await TenantRepository(
        AppScope.read(context).api,
      ).list(widget.property.id);

      tenants.sort((a, b) => a.unitNumber.compareTo(b.unitNumber));

      if (mounted) setState(() => _tenants = tenants);
    } on ApiException catch (failure) {
      if (mounted) setState(() => _error = failure.message);
    }
  }

  bool _matches(Tenant tenant) {
    final passes = switch (_filter) {
      _Filter.current => tenant.isCurrent,
      _Filter.owing => tenant.owes,
      _Filter.movedOut => tenant.status == 'moved_out',
      _Filter.all => true,
    };

    if (!passes) return false;

    final query = _search.text.trim().toLowerCase();

    if (query.isEmpty) return true;

    return tenant.fullName.toLowerCase().contains(query) ||
        tenant.unitNumber.toLowerCase().contains(query) ||
        tenant.phone.replaceAll(' ', '').contains(query.replaceAll(' ', ''));
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
    final tenants = _tenants;
    final shown = tenants?.where(_matches).toList() ?? const <Tenant>[];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Tenants'),
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
        onRefresh: _load,
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
                    hintText: 'Search name, house or phone',
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
                    for (final (filter, label) in const [
                      (_Filter.current, 'Current'),
                      (_Filter.owing, 'Owing'),
                      (_Filter.movedOut, 'Moved out'),
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
            else if (tenants == null)
              const SliverFillRemaining(child: LoadingView())
            else if (shown.isEmpty)
              SliverFillRemaining(
                child: EmptyView(
                  icon: Icons.people_outline,
                  title: tenants.isEmpty ? 'No tenants yet' : 'Nobody here',
                  message: tenants.isEmpty
                      ? (widget.property.canManageTenants
                            ? 'Add the first tenant with the button below.'
                            : 'The owner has not added any tenants yet.')
                      : 'No tenant matches this search or filter.',
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
                // Built only as they scroll into view, so a large property stays light.
                sliver: SliverList.separated(
                  itemCount: shown.length,
                  separatorBuilder: (_, _) =>
                      const SizedBox(height: AppSpace.sm),
                  itemBuilder: (context, index) {
                    final tenant = shown[index];

                    return _TenantRow(
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
              ),
          ],
        ),
      ),
    );
  }
}

class _TenantRow extends StatelessWidget {
  const _TenantRow({required this.tenant, required this.onTap});

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
          CircleAvatar(
            radius: 20,
            backgroundColor: colors.lineSoft,
            child: Text(
              tenant.unitNumber,
              style: AppText.small.copyWith(
                color: colors.ink,
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
                  tenant.fullName,
                  style: AppText.label.copyWith(color: colors.ink),
                ),
                const SizedBox(height: 2),
                Text(
                  tenant.phone,
                  style: AppText.small.copyWith(color: colors.inkSoft),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              if (tenant.owes)
                Text(
                  formatKes(tenant.balance),
                  style: AppText.amount.copyWith(
                    color: colors.danger,
                    fontSize: 13.5,
                  ),
                )
              else if (tenant.isCurrent)
                const StatusChip('Paid up', tone: Tone.success),
              if (!tenant.isCurrent || tenant.status == 'notice_given') ...[
                const SizedBox(height: 4),
                StatusChip(
                  tenant.statusLabel,
                  tone: tenant.status == 'notice_given'
                      ? Tone.warning
                      : Tone.neutral,
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}
