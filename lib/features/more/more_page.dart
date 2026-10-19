import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../app/routes.dart';
import '../../core/app_scope.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text.dart';
import '../../core/theme/app_theme.dart';
import '../../widgets/cards.dart';
import '../../widgets/property_gate.dart';

/// Everything that is not a tab of its own: the property's units, expenses
/// and electricity bills, and settings. The property is switched at the top.
class MorePage extends StatelessWidget {
  const MorePage({super.key});

  @override
  Widget build(BuildContext context) {
    final services = AppScope.of(context);
    final colors = AppColors.of(context);
    final user = services.auth.user;
    final property = services.properties.selected;

    return Scaffold(
      appBar: AppBar(title: const Text('More'), bottom: const PropertyStrip()),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppSpace.page,
          AppSpace.sm,
          AppSpace.page,
          AppSpace.xxl,
        ),
        children: [
          if (user != null) ...[
            const SectionLabel('Signed in as'),
            AppCard(
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 22,
                    backgroundColor: colors.accentSoft,
                    child: Text(
                      user.fullName.isEmpty
                          ? '?'
                          : user.fullName.characters.first.toUpperCase(),
                      style: AppText.title.copyWith(color: colors.accentInk),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          user.fullName,
                          style: AppText.label.copyWith(color: colors.ink),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          user.phone,
                          style: AppText.small.copyWith(color: colors.inkSoft),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
          if (property != null) ...[
            SectionLabel(property.name),
            AppCard(
              padding: EdgeInsets.zero,
              child: Column(
                children: [
                  NavRow(
                    icon: Icons.door_front_door_outlined,
                    title: 'Units',
                    subtitle:
                        '${property.totalUnits} units · ${property.occupiedUnits} occupied',
                    onTap: () => context.go(Routes.units),
                  ),
                  const Divider(height: 1),
                  NavRow(
                    icon: Icons.receipt_long_outlined,
                    title: 'Expenses',
                    subtitle: 'What is spent on the property, with receipts',
                    onTap: () => context.go(Routes.expenses),
                  ),
                  const Divider(height: 1),
                  NavRow(
                    icon: Icons.bolt_outlined,
                    title: 'Electricity bills',
                    subtitle: 'Amounts typed in each month',
                    onTap: () => context.go(Routes.electricity),
                  ),
                ],
              ),
            ),
          ],
          const SectionLabel('App'),
          AppCard(
            padding: EdgeInsets.zero,
            child: NavRow(
              icon: Icons.settings_outlined,
              title: 'Settings',
              subtitle: 'Light or dark, sign out',
              onTap: () => context.go(Routes.settings),
            ),
          ),
        ],
      ),
    );
  }
}
