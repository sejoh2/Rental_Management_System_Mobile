import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../app/routes.dart';
import '../../core/app_scope.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text.dart';
import '../../core/theme/app_theme.dart';
import '../../widgets/brand.dart';

class _Slide {
  const _Slide({required this.icon, required this.title, required this.text});

  final IconData icon;
  final String title;
  final String text;
}

const _slides = [
  _Slide(
    icon: Icons.water_drop_outlined,
    title: 'Meter readings, with proof',
    text:
        'Record each house’s reading and take a photo of the meter. The bill is worked out for you, '
        'and the photo settles any question later.',
  ),
  _Slide(
    icon: Icons.build_outlined,
    title: 'Repairs and expenses',
    text:
        'Report a repair the moment you see it, follow it to done, and add what you spent with a photo '
        'of the receipt.',
  ),
  _Slide(
    icon: Icons.verified_user_outlined,
    title: 'Your work, under your name',
    text:
        'Everything you record carries your name, so the owner always knows who did what. The owner '
        'decides what you may do in each property.',
  ),
];

/// Three short slides shown once, before the first sign-in.
class IntroPage extends StatefulWidget {
  const IntroPage({super.key});

  @override
  State<IntroPage> createState() => _IntroPageState();
}

class _IntroPageState extends State<IntroPage> {
  final _pages = PageController();
  int _index = 0;

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  bool get _last => _index == _slides.length - 1;

  Future<void> _finish() async {
    await AppScope.read(context).preferences.markIntroSeen();
    if (mounted) context.go(Routes.signIn);
  }

  void _next() {
    if (_last) {
      _finish();
    } else {
      _pages.nextPage(
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);

    return Scaffold(
      body: Column(
        children: [
          Expanded(
            child: PageView.builder(
              controller: _pages,
              itemCount: _slides.length,
              onPageChanged: (index) => setState(() => _index = index),
              itemBuilder: (context, index) =>
                  _SlideView(slide: _slides[index]),
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpace.xl,
                AppSpace.lg,
                AppSpace.xl,
                AppSpace.lg,
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      for (var i = 0; i < _slides.length; i++)
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          margin: const EdgeInsets.symmetric(horizontal: 3),
                          width: i == _index ? 22 : 7,
                          height: 7,
                          decoration: BoxDecoration(
                            color: i == _index ? colors.accent : colors.line,
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: AppSpace.xl),
                  FilledButton(
                    onPressed: _next,
                    child: Text(_last ? 'Sign in' : 'Next'),
                  ),
                  const SizedBox(height: AppSpace.sm),
                  TextButton(
                    style: TextButton.styleFrom(
                      foregroundColor: colors.inkSoft,
                      minimumSize: const Size.fromHeight(44),
                    ),
                    // Kept in place on the last slide, so the buttons do not jump.
                    onPressed: _last ? null : _finish,
                    child: Text(_last ? '' : 'Skip'),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SlideView extends StatelessWidget {
  const _SlideView({required this.slide});

  final _Slide slide;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          flex: 5,
          child: BrandPanel(
            child: SafeArea(
              bottom: false,
              child: Center(
                child: Container(
                  width: 112,
                  height: 112,
                  decoration: BoxDecoration(
                    color: AppColors.onAccent.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(28),
                    border: Border.all(
                      color: AppColors.onAccent.withValues(alpha: 0.12),
                    ),
                  ),
                  child: Icon(
                    slide.icon,
                    size: 52,
                    color: AppColors.brandEyebrow,
                  ),
                ),
              ),
            ),
          ),
        ),
        Expanded(
          flex: 4,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpace.xl,
              AppSpace.xl,
              AppSpace.xl,
              0,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  slide.title,
                  style: AppText.headline.copyWith(color: colors.ink),
                ),
                const SizedBox(height: AppSpace.md),
                Text(
                  slide.text,
                  style: AppText.text.copyWith(
                    color: colors.inkSoft,
                    fontSize: 15,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
