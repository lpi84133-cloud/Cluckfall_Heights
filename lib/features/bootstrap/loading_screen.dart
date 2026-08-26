import 'package:cluckfall_heights/app/providers.dart';
import 'package:cluckfall_heights/core/assets/app_assets.dart';
import 'package:cluckfall_heights/core/format/measure_format.dart';
import 'package:cluckfall_heights/core/theme/app_colors.dart';
import 'package:cluckfall_heights/core/theme/app_metrics.dart';
import 'package:cluckfall_heights/core/theme/app_typography.dart';
import 'package:cluckfall_heights/core/widgets/app_button.dart';
import 'package:cluckfall_heights/core/widgets/progress_track.dart';
import 'package:cluckfall_heights/features/bootstrap/bootstrap_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

/// Startup screen.
///
/// Two layouts, chosen by the shape of the window rather than by device type, and
/// each uses the artwork drawn for that shape. Both show the same two bars: a
/// horizontal one that fills left to right, and a vertical one styled as the
/// upright of a shelf frame, which is the app's own way of showing progress.
class LoadingScreen extends ConsumerStatefulWidget {
  const LoadingScreen({super.key});

  @override
  ConsumerState<LoadingScreen> createState() => _LoadingScreenState();
}

class _LoadingScreenState extends ConsumerState<LoadingScreen> {
  bool _navigated = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _start());
  }

  Future<void> _start() async {
    await ref.read(bootstrapProvider.notifier).run(
      precache: (String asset) => precacheImage(AssetImage(asset), context),
    );
  }

  void _leaveWhenReady(BootstrapState state) {
    if (!state.finished || _navigated) return;
    _navigated = true;
    // One frame at a full bar, so the completed state is actually seen rather
    // than skipped. Nothing is waiting on this; the app is already ready.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final bool onboarded = ref.read(preferencesProvider).onboardingCompleted;
      context.go(onboarded ? '/plans' : '/welcome');
    });
  }

  @override
  Widget build(BuildContext context) {
    final BootstrapState state = ref.watch(bootstrapProvider);
    _leaveWhenReady(state);

    return Scaffold(
      body: LayoutBuilder(
        builder: (context, constraints) {
          final bool wide = constraints.maxWidth > constraints.maxHeight;
          return Stack(
            fit: StackFit.expand,
            children: [
              Image.asset(
                wide ? BrandArt.loadingLandscape : BrandArt.loadingPortrait,
                fit: BoxFit.cover,
              ),
              DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      context.palette.canvas.withValues(alpha: 0.10),
                      context.palette.canvas.withValues(alpha: 0.92),
                    ],
                    stops: const [0.35, 1],
                  ),
                ),
              ),
              SafeArea(
                child: Padding(
                  padding: const EdgeInsets.all(Insets.xxl),
                  child: wide
                      ? _WideLayout(state: state, onRetry: _start)
                      : _TallLayout(state: state, onRetry: _start),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _TallLayout extends StatelessWidget {
  const _TallLayout({required this.state, required this.onRetry});

  final BootstrapState state;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const Spacer(),
        Image.asset(BrandArt.logo, width: 220),
        const Spacer(),
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            SizedBox(height: 120, child: VerticalProgressTrack(value: state.progress)),
            const SizedBox(width: Insets.xl),
            Expanded(child: _Status(state: state, onRetry: onRetry)),
          ],
        ),
      ],
    );
  }
}

class _WideLayout extends StatelessWidget {
  const _WideLayout({required this.state, required this.onRetry});

  final BootstrapState state;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        SizedBox(height: double.infinity, child: VerticalProgressTrack(value: state.progress)),
        const SizedBox(width: Insets.xxl),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Spacer(),
              Image.asset(BrandArt.logo, width: 240),
              const SizedBox(height: Insets.xxl),
              _Status(state: state, onRetry: onRetry),
            ],
          ),
        ),
      ],
    );
  }
}

class _Status extends StatelessWidget {
  const _Status({required this.state, required this.onRetry});

  final BootstrapState state;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final AppPalette palette = context.palette;

    if (state.failed) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(LucideIcons.triangleAlert, size: 18, color: palette.unstable),
              const SizedBox(width: Insets.sm),
              Text(
                'Startup did not finish',
                style: AppTypography.bodyStrong.copyWith(color: palette.textPrimary),
              ),
            ],
          ),
          const SizedBox(height: Insets.xs),
          Text(
            state.error!,
            style: AppTypography.caption.copyWith(color: palette.textSecondary),
          ),
          const SizedBox(height: Insets.lg),
          AppButton(
            label: 'Try again',
            icon: LucideIcons.rotateCw,
            expand: false,
            onPressed: onRetry,
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Expanded(
              child: Text(
                state.label,
                style: AppTypography.caption.copyWith(color: palette.textSecondary),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: Insets.sm),
            Text(
              percent(state.progress),
              style: AppTypography.metric.copyWith(fontSize: 18, color: palette.textPrimary),
            ),
          ],
        ),
        const SizedBox(height: Insets.md),
        ProgressTrack(value: state.progress),
      ],
    );
  }
}
