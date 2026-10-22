import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../app/routes.dart';
import '../../config.dart';
import '../../core/app_scope.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text.dart';
import '../../core/theme/app_theme.dart';
import '../../widgets/brand.dart';
import '../../widgets/cards.dart';
import '../../widgets/notices_bell.dart';
import '../../widgets/status_chip.dart';

/// Who is signed in, the properties they look after and what they may do
/// in each, the owner to call, light or dark, signing out, the version.
class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key});

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
    final user = services.auth.user;
    final owner = services.auth.owner;
    final properties = services.properties.properties ?? const [];
    final current = services.properties.hasChosen
        ? services.properties.selected
        : null;
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
      appBar: AppBar(
        title: const Text('Profile'),
        actions: const [NoticesBell()],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppSpace.page,
          AppSpace.md,
          AppSpace.page,
          AppSpace.xxl,
        ),
        children: [
          if (user != null)
            AppCard(
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 26,
                    backgroundColor: colors.accentSoft,
                    child: Text(
                      user.fullName.isEmpty
                          ? '?'
                          : user.fullName.characters.first.toUpperCase(),
                      style: AppText.headline.copyWith(color: colors.accentInk),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          user.fullName,
                          style: AppText.title.copyWith(color: colors.ink),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${user.phone} · Caretaker',
                          style: AppText.small.copyWith(color: colors.inkSoft),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          SectionLabel(
            properties.length == 1 ? 'Your property' : 'Your properties',
            trailing: properties.length > 1
                ? TextButton(
                    onPressed: () => context.go(Routes.home),
                    child: const Text('Change'),
                  )
                : null,
          ),
          AppCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                for (final (index, property) in properties.indexed) ...[
                  if (index > 0) const Divider(height: 1),
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpace.lg,
                      vertical: 12,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                property.name,
                                style: AppText.label.copyWith(
                                  color: colors.ink,
                                ),
                              ),
                            ),
                            if (property.id == current?.id &&
                                properties.length > 1)
                              const StatusChip('Working on', tone: Tone.accent),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: [
                            for (final work in property.allowedWork)
                              StatusChip(work, tone: Tone.info),
                            if (property.allowedWork.isEmpty)
                              const StatusChip('No access yet'),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: AppSpace.sm),
          Text(
            'What you may do is set by the owner. Units, rent and deposits are changed by the owner on the web.',
            style: AppText.small.copyWith(color: colors.inkFaint),
          ),
          if (owner != null && owner.phone.isNotEmpty) ...[
            const SectionLabel('The owner'),
            AppCard(
              padding: EdgeInsets.zero,
              child: Column(
                children: [
                  NavRow(
                    icon: Icons.call_outlined,
                    title:
                        'Call ${owner.fullName.isEmpty ? 'the owner' : owner.fullName}',
                    subtitle: owner.phone,
                    onTap: () => launchUrl(Uri.parse('tel:${owner.phone}')),
                  ),
                  const Divider(height: 1),
                  NavRow(
                    icon: Icons.sms_outlined,
                    title: 'Send an SMS',
                    subtitle: 'For questions, or to ask for a change',
                    onTap: () => launchUrl(Uri.parse('sms:${owner.phone}')),
                  ),
                ],
              ),
            ),
          ],
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
