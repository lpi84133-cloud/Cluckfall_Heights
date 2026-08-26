import 'package:cluckfall_heights/app/providers.dart';
import 'package:cluckfall_heights/core/assets/app_assets.dart';
import 'package:cluckfall_heights/core/services/feedback_service.dart';
import 'package:cluckfall_heights/core/theme/app_colors.dart';
import 'package:cluckfall_heights/core/theme/app_metrics.dart';
import 'package:cluckfall_heights/core/theme/app_typography.dart';
import 'package:cluckfall_heights/core/widgets/app_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

/// Shown once, before the first plan exists.
///
/// Three sentences about what the app does and a button that starts the real work.
/// No permission requests here: the app asks for the camera only when the user taps
/// the profile photo, which is the only moment the request makes sense.
class WelcomeScreen extends ConsumerWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppPalette palette = context.palette;

    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset(BackgroundArt.pantry, fit: BoxFit.cover),
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  palette.canvas.withValues(alpha: 0.45),
                  palette.canvas.withValues(alpha: 0.94),
                ],
                stops: const [0.0, 0.55],
              ),
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(Insets.page),
              child: Column(
                children: [
                  const Spacer(),
                  Image.asset(BrandArt.logo, height: 96),
                  const SizedBox(height: Insets.xl),
                  Text(
                    'Cluckfall Heights',
                    textAlign: TextAlign.center,
                    style: AppTypography.display.copyWith(color: palette.textPrimary),
                  ),
                  const SizedBox(height: Insets.sm),
                  Text(
                    'Plan what goes where before you lift a thing.',
                    textAlign: TextAlign.center,
                    style: AppTypography.body.copyWith(color: palette.textSecondary),
                  ),
                  const Spacer(),
                  const _Point(
                    icon: LucideIcons.layoutPanelTop,
                    title: 'Lay it out',
                    body: 'Draw your shelf, cabinet or pantry and place real objects on it.',
                  ),
                  const _Point(
                    icon: LucideIcons.scale,
                    title: 'See the weight',
                    body: 'The app works out where the mass sits and which level is loaded.',
                  ),
                  const _Point(
                    icon: LucideIcons.wand,
                    title: 'Fix it before you move it',
                    body: 'Get specific swaps that lower the centre of mass, then apply them.',
                  ),
                  const Spacer(),
                  AppButton(
                    label: 'Plan my first space',
                    onPressed: () async {
                      await ref.read(feedbackProvider).tap();
                      await ref.read(preferencesProvider.notifier).completeOnboarding();
                      if (!context.mounted) return;
                      context.go('/plans/new');
                    },
                  ),
                  const SizedBox(height: Insets.md),
                  TextButton(
                    onPressed: () async {
                      await ref.read(preferencesProvider.notifier).completeOnboarding();
                      if (!context.mounted) return;
                      context.go('/plans');
                    },
                    child: Text(
                      'Look around first',
                      style: AppTypography.body.copyWith(color: palette.textSecondary),
                    ),
                  ),
                  const SizedBox(height: Insets.sm),
                  Text(
                    'Works offline. Nothing is uploaded.',
                    style: AppTypography.caption.copyWith(color: palette.textTertiary),
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

class _Point extends StatelessWidget {
  const _Point({required this.icon, required this.title, required this.body});

  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    final AppPalette palette = context.palette;

    return Padding(
      padding: const EdgeInsets.only(bottom: Insets.lg),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: palette.surface,
              borderRadius: const BorderRadius.all(Radius.circular(Corners.sm)),
              border: Border.all(color: palette.hairline),
            ),
            child: Icon(icon, size: 17, color: palette.accent),
          ),
          const SizedBox(width: Insets.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: AppTypography.bodyStrong.copyWith(color: palette.textPrimary),
                ),
                const SizedBox(height: 1),
                Text(
                  body,
                  style: AppTypography.caption.copyWith(color: palette.textSecondary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
