import 'dart:async';

import 'package:core/core.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:example_app/app.dart';
import 'package:example_app/wiring.dart';

const _logger = AppLogger(name: 'bootstrap');

/// Common startup path for every flavor entrypoint.
///
/// 1. Binds Flutter, 2. records the flavor, 3. installs observability,
/// 4. runs the app inside a guarded zone so uncaught async errors are logged.
///
/// Wiring seam: the app boots on the `core` stubs (unauthenticated
/// `authStateProvider`, no Supabase). When you connect the real backend
/// (Supabase Auth / Toss / Firebase) add the Riverpod overrides to the
/// [ProviderScope] below — see `wiring.dart` for the integration map.
Future<void> bootstrap(Flavor flavor) async {
  WidgetsFlutterBinding.ensureInitialized();
  AppConfig.init(flavor);
  _logger.info('Booting flavor=${flavor.name} sentry=${AppEnv.hasSentry}');

  // Wiring seam: initialize Supabase if env is present. No-op without keys, so
  // the skeleton stays green. See `wiring.dart` for the full integration map.
  await initAppBackends();

  await runZonedGuarded(
    () async {
      await initObservability(
        appRunner: () async => runApp(
          const ProviderScope(
            child: ExampleAppApp(),
          ),
        ),
      );
    },
    (error, stack) {
      _logger.error('Uncaught zone error', error: error, stackTrace: stack);
    },
  );
}
