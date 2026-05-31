/// Haptics enable/disable gate + the read-only Riverpod surface for [Haptics].
///
/// Same "default no-op, app turns it on" shape as `authStateProvider` and the
/// `initObservability` Sentry gate: `core` ships [hapticsProvider] bound to
/// [NoopHaptics], and an app opts in by overriding it in `ProviderScope` with a
/// real implementation. [HapticsSettings] is the config gate the platform
/// wiring consults so a global "haptics off" preference is honoured at one
/// place.
library;

import 'package:core/src/haptics/haptics.dart';
import 'package:core/src/haptics/noop_haptics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:meta/meta.dart';

/// Immutable haptics configuration gate.
///
/// `PlatformHaptics` consults [enabled]; when `false` every fire is suppressed
/// at the wiring layer so callers never have to branch on a user preference.
@immutable
class HapticsSettings {
  /// Creates a [HapticsSettings]. Haptics are [enabled] by default.
  const HapticsSettings({this.enabled = true});

  /// Whether haptic feedback is allowed to fire.
  final bool enabled;

  @override
  bool operator ==(Object other) =>
      other is HapticsSettings && other.enabled == enabled;

  @override
  int get hashCode => enabled.hashCode;
}

/// The read-only [Haptics] surface for the rest of the app.
///
/// Defaults to [NoopHaptics] so nothing fires until an app opts in. Apps wire
/// real feedback via a `ProviderScope` override, e.g.:
///
/// ```dart
/// ProviderScope(
///   overrides: [
///     hapticsProvider.overrideWithValue(
///       ThrottlingHaptics(const PlatformHaptics()),
///     ),
///   ],
///   child: const MyApp(),
/// );
/// ```
///
/// Consumers read this provider and call `ref.read(hapticsProvider).success()`
/// without knowing whether haptics is noop, platform, or throttled.
final Provider<Haptics> hapticsProvider =
    Provider<Haptics>((ref) => const NoopHaptics());
