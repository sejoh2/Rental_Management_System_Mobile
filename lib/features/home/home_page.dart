import 'package:flutter/material.dart';

import '../../core/api_client.dart';
import '../../core/app_scope.dart';
import '../../core/app_theme.dart';
import '../../models/caretaker_property.dart';
import '../../widgets/message_box.dart';
import '../property/property_page.dart';

/// Where the caretaker lands: the properties they look after.
class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  List<CaretakerProperty>? _properties;
  String? _error;
  bool _loading = true;
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    // Loaded once, when the screen first has access to the server connection.
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
      final response = await AppScope.of(
        context,
      ).api.get('/api/caretaker/properties');
      final rows = response['data'] as List? ?? const [];

      if (!mounted) return;

      setState(() {
        _properties = [
          for (final row in rows) CaretakerProperty.fromJson(row as Json),
        ];
      });
    } on ApiException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _confirmSignOut() async {
    final auth = AppScope.of(context).auth;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Sign out?'),
        content: const Text('You will need a new SMS code to sign in again.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Stay signed in'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Sign out'),
          ),
        ],
      ),
    );

    if (confirmed == true) await auth.signOut();
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final user = AppScope.of(context).auth.user;
    final properties = _properties;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          user == null || user.firstName.isEmpty
              ? 'My properties'
              : 'Hello, ${user.firstName}',
        ),
        actions: [
          IconButton(
            onPressed: _confirmSignOut,
            tooltip: 'Sign out',
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          children: [
            if (_error != null) ...[
              ErrorBox(_error!),
              const SizedBox(height: 12),
              OutlinedButton(
                onPressed: _loading ? null : _load,
                child: const Text('Try again'),
              ),
              const SizedBox(height: 12),
            ],
            if (properties == null && _loading)
              const Padding(
                padding: EdgeInsets.only(top: 80),
                child: Center(child: CircularProgressIndicator()),
              ),
            if (properties != null && properties.isEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 60),
                child: Text(
                  'You are not assigned to any property yet. Ask the owner to add you to one, then pull down to refresh.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: colors.inkSoft,
                    fontSize: 14,
                    height: 1.5,
                  ),
                ),
              ),
            if (properties != null)
              for (final property in properties) ...[
                _PropertyCard(
                  property,
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => PropertyPage(property: property),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
              ],
          ],
        ),
      ),
    );
  }
}

class _PropertyCard extends StatelessWidget {
  const _PropertyCard(this.property, {required this.onTap});

  final CaretakerProperty property;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);

    final allowed = [
      'Readings, repairs, expenses',
      if (property.canManageTenants) 'Add and edit tenants' else 'View tenants',
      if (property.canRecordPayments) 'Record payments',
    ];

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                property.name,
                style: TextStyle(
                  color: colors.ink,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
              if (property.location.isNotEmpty) ...[
                const SizedBox(height: 2),
                Text(
                  property.location,
                  style: TextStyle(color: colors.inkFaint, fontSize: 13),
                ),
              ],
              const SizedBox(height: 14),
              Row(
                children: [
                  _Figure(label: 'Units', value: '${property.totalUnits}'),
                  _Figure(
                    label: 'Occupied',
                    value: '${property.occupiedUnits}',
                  ),
                  _Figure(label: 'Vacant', value: '${property.vacantUnits}'),
                ],
              ),
              const SizedBox(height: 14),
              Text(
                'You can: ${allowed.join(' · ')}',
                style: TextStyle(
                  color: colors.inkSoft,
                  fontSize: 12,
                  height: 1.5,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Figure extends StatelessWidget {
  const _Figure({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);

    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: TextStyle(
              color: colors.ink,
              fontSize: 20,
              fontWeight: FontWeight.w700,
            ),
          ),
          Text(label, style: TextStyle(color: colors.inkFaint, fontSize: 12)),
        ],
      ),
    );
  }
}
