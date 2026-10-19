import 'package:flutter/material.dart';

import '../../widgets/message_box.dart';
import '../../widgets/property_gate.dart';
import 'water_readings_page.dart';

/// The Water tab: the readings of the property being worked on.
class WaterTab extends StatelessWidget {
  const WaterTab({super.key});

  @override
  Widget build(BuildContext context) {
    return PropertyGate(
      builder: (context, property) {
        if (!property.readsMeters) {
          return Scaffold(
            appBar: AppBar(
              title: const Text('Water readings'),
              bottom: const PropertyStrip(),
            ),
            body: const EmptyView(
              icon: Icons.water_drop_outlined,
              title: 'No meter readings here',
              message:
                  'This property does not bill water by meter, so there is nothing to read. '
                  'If that is wrong, ask the owner to change its water billing.',
            ),
          );
        }

        // A new key when the property changes, so its readings load afresh.
        return WaterReadingsPage(
          key: ValueKey(property.id),
          property: property,
        );
      },
    );
  }
}
