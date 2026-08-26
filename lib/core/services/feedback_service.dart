import 'package:audioplayers/audioplayers.dart';
import 'package:cluckfall_heights/app/providers.dart';
import 'package:cluckfall_heights/core/assets/app_assets.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Short interface sounds and haptics, both switchable in Settings.
///
/// One player is reused and pre-warmed at startup, because creating a player per
/// tap adds an audible delay on the first sound. Failures are swallowed on
/// purpose: audio is decoration here, and a silent device must never break a
/// placement the user just made.
class FeedbackService {
  FeedbackService(this._ref);

  final Ref _ref;
  final AudioPlayer _player = AudioPlayer(playerId: 'cluckfall.ui');
  bool _ready = false;

  Future<void> warmUp() async {
    if (_ready) return;
    try {
      await _player.setReleaseMode(ReleaseMode.stop);
      await _player.setVolume(0.55);
      await _player.setSource(AssetSource(_relative(SoundAsset.buttonTap)));
      _ready = true;
    } on Object {
      _ready = false;
    }
  }

  Future<void> _play(String asset) async {
    if (!_ref.read(preferencesProvider).soundEnabled) return;
    try {
      await _player.stop();
      await _player.play(AssetSource(_relative(asset)), volume: 0.55);
    } on Object {
      // Nothing to recover from; the action itself already succeeded.
    }
  }

  void _haptic(HapticKind kind) {
    if (!_ref.read(preferencesProvider).hapticsEnabled) return;
    switch (kind) {
      case HapticKind.light:
        HapticFeedback.selectionClick();
      case HapticKind.medium:
        HapticFeedback.mediumImpact();
      case HapticKind.heavy:
        HapticFeedback.heavyImpact();
    }
  }

  Future<void> tap() async {
    _haptic(HapticKind.light);
    await _play(SoundAsset.buttonTap);
  }

  Future<void> screenOpen() => _play(SoundAsset.screenOpen);

  Future<void> objectPlaced() async {
    _haptic(HapticKind.medium);
    await _play(SoundAsset.objectPlacement);
  }

  Future<void> objectRemoved() async {
    _haptic(HapticKind.light);
    await _play(SoundAsset.objectRemoval);
  }

  Future<void> saved() async {
    _haptic(HapticKind.medium);
    await _play(SoundAsset.structureSaved);
  }

  Future<void> rearranged() async {
    _haptic(HapticKind.medium);
    await _play(SoundAsset.successfulRearrangement);
  }

  Future<void> warning() async {
    _haptic(HapticKind.heavy);
    await _play(SoundAsset.stabilityWarning);
  }

  Future<void> error() async {
    _haptic(HapticKind.heavy);
    await _play(SoundAsset.error);
  }

  void dispose() => _player.dispose();

  /// audioplayers resolves asset sources relative to the assets folder.
  static String _relative(String assetPath) => assetPath.replaceFirst('assets/', '');
}

enum HapticKind { light, medium, heavy }

final Provider<FeedbackService> feedbackProvider = Provider<FeedbackService>((ref) {
  final FeedbackService service = FeedbackService(ref);
  ref.onDispose(service.dispose);
  return service;
});
