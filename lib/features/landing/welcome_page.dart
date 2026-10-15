import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../app/routes.dart';
import '../../core/app_scope.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text.dart';
import '../../core/theme/app_theme.dart';
import '../../widgets/brand.dart';

/// The first screen on a new phone: the dark brand panel, what the app is
/// for, and the way in. After the intro has been seen, signing out leads
/// straight to the sign-in screen instead.
class WelcomePage extends StatelessWidget {
  const WelcomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.brandPanel,
      body: BrandPanel(
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpace.xl,
              AppSpace.xl,
              AppSpace.xl,
              AppSpace.lg,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Align(
                  alignment: Alignment.centerLeft,
                  child: BrandLockup(onDark: true, caption: 'Caretaker app'),
                ),
                const Spacer(),
                Text(
                  'FOR CARETAKERS',
                  style: AppText.eyebrow.copyWith(
                    color: AppColors.brandEyebrow,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  'Your property work, done from your phone.',
                  style: AppText.headline.copyWith(
                    color: AppColors.onAccent,
                    fontSize: 30,
                    height: 1.15,
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  'Record meter readings with a photo, report repairs, add expenses and look after '
                  'tenants for the properties you care for. The owner sees it all.',
                  style: AppText.text.copyWith(color: AppColors.brandPanelSoft),
                ),
                const SizedBox(height: AppSpace.xl),
                const _Highlights(),
                const Spacer(),
                FilledButton(
                  onPressed: () => context.go(Routes.intro),
                  child: const Text('Get started'),
                ),
                const SizedBox(height: AppSpace.sm),
                TextButton(
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.onAccent,
                    minimumSize: const Size.fromHeight(46),
                  ),
                  onPressed: () async {
                    // Someone who already knows the app skips the intro for good.
                    await AppScope.read(context).preferences.markIntroSeen();
                    if (context.mounted) context.go(Routes.signIn);
                  },
                  child: const Text('I already have an account'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Highlights extends StatelessWidget {
  const _Highlights();

  @override
  Widget build(BuildContext context) {
    Widget item(String title, String label) {
      return Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: AppText.amount.copyWith(
                color: AppColors.onAccent,
                fontSize: 17,
              ),
            ),
            const SizedBox(height: 5),
            Text(
              label.toUpperCase(),
              style: AppText.eyebrow.copyWith(
                color: AppColors.brandPanelSoft,
                fontSize: 9.5,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
      );
    }

    return Row(
      children: [
        item('Water', 'Readings'),
        item('Repairs', 'Reported'),
        item('Receipts', 'Photographed'),
      ],
    );
  }
}
