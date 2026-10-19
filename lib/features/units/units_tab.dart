import 'package:flutter/material.dart';

import '../../widgets/property_gate.dart';
import 'units_page.dart';

/// Units, opened from Home or More, for the property being worked on.
class UnitsTab extends StatelessWidget {
  const UnitsTab({super.key});

  @override
  Widget build(BuildContext context) {
    return PropertyGate(
      builder: (context, property) =>
          UnitsPage(key: ValueKey(property.id), property: property),
    );
  }
}
