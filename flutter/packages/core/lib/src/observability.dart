import 'dart:async';

import 'package:core/src/env.dart';
import 'package:core/src/flavor.dart';
import 'package:core/src/logger.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

const _logger = AppLogger(name: 'observability');

/// Initializes crash/error reporting, then runs [appRunner].
///
/// If [AppEnv.sentryDsn] is empty (e.g. local dev), Sentry is skipped entirely
/// and [appRunner] is executed directly — no-op observability, zero overhead.
Future<void> initObservability({
  required FutureOr<void> Function() appRunner,
}) async {
  if (!AppEnv.hasSentry) {
    _logger.info('Sentry DSN not set — observability disabled (no-op).');
    await appRunner();
    return;
  }

  await SentryFlutter.init(
    (options) {
      options
        ..dsn = AppEnv.sentryDsn
        ..environment = AppConfig.isInitialized
            ? AppConfig.current.name
            : Flavor.dev.name
        ..tracesSampleRate = AppConfig.isInitialized && AppConfig.current.isProd
            ? 0.2
            : 1.0;
    },
    appRunner: () async => appRunner(),
  );
}
