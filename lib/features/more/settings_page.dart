import 'package:flutter/material.dart';

import '../../config.dart';
import '../../core/app_scope.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text.dart';
import '../../core/theme/app_theme.dart';
import '../../widgets/brand.dart';
import '../../widgets/cards.dart';

/// Light or dark, signing out, and what version this is.
class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  Future<void> _confirmSignOut(BuildContext context) async {
    final auth = AppScope.read(context).auth;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Sign out?'),
        content: const Text('You will need a new SMS code to sign in again.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Stay signed in'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Sign out'),
          ),
        ],
      ),
    );

    if (confirmed == true) await auth.signOut();
  }

  @override
  Widget build(BuildContext context) {
    final services = AppScope.of(context);
    final colors = AppColors.of(context);
    final mode = services.preferences.themeMode;

    const choices = [
      (
        ThemeMode.system,
        'Follow the phone',
        'Light or dark, as the phone is set',
        Icons.brightness_auto_outlined,
      ),
      (ThemeMode.light, 'Light', 'Always light', Icons.light_mode_outlined),
      (ThemeMode.dark, 'Dark', 'Always dark', Icons.dark_mode_outlined),
    ];

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppSpace.page,
          AppSpace.sm,
          AppSpace.page,
          AppSpace.xxl,
        ),
        children: [
          const SectionLabel('Appearance'),
          AppCard(
            padding: EdgeInsets.zero,
            child: RadioGroup<ThemeMode>(
              groupValue: mode,
              onChanged: (value) {
                if (value != null) services.preferences.setThemeMode(value);
              },
              child: Column(
                children: [
                  for (final (value, title, subtitle, icon) in choices)
                    RadioListTile<ThemeMode>(
                      value: value,
                      activeColor: colors.accent,
                      secondary: Icon(icon, color: colors.inkSoft),
                      title: Text(title),
                      subtitle: Text(subtitle),
                    ),
                ],
              ),
            ),
          ),
          const SectionLabel('Account'),
          AppCard(
            padding: EdgeInsets.zero,
            child: NavRow(
              icon: Icons.logout,
              title: 'Sign out',
              subtitle: 'Ends your session on this phone',
              trailing: const SizedBox.shrink(),
              onTap: () => _confirmSignOut(context),
            ),
          ),
          const SectionLabel('About'),
          AppCard(
            child: Row(
              children: [
                const BrandMark(size: 40),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '$appName caretaker app',
                        style: AppText.label.copyWith(color: colors.ink),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Version $appVersion · ${Uri.parse(apiUrl).host}',
                        style: AppText.small.copyWith(color: colors.inkSoft),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
