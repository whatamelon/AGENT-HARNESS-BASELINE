import 'package:app_kit/src/chrome/route_chrome_policy.dart';
import 'package:flutter/rendering.dart' show ScrollDirection;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:meta/meta.dart';

/// Immutable chrome state owned by the single [ChromeController].
///
/// Combines the active route [policy] with the scroll-driven [visible] flag.
/// The shell reads `policy.showAppBar && visible` (and the bottom-nav
/// equivalent) to decide what to render.
@immutable
class ChromeState {
  /// Creates a [ChromeState].
  const ChromeState({
    this.policy = const RouteChromePolicy(),
    this.visible = true,
  });

  /// The active route's declarative chrome policy.
  final RouteChromePolicy policy;

  /// Whether chrome is currently shown (scroll show/hide). `true` = revealed.
  final bool visible;

  /// Returns a copy with the provided overrides.
  ChromeState copyWith({RouteChromePolicy? policy, bool? visible}) =>
      ChromeState(
        policy: policy ?? this.policy,
        visible: visible ?? this.visible,
      );

  @override
  bool operator ==(Object other) =>
      other is ChromeState &&
      other.policy == policy &&
      other.visible == visible;

  @override
  int get hashCode => Object.hash(policy, visible);
}

/// The single source of truth for app chrome: both the route policy and the
/// scroll-driven show/hide visibility live here (no separate ValueNotifier).
///
/// - [onRouteChanged] runs the injected resolver and swaps the policy,
///   resetting visibility to shown on a route change.
/// - [onScroll] toggles [ChromeState.visible] from a [ScrollDirection].
///
/// Construct the provider with [chromeControllerProvider] (built from a
/// resolver) so apps inject their own route -> policy registry.
class ChromeController extends Notifier<ChromeState> {
  /// Creates a controller bound to [_resolver].
  ChromeController(this._resolver);

  final ChromePolicyResolver _resolver;

  @override
  ChromeState build() => ChromeState(policy: _resolver('/'));

  /// Resolve and apply the policy for [fullPath]. Resets [ChromeState.visible]
  /// to `true` so chrome is revealed when the user lands on a new route.
  void onRouteChanged(String fullPath) {
    final next = _resolver(fullPath);
    if (next == state.policy && state.visible) return;
    state = state.copyWith(policy: next, visible: true);
  }

  /// Map a scroll [direction] to chrome visibility: scrolling down (reverse)
  /// hides chrome; scrolling up (forward) reveals it. [ScrollDirection.idle]
  /// leaves visibility unchanged.
  void onScroll(ScrollDirection direction) {
    switch (direction) {
      case ScrollDirection.reverse:
        if (state.visible) state = state.copyWith(visible: false);
      case ScrollDirection.forward:
        if (!state.visible) state = state.copyWith(visible: true);
      case ScrollDirection.idle:
        break;
    }
  }
}

/// Builds a [ChromeController] provider bound to a route -> policy [resolver].
///
/// Apps create one provider with their resolver and pass it to the shell. The
/// package exposes [defaultChromeControllerProvider] for the default resolver.
NotifierProvider<ChromeController, ChromeState> chromeControllerProvider(
  ChromePolicyResolver resolver,
) {
  return NotifierProvider<ChromeController, ChromeState>(
    () => ChromeController(resolver),
  );
}

/// Convenience provider using [defaultChromePolicyResolver].
final NotifierProvider<ChromeController, ChromeState>
    defaultChromeControllerProvider =
    chromeControllerProvider(defaultChromePolicyResolver);
