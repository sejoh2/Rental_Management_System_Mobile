import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';
import '../core/theme/app_text.dart';
import '../core/theme/app_theme.dart';

/// An error shown inside a form or a screen.
class ErrorBox extends StatelessWidget {
  const ErrorBox(this.message, {super.key});

  final String message;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: colors.dangerSoft,
        borderRadius: BorderRadius.circular(AppSpace.controlRadius),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.error_outline, size: 18, color: colors.danger),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: AppText.small.copyWith(color: colors.danger, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}

/// A note in a soft box: what will happen, or why something is not possible.
class NoteBox extends StatelessWidget {
  const NoteBox(this.message, {super.key, this.icon = Icons.info_outline});

  final String message;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: colors.surface,
        border: Border.all(color: colors.line),
        borderRadius: BorderRadius.circular(AppSpace.controlRadius),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: colors.inkFaint),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: AppText.small.copyWith(
                color: colors.inkSoft,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Shown in place of a list while it loads for the first time.
class LoadingView extends StatelessWidget {
  const LoadingView({super.key});

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(AppSpace.xxl),
        child: SizedBox(
          width: 26,
          height: 26,
          child: CircularProgressIndicator(strokeWidth: 2.6),
        ),
      ),
    );
  }
}

/// Shown in place of a list that could not be loaded, with a way to try again.
class ErrorView extends StatelessWidget {
  const ErrorView({super.key, required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return EmptyView(
      icon: Icons.cloud_off_outlined,
      title: 'Could not load this',
      message: message,
      actionLabel: 'Try again',
      onAction: onRetry,
    );
  }
}

/// Shown when there is nothing to list, or nothing yet.
class EmptyView extends StatelessWidget {
  const EmptyView({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpace.xl,
          vertical: AppSpace.xxl,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: colors.lineSoft,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, color: colors.inkFaint, size: 26),
            ),
            const SizedBox(height: AppSpace.lg),
            Text(
              title,
              textAlign: TextAlign.center,
              style: AppText.title.copyWith(color: colors.ink, fontSize: 16),
            ),
            const SizedBox(height: 6),
            Text(
              message,
              textAlign: TextAlign.center,
              style: AppText.small.copyWith(
                color: colors.inkSoft,
                fontSize: 13,
              ),
            ),
            if (actionLabel != null) ...[
              const SizedBox(height: AppSpace.lg),
              SizedBox(
                width: 200,
                child: OutlinedButton(
                  onPressed: onAction,
                  child: Text(actionLabel!),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// A whole-screen message with one action, such as "Try again".
class FullScreenMessage extends StatelessWidget {
  const FullScreenMessage({
    super.key,
    required this.title,
    required this.message,
    this.icon = Icons.info_outline,
    this.actionLabel,
    this.onAction,
    this.secondaryLabel,
    this.onSecondary,
  });

  final String title;
  final String message;
  final IconData icon;
  final String? actionLabel;
  final VoidCallback? onAction;
  final String? secondaryLabel;
  final VoidCallback? onSecondary;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpace.xl),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Icon(icon, size: 40, color: colors.inkFaint),
                  const SizedBox(height: AppSpace.lg),
                  Text(
                    title,
                    textAlign: TextAlign.center,
                    style: AppText.headline.copyWith(
                      color: colors.ink,
                      fontSize: 22,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    message,
                    textAlign: TextAlign.center,
                    style: AppText.text.copyWith(color: colors.inkSoft),
                  ),
                  if (actionLabel != null) ...[
                    const SizedBox(height: AppSpace.xl),
                    FilledButton(
                      onPressed: onAction,
                      child: Text(actionLabel!),
                    ),
                  ],
                  if (secondaryLabel != null) ...[
                    const SizedBox(height: AppSpace.sm),
                    TextButton(
                      onPressed: onSecondary,
                      child: Text(secondaryLabel!),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
