import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text.dart';
import '../../core/theme/app_theme.dart';
import '../../widgets/brand.dart';

/// The frame of the sign-in screens: the brand panel on the top half of the
/// screen, as on the web sign-in page, and the form on the bottom half.
class AuthLayout extends StatelessWidget {
  const AuthLayout({
    super.key,
    required this.title,
    required this.subtitle,
    required this.children,
    this.onBack,
  });

  final String title;
  final String subtitle;
  final List<Widget> children;

  /// Shows a back arrow on the panel, for a step that can be undone.
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    // Half the screen each: the brand panel on top, the form below. Fixed to
    // the screen (not to the space left by the keyboard), and scrollable, so
    // the field stays in view while typing.
    final half = MediaQuery.sizeOf(context).height / 2;

    return Scaffold(
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ConstrainedBox(
              constraints: BoxConstraints(minHeight: half),
              child: BrandPanel(
                child: SafeArea(
                  bottom: false,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpace.xl,
                      AppSpace.md,
                      AppSpace.xl,
                      AppSpace.xxl,
                    ),
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        minHeight: half -
                            MediaQuery.paddingOf(context).top -
                            AppSpace.md -
                            AppSpace.xxl,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          // Top of the panel: back (when there is a step to undo) and the brand.
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              SizedBox(
                                height: 44,
                                child: onBack == null
                                    ? null
                                    : IconButton(
                                        onPressed: onBack,
                                        color: AppColors.onAccent,
                                        padding: EdgeInsets.zero,
                                        alignment: Alignment.centerLeft,
                                        icon: const Icon(Icons.arrow_back),
                                        tooltip: 'Back',
                                      ),
                              ),
                              const BrandLockup(onDark: true, caption: 'Caretaker app'),
                            ],
                          ),
                          // Bottom of the panel: what this step is.
                          Padding(
                            padding: const EdgeInsets.only(top: AppSpace.xl),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  title,
                                  style: AppText.headline.copyWith(
                                    color: AppColors.onAccent,
                                    fontSize: 28,
                                  ),
                                ),
                                const SizedBox(height: AppSpace.sm),
                                Text(
                                  subtitle,
                                  style: AppText.text.copyWith(
                                    color: AppColors.brandPanelSoft,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
            ConstrainedBox(
              constraints: BoxConstraints(minHeight: half),
              child: Padding(
                padding: const EdgeInsets.all(AppSpace.xl),
                child: DefaultTextStyle.merge(
                  style: TextStyle(color: colors.ink),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: children,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
