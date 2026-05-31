/// No-op analytics sink — the safe default when no provider is configured.
///
/// Same philosophy as `initObservability` when `AppEnv.hasSentry` is false:
/// when there is no analytics key, every call is a zero-overhead no-op rather
/// than a crash or a silent leak. Apps wire a real sink only when a key exists.
library;

import 'package:core/src/analytics/analytics_event.dart';
import 'package:core/src/analytics/analytics_sink.dart';

/// An [AnalyticsSink] that discards everything. Default sink.
class NoopSink implements AnalyticsSink {
  /// Creates a [NoopSink].
  const NoopSink();

  @override
  Future<void> logEvent(AnalyticsEvent event) async {}

  @override
  Future<void> setScreen(String name) async {}

  @override
  Future<void> setUserId(String? id) async {}
}
