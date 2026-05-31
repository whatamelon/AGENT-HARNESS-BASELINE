import 'dart:async';

import 'package:core/core.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:{{app_name}}/app.dart';
import 'package:{{app_name}}/wiring.dart';

const _logger = AppLogger(name: 'bootstrap');

/// Common startup path for every flavor entrypoint.
///
/// 1. Binds Flutter, 2. records the flavor, 3. installs observability,
/// 4. runs the app inside a guarded zone so uncaught async errors are logged.
///
/// Wiring seam: the app boots on the `core` stubs (unauthenticated
/// `authStateProvider`, no Supabase). When you connect the real backend
/// (Supabase Auth / Toss / Firebase) add the Riverpod overrides to the
/// [ProviderScope] `overrides` list below — see `wiring.dart` for the
/// integration map.
{{#haptics_enabled}}
///
/// Haptics ship ON: `hapticsProvider` is overridden with
/// `ThrottlingHaptics(PlatformHaptics(...))` so `ds`/app call sites
/// (`ref.read(hapticsProvider).success()`) get real taptic feedback out of the
/// box. The throttle decorator drops same-intent fires <80ms apart (fast-scroll
/// guard); the platform layer respects the `HapticsSettings.enabled` gate so a
/// future user "haptics off" preference mutes everything at one place.
{{/haptics_enabled}}
{{^haptics_enabled}}
///
/// Haptics is OFF: no `hapticsProvider` override, so the `core` default
/// (`NoopHaptics`) stays in place and every haptic call is a silent no-op.
{{/haptics_enabled}}
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
          {{#haptics_enabled}}
          // `Override` is not re-exported by the flutter_riverpod barrel (it is
          // sealed in riverpod 3.x); the `overrides` element type is inferred
          // from `ProviderScope.overrides`, so it stays unannotated here.
          ProviderScope(
            overrides: [
              hapticsProvider.overrideWithValue(
                ThrottlingHaptics(const PlatformHaptics()),
              ),
            ],
            child: const {{app_name.pascalCase()}}App(),
          ),
          {{/haptics_enabled}}
          {{^haptics_enabled}}
          // No overrides: the skeleton runs on the `core` stubs (incl. the
          // NoopHaptics default). Add real-backend overrides here when wiring
          // `wiring.dart`.
          const ProviderScope(
            child: {{app_name.pascalCase()}}App(),
          ),
          {{/haptics_enabled}}
        ),
      );
    },
    (error, stack) {
      _logger.error('Uncaught zone error', error: error, stackTrace: stack);
    },
  );
}
