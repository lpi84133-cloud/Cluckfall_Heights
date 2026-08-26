import 'dart:async';

import 'package:cluckfall_heights/app/providers.dart';
import 'package:cluckfall_heights/core/assets/app_assets.dart';
import 'package:cluckfall_heights/core/services/feedback_service.dart';
import 'package:cluckfall_heights/domain/analysis/stability_analyzer.dart';
import 'package:cluckfall_heights/domain/structures/structure.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:meta/meta.dart';

/// One unit of startup work.
///
/// [weight] is a rough share of the total time the step takes, so the bar moves
/// at a believable pace: opening the database is quick, decoding twelve sprites
/// is not, and giving them equal weight is what produces a bar that races to 90%
/// and then sits there.
@immutable
class _Step {
  const _Step({required this.label, required this.weight, required this.run});

  final String label;
  final double weight;
  final Future<void> Function() run;
}

@immutable
class BootstrapState {
  const BootstrapState({
    this.progress = 0,
    this.label = 'Starting up',
    this.finished = false,
    this.error,
  });

  /// Real fraction of the startup work that has completed, 0 to 1.
  final double progress;

  /// What is happening right now, so the number is accountable.
  final String label;

  /// Only ever true once every step has actually finished.
  final bool finished;

  final String? error;

  bool get failed => error != null;
}

/// Runs startup and reports honest progress.
///
/// The bar is driven by completed work, never by a timer. There is no artificial
/// delay, no padding to make the screen linger, and no cap short of 100: the last
/// step sets it to exactly 1 and the app moves on. If a step fails, the screen
/// says so and offers a retry instead of holding at some percentage forever.
class BootstrapController extends Notifier<BootstrapState> {
  /// A step that has not answered in this long is treated as failed rather than
  /// left to hold the bar in place. Generous enough that a cold start on an old
  /// device finishes well inside it, short enough that a user is not left staring
  /// at a frozen percentage.
  static const Duration stepTimeout = Duration(seconds: 15);

  @override
  BootstrapState build() => const BootstrapState();

  /// [precache] is supplied by the screen, because decoding an image into the
  /// widget layer needs a build context.
  Future<void> run({required Future<void> Function(String asset) precache}) async {
    state = const BootstrapState(label: 'Starting up');

    final List<_Step> steps = [
      _Step(
        label: 'Opening your local data',
        weight: 2,
        run: () => ref.read(localStoreProvider.future),
      ),
      _Step(
        label: 'Reading your settings',
        weight: 0.5,
        run: () async {
          ref.read(preferencesProvider);
          ref.read(objectLibraryProvider);
        },
      ),
      _Step(
        label: 'Preparing the interface',
        weight: 1.5,
        run: () async {
          for (final String asset in BrandArt.all) {
            await precache(asset);
          }
          for (final String asset in IndicatorArt.all) {
            await precache(asset);
          }
        },
      ),
      _Step(
        label: 'Loading the object library',
        weight: 3,
        run: () async {
          for (final String asset in ObjectArt.all) {
            await precache(asset);
          }
        },
      ),
      _Step(
        label: 'Loading backdrops',
        weight: 2,
        run: () async {
          for (final String asset in BackgroundArt.all) {
            await precache(asset);
          }
        },
      ),
      _Step(
        label: 'Checking your saved plans',
        weight: 1,
        run: () async {
          // Real work, not a placeholder: every saved plan is analysed here so
          // the home screen can show its status immediately instead of computing
          // twelve reports during its first frame.
          for (final Structure structure in ref.read(structuresProvider)) {
            StabilityAnalyzer.analyse(structure);
          }
        },
      ),
      _Step(
        label: 'Warming up sound',
        weight: 0.5,
        run: () => ref.read(feedbackProvider).warmUp(),
      ),
    ];

    final double total = steps.fold<double>(0, (sum, step) => sum + step.weight);
    double done = 0;

    for (final _Step step in steps) {
      state = BootstrapState(progress: done / total, label: step.label);
      try {
        await step.run().timeout(stepTimeout);
      } on TimeoutException {
        state = BootstrapState(
          progress: done / total,
          label: step.label,
          error:
              'Step "${step.label.toLowerCase()}" is not responding. This is usually '
              'temporary.',
        );
        return;
      } on Object catch (error) {
        state = BootstrapState(
          progress: done / total,
          label: step.label,
          error: 'Could not finish "${step.label.toLowerCase()}". $error',
        );
        return;
      }
      done += step.weight;
      state = BootstrapState(progress: done / total, label: step.label);
    }

    state = const BootstrapState(progress: 1, label: 'Ready', finished: true);
  }
}

final NotifierProvider<BootstrapController, BootstrapState> bootstrapProvider =
    NotifierProvider<BootstrapController, BootstrapState>(BootstrapController.new);
