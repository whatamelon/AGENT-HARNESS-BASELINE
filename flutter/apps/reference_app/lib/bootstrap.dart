import 'dart:async';

import 'package:core/core.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:reference_app/app.dart';

const _logger = AppLogger(name: 'bootstrap');

/// Common startup path for every flavor entrypoint.
///
/// 1. Binds Flutter, 2. records the flavor, 3. installs observability,
/// 4. runs the app inside a guarded zone so uncaught async errors are logged.
Future<void> bootstrap(Flavor flavor) async {
  WidgetsFlutterBinding.ensureInitialized();
  AppConfig.init(flavor);
  _logger.info('Booting flavor=${flavor.name} sentry=${AppEnv.hasSentry}');

  await runZonedGuarded(
    () async {
      await initObservability(
        appRunner: () async => runApp(
          const ProviderScope(child: ReferenceApp()),
        ),
      );
    },
    (error, stack) {
      _logger.error('Uncaught zone error', error: error, stackTrace: stack);
    },
  );
}
