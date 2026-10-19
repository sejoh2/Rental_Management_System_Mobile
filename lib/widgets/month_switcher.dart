import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';
import '../core/theme/app_text.dart';
import '../utils/format.dart';

/// "‹  October 2026  ›" — moves between months, never past the current one.
class MonthSwitcher extends StatelessWidget {
  const MonthSwitcher({
    super.key,
    required this.month,
    required this.onChanged,
  });

  final DateTime month;
  final ValueChanged<DateTime> onChanged;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final isCurrent = month == monthOf(DateTime.now());

    return Row(
      children: [
        IconButton(
          onPressed: () => onChanged(DateTime(month.year, month.month - 1)),
          tooltip: 'Previous month',
          icon: const Icon(Icons.chevron_left),
        ),
        Expanded(
          child: Text(
            monthLabel(month),
            textAlign: TextAlign.center,
            style: AppText.title.copyWith(color: colors.ink, fontSize: 16),
          ),
        ),
        IconButton(
          onPressed: isCurrent
              ? null
              : () => onChanged(DateTime(month.year, month.month + 1)),
          tooltip: 'Next month',
          icon: const Icon(Icons.chevron_right),
        ),
      ],
    );
  }
}
