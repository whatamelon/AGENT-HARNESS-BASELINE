/// Rate-limiting decorator for [Haptics] — mirrors the `RedactingSink`
/// analytics decorator convention (wrap an inner port, gate before delegating).
///
/// Wraps an inner [Haptics] and suppresses repeated fires of the *same*
/// [HapticIntent] that arrive faster than a minimum interval. This stops a
/// high-frequency source (selection ticks during a fast scroll, a button that
/// emits on every pointer move) from machine-gunning the taptic engine, which
/// both feels bad and drains battery.
///
/// Time comes from an injected `clock` (`DateTime Function()`) so the throttle
/// is deterministic under test — `DateTime.now()` is never hidden inside the
/// implementation.
library;

import 'package:core/src/haptics/haptics.dart';

/// A [Haptics] decorator that drops same-intent fires within [minInterval].
class ThrottlingHaptics implements Haptics {
  /// Wraps [_inner], throttling each intent independently.
  ///
  /// [minInterval] is the minimum time that must elapse between two fires of
  /// the same intent (default [defaultMinInterval]). [clock] supplies the
  /// current time and defaults to `DateTime.now`; inject a fake clock in tests.
  ThrottlingHaptics(
    this._inner, {
    this.minInterval = defaultMinInterval,
    DateTime Function() clock = DateTime.now,
  }) : _clock = clock;

  /// Default minimum spacing between same-intent fires.
  static const Duration defaultMinInterval = Duration(milliseconds: 80);

  final Haptics _inner;

  /// Minimum spacing between two fires of the same intent.
  final Duration minInterval;

  final DateTime Function() _clock;

  /// Last accepted fire time, keyed by intent. Per-intent so a `success`
  /// pulse is never blocked by an unrelated burst of `selection` ticks.
  final Map<HapticIntent, DateTime> _lastFired = <HapticIntent, DateTime>{};

  @override
  Future<void> perform(HapticIntent intent) async {
    final now = _clock();
    final last = _lastFired[intent];
    if (last != null && now.difference(last) < minInterval) {
      return; // Too soon since the last same-intent fire — drop it.
    }
    _lastFired[intent] = now;
    await _inner.perform(intent);
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
