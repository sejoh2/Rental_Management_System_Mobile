import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';
import '../core/theme/app_text.dart';
import '../core/theme/app_theme.dart';

/// A white (dark mode: dark) card with a thin border, as on the web.
/// Pass [onTap] to make the whole card a button.
class AppCard extends StatelessWidget {
  const AppCard({
    super.key,
    required this.child,
    this.onTap,
    this.padding = const EdgeInsets.all(AppSpace.lg),
  });

  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final content = Padding(padding: padding, child: child);

    return Card(
      clipBehavior: Clip.antiAlias,
      child: onTap == null ? content : InkWell(onTap: onTap, child: content),
    );
  }
}

/// The small capital label above a group: "THIS MONTH".
class SectionLabel extends StatelessWidget {
  const SectionLabel(this.text, {super.key, this.trailing});

  final String text;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);

    return Padding(
      padding: const EdgeInsets.fromLTRB(2, AppSpace.lg, 2, AppSpace.sm),
      child: Row(
        children: [
          Expanded(
            child: Text(
              text.toUpperCase(),
              style: AppText.eyebrow.copyWith(color: colors.inkFaint),
            ),
          ),
          ?trailing,
        ],
      ),
    );
  }
}

/// One figure with its label, for summary cards: "18 of 24 / Readings done".
class StatTile extends StatelessWidget {
  const StatTile({
    super.key,
    required this.label,
    required this.value,
    this.tone,
  });

  final String label;
  final String value;

  /// The figure's colour; ink when not given.
  final Color? tone;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(value, style: AppText.figure.copyWith(color: tone ?? colors.ink)),
        const SizedBox(height: 4),
        Text(
          label,
          style: AppText.small.copyWith(color: colors.inkFaint, fontSize: 12),
        ),
      ],
    );
  }
}

/// A row in a list that opens something: icon, title, optional subtitle, arrow.
class NavRow extends StatelessWidget {
  const NavRow({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.onTap,
    this.trailing,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback? onTap;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpace.lg,
          vertical: 14,
        ),
        child: Row(
          children: [
            IconBadge(icon: icon),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: AppText.label.copyWith(color: colors.ink)),
                  if (subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      subtitle!,
                      style: AppText.small.copyWith(color: colors.inkSoft),
                    ),
                  ],
                ],
              ),
            ),
            trailing ??
                Icon(
                  Icons.chevron_right,
                  color: onTap == null ? Colors.transparent : colors.inkFaint,
                ),
          ],
        ),
      ),
    );
  }
}

/// An icon on the soft orange square used across the web app.
class IconBadge extends StatelessWidget {
  const IconBadge({super.key, required this.icon, this.size = 40});

  final IconData icon;
  final double size;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: colors.accentSoft,
        borderRadius: BorderRadius.circular(AppSpace.controlRadius),
      ),
      child: Icon(icon, color: colors.accentInk, size: size * 0.5),
    );
  }
}
