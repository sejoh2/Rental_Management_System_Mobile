import 'package:flutter/material.dart';

import '../config.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_text.dart';

/// The orange square with the brand letter, as in the web app's sidebar.
class BrandMark extends StatelessWidget {
  const BrandMark({super.key, this.size = 30});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: AppColors.light.accent,
        borderRadius: BorderRadius.circular(size * 0.27),
      ),
      child: Text(
        brandLetter,
        style: TextStyle(
          fontFamily: AppText.display,
          fontWeight: FontWeight.w700,
          fontSize: size * 0.5,
          height: 1,
          color: AppColors.onAccent,
        ),
      ),
    );
  }
}

/// The mark with the name beside it.
class BrandLockup extends StatelessWidget {
  const BrandLockup({super.key, this.onDark = false, this.caption});

  final bool onDark;
  final String? caption;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const BrandMark(),
        const SizedBox(width: 10),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              appName,
              style: AppText.title.copyWith(
                fontSize: 17,
                color: onDark ? AppColors.onAccent : colors.ink,
                height: 1,
              ),
            ),
            if (caption != null) ...[
              const SizedBox(height: 5),
              Text(
                caption!.toUpperCase(),
                style: AppText.eyebrow.copyWith(
                  fontSize: 9.5,
                  letterSpacing: 0.5,
                  fontWeight: FontWeight.w600,
                  color: onDark ? AppColors.brandPanelSoft : colors.inkFaint,
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }
}

/// The dark panel of the web sign-in page: warm orange glows over the dark
/// background, with faint ledger lines. The same in light and dark mode.
class BrandPanel extends StatelessWidget {
  const BrandPanel({
    super.key,
    required this.child,
    this.padding = EdgeInsets.zero,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(color: AppColors.brandPanel),
      child: CustomPaint(
        painter: const _BrandPanelPainter(),
        child: Padding(padding: padding, child: child),
      ),
    );
  }
}

class _BrandPanelPainter extends CustomPainter {
  const _BrandPanelPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final glow = AppColors.light.accent;

    void radial(Offset center, double radius, double opacity) {
      final rect = Rect.fromCircle(center: center, radius: radius);

      canvas.drawRect(
        Offset.zero & size,
        Paint()
          ..shader = RadialGradient(
            colors: [
              glow.withValues(alpha: opacity),
              glow.withValues(alpha: 0),
            ],
          ).createShader(rect),
      );
    }

    radial(
      Offset(size.width * 0.2, size.height * 0.2),
      size.longestSide * 0.45,
      0.35,
    );
    radial(
      Offset(size.width * 0.8, size.height * 0.75),
      size.longestSide * 0.5,
      0.18,
    );

    // A ruled line every 34 pixels, as in a rent book.
    final line = Paint()
      ..color = AppColors.onAccent.withValues(alpha: 0.06)
      ..strokeWidth = 1;

    for (double y = 0; y < size.height; y += 34) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), line);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
