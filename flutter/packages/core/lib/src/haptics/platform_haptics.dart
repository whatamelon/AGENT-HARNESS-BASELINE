/// Platform wiring for [Haptics] using Flutter's built-in `HapticFeedback`.
///
/// This is the only haptics file that touches a platform channel
/// (`package:flutter/services`), so it is excluded from unit tests — the rest
/// of the seam (port, noop, throttle decorator, intent mapping) is tested
/// against fakes. `HapticFeedback` has no return value to assert and routes to
/// a method channel that is unavailable under `flutter test`.
///
/// The intent→feedback mapping is the external-dependency-free baseline:
/// Android exposes only impact/selection primitives, so [HapticIntent.success]
/// / [HapticIntent.warning] / [HapticIntent.error] map onto impact strengths
/// rather than true notification haptics. Real iOS notification haptics
/// (`UINotificationFeedbackGenerator`) can be wired later via a plugin (e.g.
/// `gaimon`) by swapping this implementation — the same "defer the heavier
/// integration" pattern the cache seam uses for Hive. Call sites keep speaking
/// in [HapticIntent] and never change.
library;

import 'package:core/src/haptics/haptics.dart';
import 'package:core/src/haptics/haptics_settings.dart';
import 'package:flutter/services.dart';

/// A [Haptics] backed by Flutter's `HapticFeedback` platform channel.
///
/// Gated by [HapticsSettings]: when `settings.enabled` is `false`, every call
/// is a no-op so a global "haptics off" preference is honoured without callers
/// having to check it.
class PlatformHaptics implements Haptics {
  /// Creates a [PlatformHaptics].
  ///
  /// [settings] defaults to enabled; pass a disabled value (or a user
  /// preference) to mute all feedback at the wiring layer.
  const PlatformHaptics({this.settings = const HapticsSettings()});

  /// Enable/disable gate. When disabled, [perform] returns immediately.
  final HapticsSettings settings;

  @override
  Future<void> perform(HapticIntent intent) async {
    if (!settings.enabled) return;
    switch (intent) {
      case HapticIntent.selection:
        await HapticFeedback.selectionClick();
      case HapticIntent.light:
        await HapticFeedback.lightImpact();
      case HapticIntent.medium:
        await HapticFeedback.mediumImpact();
      case HapticIntent.heavy:
        await HapticFeedback.heavyImpact();
      case HapticIntent.success:
        // Android has no native success notification haptic — approximate with
        // a medium impact. iOS plugins can later provide the real one.
        await HapticFeedback.mediumImpact();
      case HapticIntent.warning:
        await HapticFeedback.heavyImpact();
      case HapticIntent.error:
        await HapticFeedback.heavyImpact();
    }
  }

  @override
  Future<void> selection() => perform(HapticIntent.selection);

  @override
  Future<void> light() => perform(HapticIntent.light);

  @override
  Future<void> medium() => perform(HapticIntent.medium);

  @override
  Future<void> heavy() => perform(HapticIntent.heavy);

  @override
  Future<void> success() => perform(HapticIntent.success);

  @override
  Future<void> warning() => perform(HapticIntent.warning);

  @override
  Future<void> error() => perform(HapticIntent.error);
}
