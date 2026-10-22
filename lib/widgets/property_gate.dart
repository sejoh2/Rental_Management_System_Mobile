import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../app/routes.dart';
import '../core/app_scope.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_text.dart';
import '../core/theme/app_theme.dart';
import '../models/caretaker_property.dart';
import 'message_box.dart';
import 'notices_bell.dart';

/// Shows [builder] with the property being worked on, or what is in the way:
/// the list still loading, a failure, or no property assigned yet. When the
/// property chosen before is no longer theirs and they have several, it
/// sends them to Home to choose.
class PropertyGate extends StatelessWidget {
  const PropertyGate({super.key, required this.builder});

  final Widget Function(BuildContext context, CaretakerProperty property)
  builder;

  @override
  Widget build(BuildContext context) {
    final controller = AppScope.of(context).properties;
    final list = controller.properties;

    if (list == null) {
      return Scaffold(
        body: SafeArea(
          child: controller.error != null
              ? ErrorView(message: controller.error!, onRetry: controller.load)
              : const LoadingView(),
        ),
      );
    }

    if (list.isEmpty) {
      return Scaffold(
        body: SafeArea(
          child: EmptyView(
            icon: Icons.home_work_outlined,
            title: 'No property yet',
            message:
                'You are not assigned to any property yet. Ask the owner to add you, then check again.',
            actionLabel: 'Check again',
            onAction: controller.load,
          ),
        ),
      );
    }

    if (!controller.hasChosen) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (context.mounted) context.go(Routes.home);
      });

      return const Scaffold(body: LoadingView());
    }

    return builder(context, controller.selected!);
  }
}

/// The property every tab is showing, under each screen's title. With more
/// than one property, tapping it goes back to Home to choose another: Home
/// is the one place to switch.
class PropertyStrip extends StatelessWidget implements PreferredSizeWidget {
  const PropertyStrip({super.key});

  @override
  Size get preferredSize => const Size.fromHeight(40);

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final controller = AppScope.of(context).properties;
    final property = controller.selected;
    final several = (controller.properties?.length ?? 0) > 1;

    if (property == null) return const SizedBox(height: 40);

    final content = Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpace.page),
      child: Row(
        children: [
          Icon(Icons.apartment_outlined, size: 17, color: colors.accentInk),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              property.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppText.small.copyWith(
                color: colors.ink,
                fontWeight: FontWeight.w700,
                fontSize: 13,
              ),
            ),
          ),
          if (several) ...[
            Text(
              'Change',
              style: AppText.small.copyWith(
                color: colors.accentInk,
                fontWeight: FontWeight.w700,
              ),
            ),
            Icon(Icons.unfold_more, size: 17, color: colors.accentInk),
          ],
        ],
      ),
    );

    return Material(
      color: colors.bg,
      child: SizedBox(
        height: 40,
        child: several
            ? InkWell(onTap: () => context.go(Routes.home), child: content)
            : content,
      ),
    );
  }
}

/// A tab whose work the owner has not allowed in this property: its title
/// and the property strip (to switch), with the reason.
class LockedTab extends StatelessWidget {
  const LockedTab({
    super.key,
    required this.title,
    required this.what,
    required this.property,
  });

  final String title;
  final String what;
  final CaretakerProperty property;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        actions: const [NoticesBell()],
        bottom: const PropertyStrip(),
      ),
      body: NoAccessView(what: what, propertyName: property.name),
    );
  }
}
