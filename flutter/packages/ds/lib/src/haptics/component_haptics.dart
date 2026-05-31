/// Internal seam that lets ds interactive components fire semantic haptics
/// without forcing a `ProviderScope` ancestor onto every call site.
///
/// Design constraint (non-negotiable): wiring haptics must change **zero**
/// existing behaviour. `core` ships [hapticsProvider] bound to `NoopHaptics`,
/// so when an app does not override it the fire is a no-op. But ds components
/// are also rendered in contexts with *no* `ProviderScope` at all (golden
/// tests, embedding into a non-Riverpod tree). `ProviderScope.containerOf`
/// throws `StateError('No ProviderScope found')` in that case, which would turn
/// a "decoration" into a crash.
///
/// [componentHaptics] resolves the provider when a scope is present and falls
/// back to a shared [NoopHaptics] when it is not — so the contract is uniform:
/// *no override or no scope ⇒ silent, exactly as before*. Reads use
/// `listen: false`, so they register no dependency and never trigger a rebuild;
/// they are only ever called from interaction handlers (onTap/onChanged), not
/// from `build`.
library;

import 'dart:async';

import 'package:core/core.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Shared no-op fallback used when there is no enclosing [ProviderScope].
const Haptics _fallback = NoopHaptics();

/// Resolves the [Haptics] implementation for [context].
///
/// Returns the override from the nearest [ProviderScope] when one exists,
/// otherwise [NoopHaptics]. Never throws and never registers a rebuild
/// dependency, so it is safe to call from gesture/value-change callbacks.
Haptics componentHaptics(BuildContext context) {
  try {
    return ProviderScope.containerOf(context, listen: false).read(
      hapticsProvider,
    );
    // No ProviderScope in this tree (e.g. golden tests). Riverpod signals
    // "no scope" with a StateError; catching it is intentional — letting it
    // propagate would turn best-effort decoration into a crash. Stay silent.
    // ignore: avoid_catching_errors
  } on StateError {
    return _fallback;
  }
}

/// Fires [intent] on the haptics resolved for [context], discarding the future.
///
/// Haptics is best-effort decoration that must never block or throw on the
/// calling flow, so the returned future is intentionally not awaited.
void fireHaptic(BuildContext context, HapticIntent intent) {
  unawaited(componentHaptics(context).perform(intent));
}
