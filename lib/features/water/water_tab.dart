import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../widgets/message_box.dart';
import '../../widgets/notices_bell.dart';
import '../../widgets/property_gate.dart';
import '../expenses/electricity_page.dart';
import 'water_readings_page.dart';

/// The Water & Electricity tab: the meter readings and the electricity
/// amounts typed each month, for the property being worked on.
class WaterTab extends StatelessWidget {
  const WaterTab({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);

    return PropertyGate(
      builder: (context, property) => DefaultTabController(
        // A new key when the property changes, so everything loads afresh.
        key: ValueKey(property.id),
        length: 2,
        child: Scaffold(
          appBar: AppBar(
            title: const Text('Water & Electricity'),
            actions: const [NoticesBell()],
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(40 + 46),
              child: Column(
                children: [
                  const PropertyStrip(),
                  TabBar(
                    labelColor: colors.accentInk,
                    indicatorColor: colors.accent,
                    unselectedLabelColor: colors.inkSoft,
                    tabs: const [
                      Tab(height: 46, text: 'Water readings'),
                      Tab(height: 46, text: 'Electricity'),
                    ],
                  ),
                ],
              ),
            ),
          ),
          body: TabBarView(
            children: [
              if (property.readsMeters)
                WaterReadingsPage(property: property)
              else
                const EmptyView(
                  icon: Icons.water_drop_outlined,
                  title: 'No meter readings here',
                  message:
                      'This property does not bill water by meter, so there is nothing to read. '
                      'If that is wrong, ask the owner to change its water billing.',
                ),
              ElectricityPage(property: property),
            ],
          ),
        ),
      ),
    );
  }
}
