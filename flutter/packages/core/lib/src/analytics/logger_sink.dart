/// Console analytics sink for local development.
///
/// Routes events through [AppLogger] (which itself redacts PII) so a developer
/// can see analytics traffic without wiring a real provider. Not for prod —
/// production binds a real SDK adapter; this is the dev counterpart of
/// `NoopSink`.
library;

import 'package:core/src/analytics/analytics_event.dart';
import 'package:core/src/analytics/analytics_sink.dart';
import 'package:core/src/logger.dart';

/// An [AnalyticsSink] that logs events to the console via [AppLogger].
class LoggerSink implements AnalyticsSink {
  /// Creates a [LoggerSink], optionally with a custom [logger].
  const LoggerSink({AppLogger logger = const AppLogger(name: 'analytics')})
      : _logger = logger;

  final AppLogger _logger;

  @override
  Future<void> logEvent(AnalyticsEvent event) async {
    _logger.info('event ${event.name} ${event.params}');
  }

  @override
  Future<void> setScreen(String name) async {
    _logger.info('screen $name');
  }

  @override
  Future<void> setUserId(String? id) async {
    _logger.info('userId ${id ?? '(cleared)'}');
  }
}
