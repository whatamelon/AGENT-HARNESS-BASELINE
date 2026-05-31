/// No-op haptics — the safe default when no haptics provider is wired.
///
/// Same philosophy as `NoopSink` for analytics: when the app has not opted in
/// to haptics (or runs on a platform without them), every call is a
/// zero-overhead no-op rather than a crash. Apps wire a real [Haptics] only
/// when they want physical feedback.
library;

import 'package:core/src/haptics/haptics.dart';

/// A [Haptics] that performs no feedback. Default haptics.
///
/// Only [perform] is overridden — the `Haptics` convenience methods
/// (`selection()`, `success()`, ...) delegate to it, so every entry point is a
/// no-op without restating each one.
class NoopHaptics implements Haptics {
  /// Creates a [NoopHaptics].
  const NoopHaptics();

  @override
  Future<void> perform(HapticIntent intent) async {}

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
