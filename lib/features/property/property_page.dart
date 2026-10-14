import 'package:flutter/material.dart';

import '../../core/app_theme.dart';
import '../../models/caretaker_property.dart';
import '../units/units_page.dart';
import '../water/water_readings_page.dart';

/// One property: the work the caretaker can do in it.
class PropertyPage extends StatelessWidget {
  const PropertyPage({super.key, required this.property});

  final CaretakerProperty property;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);

    void open(Widget page) {
      Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => page));
    }

    return Scaffold(
      appBar: AppBar(title: Text(property.name)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (property.location.isNotEmpty) ...[
            Text(
              property.location,
              style: TextStyle(color: colors.inkSoft, fontSize: 13),
            ),
            const SizedBox(height: 14),
          ],
          if (property.readsMeters) ...[
            _Section(
              icon: Icons.water_drop_outlined,
              title: 'Water readings',
              subtitle: 'Record this month’s meter readings',
              onTap: () => open(WaterReadingsPage(property: property)),
            ),
            const SizedBox(height: 10),
          ],
          _Section(
            icon: Icons.door_front_door_outlined,
            title: 'Units',
            subtitle:
                '${property.totalUnits} units · ${property.occupiedUnits} occupied',
            onTap: () => open(UnitsPage(property: property)),
          ),
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);

    return Card(
      clipBehavior: Clip.antiAlias,
      child: ListTile(
        onTap: onTap,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: colors.accentSoft,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: colors.accentInk, size: 21),
        ),
        title: Text(
          title,
          style: TextStyle(color: colors.ink, fontWeight: FontWeight.w700),
        ),
        subtitle: Text(
          subtitle,
          style: TextStyle(color: colors.inkSoft, fontSize: 13),
        ),
        trailing: Icon(Icons.chevron_right, color: colors.inkFaint),
      ),
    );
  }
}
