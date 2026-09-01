import 'dart:async';
import 'dart:math' as math;

import 'package:cluckfall_heights/app/providers.dart';
import 'package:cluckfall_heights/core/assets/app_assets.dart';
import 'package:cluckfall_heights/core/format/measure_format.dart';
import 'package:cluckfall_heights/core/theme/app_colors.dart';
import 'package:cluckfall_heights/core/theme/app_metrics.dart';
import 'package:cluckfall_heights/core/theme/app_typography.dart';
import 'package:cluckfall_heights/core/widgets/app_button.dart';
import 'package:cluckfall_heights/core/widgets/progress_track.dart';
import 'package:cluckfall_heights/features/bootstrap/bootstrap_controller.dart';
import 'package:cluckfall_heights/loft/core/loft_models.dart';
import 'package:cluckfall_heights/loft/loft_guide.dart';
import 'package:cluckfall_heights/loft/loft_scope.dart';
import 'package:cluckfall_heights/loft/pages/permit_deck.dart';
import 'package:cluckfall_heights/loft/pages/quiet_deck.dart';
import 'package:cluckfall_heights/loft/pages/span_pane.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
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
  const LoadingScreen({super.key, this.initialProgress = 0});

  /// Retry after no-wifi resumes from the last visible fill instead of 0.
  final double initialProgress;

  @override
  ConsumerState<LoadingScreen> createState() => _LoadingScreenState();
}

class _LoadingScreenState extends ConsumerState<LoadingScreen>
    with SingleTickerProviderStateMixin {
  static const Duration _holdAfterReady = Duration(milliseconds: 260);
  static const Duration _minimumVisible = Duration(seconds: 2);

  /// Live target for the fill bar. The pilot pushes this forward at each
  /// pipeline stage; a slow background creep keeps the bar visibly alive
  /// between stages so the user never sees it freeze on a wifi probe.
  double _gateTarget = 0;

  /// Current animated fill, chases [_gateTarget] on the ticker.
  late double _displayed;
  late final Ticker _ticker;
  Duration _lastElapsed = Duration.zero;
  LoftDestination? _destination;
  bool _leaving = false;
  bool _grayOwnsBar = false;
  bool _whiteReady = false;
  bool _whiteStarted = false;

  @override
  void initState() {
    super.initState();
    _displayed = widget.initialProgress.clamp(0.0, 1.0);
    _gateTarget = _displayed;
    _ticker = createTicker(_onTick)..start();
    _startedAt = DateTime.now();
    WidgetsBinding.instance.addPostFrameCallback((_) => _start());
  }

  DateTime? _startedAt;

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  void _bumpGate(double value) {
    final clamped = value.clamp(0.0, 1.0);
    if (clamped <= _gateTarget) return;
    if (mounted) {
      setState(() => _gateTarget = clamped);
    } else {
      _gateTarget = clamped;
    }
  }

  void _onTick(Duration elapsed) {
    final dt = ((elapsed - _lastElapsed).inMicroseconds / 1000000).clamp(
      0.0,
      0.05,
    );
    _lastElapsed = elapsed;
    if (dt <= 0 || !_grayOwnsBar) return;

    final dest = _destination;
    if (dest is QuietSpan) {
      _tryLeaveGray();
      return;
    }

    // Slow background creep of the *target* between real pipeline events, so
    // the bar keeps drifting up 1–2 % per second during ATT / AF / config
    // instead of appearing frozen. Caps at 0.92 until a verdict comes in.
    if (dest == null && _gateTarget < 0.92) {
      _gateTarget = math.min(0.92, _gateTarget + 0.02 * dt);
    }

    final target = _gateTarget;
    final speed = (dest is NativeSpan || dest is PortalSpan) ? 1.45 : 0.42;
    final next = math.min(target, _displayed + speed * dt);

    if ((next - _displayed).abs() > 0.0005) {
      setState(() => _displayed = next);
    } else if (_displayed != target && target <= _displayed) {
      _displayed = target;
    }

    if ((dest is NativeSpan || dest is PortalSpan) && _displayed >= 0.995) {
      if (_displayed != 1) setState(() => _displayed = 1);
      _tryLeaveGray();
    }
  }

  Future<void> _start() async {
    final LoftGuide? guide = ref.read(loftGuideProvider);
    if (guide != null && guide.enabled) {
      if (_destination != null) return;
      _grayOwnsBar = true;
      late final LoftDestination destination;
      try {
        destination = await guide.decide(onProgress: _bumpGate);
      } catch (_) {
        destination = guide.vault.route == SpanRoute.undecided
            ? const QuietSpan(returnToNative: false)
            : const NativeSpan();
      }
      if (!mounted) return;
      if (destination is PortalSpan) {
        unawaited(_warmArts(PermitDeck.artAssets));
      }
      // On a real verdict jump the target to 1.0 so the bar can fill.
      if (destination is NativeSpan || destination is PortalSpan) {
        _bumpGate(1.0);
      }
      setState(() => _destination = destination);
      _tryLeaveGray();
      return;
    }

    await ref
        .read(bootstrapProvider.notifier)
        .run(
          precache: (String asset) => precacheImage(AssetImage(asset), context),
        );
  }

  Future<void> _warmWhiteAssets() async {
    if (_whiteStarted) return;
    _whiteStarted = true;
    try {
      await ref
          .read(bootstrapProvider.notifier)
          .run(
            precache: (String asset) =>
                precacheImage(AssetImage(asset), context),
          );
    } catch (_) {}
    _whiteReady = true;
    if (mounted) _tryLeaveGray();
  }

  void _tryLeaveGray() {
    if (_leaving || !_grayOwnsBar) return;
    final dest = _destination;
    if (dest == null) return;
    if (dest is QuietSpan) {
      _leaving = true;
      _ticker.stop();
      unawaited(_openAfterHold(dest));
      return;
    }
    if (_displayed < 0.995) return;
    if (dest is NativeSpan) {
      if (!_whiteStarted) {
        unawaited(_warmWhiteAssets());
        return;
      }
      if (!_whiteReady) return;
    }
    _leaving = true;
    _ticker.stop();
    unawaited(_openAfterHold(dest));
  }

  Future<void> _openAfterHold(LoftDestination destination) async {
    if (destination is! QuietSpan) {
      await Future<void>.delayed(_holdAfterReady);
    }
    if (!mounted) return;
    await _openDestination(destination);
  }

  Future<void> _openDestination(LoftDestination destination) async {
    final LoftGuide? guide = ref.read(loftGuideProvider);
    if (destination is QuietSpan) {
      if (guide == null) return;
      _openQuiet(guide);
      return;
    }
    if (destination is PortalSpan) {
      if (guide == null) return;
      await _openPortal(guide, destination);
      return;
    }
    if (destination is NativeSpan) {
      await _enterPlanner();
    }
  }

  void _openQuiet(LoftGuide guide) {
    if (_navigated) return;
    _navigated = true;
    unawaited(
      Navigator.of(context, rootNavigator: true).pushAndRemoveUntil(
        MaterialPageRoute<void>(
          builder: (_) => QuietDeck(
            probe: guide.probe,
            retryBuilder: (_) => const LoadingScreen(initialProgress: 0.35),
          ),
        ),
        (_) => false,
      ),
    );
  }

  Future<void> _openPortal(LoftGuide guide, PortalSpan destination) async {
    if (_navigated) return;
    _navigated = true;
    Widget paneBuilder(BuildContext _) => SpanPane(
      url: destination.url,
      coldLaunch: destination.coldLaunch,
      vault: guide.vault,
      probe: guide.probe,
      notifications: guide.notifications,
      agent: guide.agent,
    );

    final NavigatorState nav = Navigator.of(context, rootNavigator: true);
    // First launch under the `_firstDecision` path started `boot()` in the
    // background, so `_messaging` may still be null right here. Wait for it
    // to settle before asking the OS anything, otherwise
    // `canOfferPermission()` returns false and the deck is silently skipped.
    if (!guide.notifications.isReady) {
      try {
        await guide.notifications.boot().timeout(
              const Duration(seconds: 3),
            );
      } catch (_) {}
    }
    if (guide.vault.shouldShowPushInvite &&
        await guide.notifications.canOfferPermission()) {
      if (!mounted) return;
      await _warmArts(PermitDeck.artAssets);
      if (!mounted) return;
      unawaited(
        nav.pushAndRemoveUntil(
          MaterialPageRoute<void>(
            builder: (_) => PermitDeck(
              vault: guide.vault,
              notifications: guide.notifications,
              nextBuilder: paneBuilder,
            ),
          ),
          (_) => false,
        ),
      );
      return;
    }
    unawaited(
      nav.pushAndRemoveUntil(
        MaterialPageRoute<void>(builder: paneBuilder),
        (_) => false,
      ),
    );
  }

  Future<void> _warmArts(List<String> assets) async {
    if (assets.isEmpty) return;
    await Future.wait<void>(
      assets.map((asset) => precacheImage(AssetImage(asset), context)),
    );
  }

  Future<void> _enterPlanner() async {
    if (_navigated) return;
    _navigated = true;
    await _goPlanner();
  }

  Future<void> _goPlanner() async {
    await SystemChrome.setPreferredOrientations(const <DeviceOrientation>[
      DeviceOrientation.portraitUp,
    ]);
    await SystemChrome.setEnabledSystemUIMode(
      SystemUiMode.edgeToEdge,
      overlays: SystemUiOverlay.values,
    );
    if (!mounted) return;
    final bool onboarded = ref.read(preferencesProvider).onboardingCompleted;
    context.go(onboarded ? '/plans' : '/welcome');
  }

  bool _navigated = false;

  void _leaveWhenReady(BootstrapState state) {
    if (_grayOwnsBar) return;
    if (!state.finished || _navigated) return;
    _navigated = true;
    unawaited(_leaveAfterMinimum());
  }

  Future<void> _leaveAfterMinimum() async {
    final DateTime started = _startedAt ?? DateTime.now();
    final Duration elapsed = DateTime.now().difference(started);
    final Duration remaining = _minimumVisible - elapsed;
    if (remaining > Duration.zero) {
      await Future<void>.delayed(remaining);
    }
    if (!mounted) return;
    await _goPlanner();
  }

  @override
  Widget build(BuildContext context) {
    final BootstrapState state = ref.watch(bootstrapProvider);
    _leaveWhenReady(state);

    final double bar = _grayOwnsBar ? _displayed : state.progress;
    final BootstrapState view = _grayOwnsBar
        ? BootstrapState(
            progress: bar,
            label: _displayed >= 0.995 ? 'Ready' : 'Starting up',
            finished: _displayed >= 0.995,
          )
        : state;

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
                      ? _WideLayout(state: view, onRetry: _start)
                      : _TallLayout(state: view, onRetry: _start),
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
    // The portrait background already carries the app title, so we do not
    // paint a second logo on top of it.
    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            SizedBox(
              height: 120,
              child: VerticalProgressTrack(value: state.progress),
            ),
            const SizedBox(width: Insets.xl),
            Expanded(
              child: _Status(state: state, onRetry: onRetry),
            ),
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
    // Landscape background already carries the title; no logo overlay.
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        SizedBox(
          height: double.infinity,
          child: VerticalProgressTrack(value: state.progress),
        ),
        const SizedBox(width: Insets.xxl),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Spacer(),
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
              Icon(
                LucideIcons.triangleAlert,
                size: 18,
                color: palette.unstable,
              ),
              const SizedBox(width: Insets.sm),
              Text(
                'Startup did not finish',
                style: AppTypography.bodyStrong.copyWith(
                  color: palette.textPrimary,
                ),
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
                style: AppTypography.caption.copyWith(
                  color: palette.textSecondary,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: Insets.sm),
            Text(
              percent(state.progress),
              style: AppTypography.metric.copyWith(
                fontSize: 18,
                color: palette.textPrimary,
              ),
            ),
          ],
        ),
        const SizedBox(height: Insets.md),
        ProgressTrack(value: state.progress),
      ],
    );
  }
}
