import 'dart:async';

import 'package:alchemist/alchemist.dart';

/// Alchemist global config for ds goldens.
///
/// Platform goldens (real-font, host-OS rendering) are disabled so the only
/// committed goldens are the deterministic, font-blocked "ci" set — these match
/// on any machine (local macOS, Linux CI) without font-rendering drift.
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  return AlchemistConfig.runWithConfig(
    config: const AlchemistConfig(
      platformGoldensConfig: PlatformGoldensConfig(enabled: false),
    ),
    run: testMain,
  );
}
