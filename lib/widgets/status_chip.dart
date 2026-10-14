import 'package:flutter/material.dart';

import '../core/app_theme.dart';

enum Tone { neutral, success, warning, danger, info, accent }

/// A small coloured label, like the web app's status badges.
class StatusChip extends StatelessWidget {
  const StatusChip(this.label, {super.key, this.tone = Tone.neutral});

  final String label;
  final Tone tone;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);

    final (background, foreground) = switch (tone) {
      Tone.success => (colors.successSoft, colors.success),
      Tone.warning => (colors.warningSoft, colors.warning),
      Tone.danger => (colors.dangerSoft, colors.danger),
      Tone.info => (colors.infoSoft, colors.info),
      Tone.accent => (colors.accentSoft, colors.accentInk),
      Tone.neutral => (colors.lineSoft, colors.inkSoft),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: foreground,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
