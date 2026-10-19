import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../core/app_scope.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_text.dart';
import '../core/theme/app_theme.dart';

/// The bottom bar and the tabs above it, for the chosen property. Each tab
/// keeps its own place, so going to another tab and back returns to where
/// you were.
class AppShell extends StatelessWidget {
  const AppShell({super.key, required this.shell});

  final StatefulNavigationShell shell;

  @override
  Widget build(BuildContext context) {
    final readOnly = AppScope.of(context).auth.readOnly;
    // While typing, the tabs step aside so the form has all the room above the keyboard.
    final typing = MediaQuery.viewInsetsOf(context).bottom > 0;

    return Scaffold(
      // Each page inside makes room for the keyboard itself. Doing it here
      // too would take the keyboard's height away twice, leaving a form only
      // a thin strip at the top.
      resizeToAvoidBottomInset: false,
      body: Column(
        children: [
          if (readOnly) const ReadOnlyBanner(),
          Expanded(
            // The banner already keeps clear of the status bar.
            child: MediaQuery.removePadding(
              context: context,
              removeTop: readOnly,
              child: shell,
            ),
          ),
        ],
      ),
      bottomNavigationBar: typing
          ? null
          : DecoratedBox(
              decoration: BoxDecoration(
                border: Border(
                  top: BorderSide(color: Theme.of(context).dividerTheme.color!),
                ),
              ),
              child: NavigationBar(
                selectedIndex: shell.currentIndex,
                // Tapping the tab you are on returns to its first page.
                onDestinationSelected: (index) => shell.goBranch(
                  index,
                  initialLocation: index == shell.currentIndex,
                ),
                destinations: const [
                  NavigationDestination(
                    icon: Icon(Icons.door_front_door_outlined),
                    selectedIcon: Icon(Icons.door_front_door),
                    label: 'Units',
                  ),
                  NavigationDestination(
                    icon: Icon(Icons.receipt_long_outlined),
                    selectedIcon: Icon(Icons.receipt_long),
                    label: 'Expenses',
                  ),
                  NavigationDestination(
                    icon: Icon(Icons.build_outlined),
                    selectedIcon: Icon(Icons.build),
                    label: 'Repairs',
                  ),
                  NavigationDestination(
                    icon: Icon(Icons.water_drop_outlined),
                    selectedIcon: Icon(Icons.water_drop),
                    label: 'Water & Power',
                  ),
                  NavigationDestination(
                    icon: Icon(Icons.person_outline),
                    selectedIcon: Icon(Icons.person),
                    label: 'Profile',
                  ),
                ],
              ),
            ),
    );
  }
}

/// Shown on every tab while the owner's Kodi bill is unpaid: the server
/// refuses every change until it is paid.
class ReadOnlyBanner extends StatelessWidget {
  const ReadOnlyBanner({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);

    return Material(
      color: colors.warningSoft,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpace.page,
            vertical: 10,
          ),
          child: Row(
            children: [
              Icon(Icons.lock_outline, size: 18, color: colors.warning),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'This account is read-only until the owner pays Kodi. '
                  'You can look at everything, but not save changes.',
                  style: AppText.small.copyWith(
                    color: colors.ink,
                    fontSize: 12.5,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
