import 'package:flutter/material.dart';

import '../../widgets/property_gate.dart';
import 'units_page.dart';

/// The Units tab, for the property being worked on.
class UnitsTab extends StatelessWidget {
  const UnitsTab({super.key});

  @override
  Widget build(BuildContext context) {
    return PropertyGate(
      // A new key when the property changes, so its units load afresh.
      builder: (context, property) =>
          UnitsPage(key: ValueKey(property.id), property: property),
    );
  }
}
