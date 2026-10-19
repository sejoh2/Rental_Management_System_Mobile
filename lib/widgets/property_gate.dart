import 'package:flutter/material.dart';

import '../core/app_scope.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_text.dart';
import '../core/theme/app_theme.dart';
import '../models/caretaker_property.dart';
import 'message_box.dart';

/// Shows [builder] with the property being worked on, or what is in the way:
/// the list still loading, a failure, or no property assigned yet.
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

    return builder(context, controller.selected!);
  }
}

/// The property every tab is showing, under each screen's title. With more
/// than one property, tapping it switches the whole app to another one.
/// This is the one place to switch; no screen has its own property choice.
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
              'Switch',
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
            ? InkWell(onTap: () => showPropertyPicker(context), child: content)
            : content,
      ),
    );
  }
}

/// Lets the caretaker choose which property to work on.
Future<void> showPropertyPicker(BuildContext context) {
  final controller = AppScope.read(context).properties;
  final list = controller.properties ?? const <CaretakerProperty>[];
  final selectedId = controller.selected?.id;

  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (sheetContext) {
      final colors = AppColors.of(sheetContext);

      return SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpace.xl,
                0,
                AppSpace.xl,
                AppSpace.sm,
              ),
              child: Text(
                'Choose a property',
                style: AppText.title.copyWith(color: colors.ink),
              ),
            ),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                children: [
                  for (final property in list)
                    ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: AppSpace.xl,
                        vertical: 2,
                      ),
                      title: Text(property.name),
                      subtitle: Text(
                        [
                          if (property.location.isNotEmpty) property.location,
                          '${property.totalUnits} units',
                        ].join(' · '),
                      ),
                      trailing: property.id == selectedId
                          ? Icon(Icons.check_circle, color: colors.accentInk)
                          : null,
                      onTap: () {
                        controller.select(property);
                        Navigator.pop(sheetContext);
                      },
                    ),
                ],
              ),
            ),
            const SizedBox(height: AppSpace.sm),
          ],
        ),
      );
    },
  );
}
