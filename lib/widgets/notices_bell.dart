import 'package:flutter/material.dart';

import '../core/app_scope.dart';
import '../core/theme/app_colors.dart';
import '../features/notices/notices_page.dart';

/// The bell at the top of each tab: how many repairs are new for the
/// caretaker. Opens the list.
class NoticesBell extends StatelessWidget {
  const NoticesBell({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final count = AppScope.of(context).notices.count;

    return IconButton(
      tooltip: count == 0 ? 'Notifications' : '$count new',
      onPressed: () => Navigator.of(context).push(
        MaterialPageRoute<void>(builder: (_) => const NoticesPage()),
      ),
      icon: Badge(
        isLabelVisible: count > 0,
        backgroundColor: colors.accent,
        label: Text(count > 9 ? '9+' : '$count'),
        child: Icon(
          count > 0 ? Icons.notifications : Icons.notifications_outlined,
        ),
      ),
    );
  }
}
