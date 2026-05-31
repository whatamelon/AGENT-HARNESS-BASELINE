import 'package:app_kit/src/chrome/chrome_controller.dart';
import 'package:app_kit/src/router/route_policy.dart';
import 'package:app_kit/src/shell/app_shell.dart';
import 'package:app_kit/src/shell/shell_branch.dart';
import 'package:core/core.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// Builds the app [GoRouter] for a set of tab [branches].
///
/// Integration notes (go_router x Riverpod, build-during-build safe):
/// - Uses [StatefulShellRoute.indexedStack] so each tab keeps an independent
///   [Navigator] and its state (scroll offset, form input) survives tab swaps.
/// - The shell builder constructs [AppShell] and passes the active `fullPath`.
///   The shell pushes that path into the [ChromeController] from a
///   post-frame callback (never synchronously during build).
/// - The router `redirect` only *reads* [authStateProvider] (read-only
///   surface, no mutation), so it is safe to call during route resolution
///   (§8-B one-way boundary preserved).
/// - The router `refreshListenable` is bridged to [authStateProvider] so the
///   router re-evaluates redirects when auth changes.
///
/// Selective auth gate (§5.5): when [routePolicy] is supplied the redirect
/// enforces it — hold on splash while auth is `unknown`, never gate `public`
/// routes (onyu guest-first), and send unauthenticated users hitting a
/// `protected`/`stepUp` route to `loginPath?redirect=<dest>`. When
/// [routePolicy] is `null` the redirect stays permissive (backward compatible
/// with existing callers/tests).
///
/// Cross-session restoration (§3.2): pass [restorationScopeId] to enable
/// go_router state restoration. It is threaded into the [GoRouter], the
/// [StatefulShellRoute.indexedStack], and every [StatefulShellBranch] (each
/// branch gets a distinct id) — go_router 17 requires the shell route to carry
/// an id whenever any branch sets one.
///
/// [chromeProvider] is the controller provider the shell + `ChromeScroll`
/// share (build it from the app's resolver via [chromeControllerProvider]).
GoRouter buildAppRouter({
  required Ref ref,
  required List<ShellBranch> branches,
  required NotifierProvider<ChromeController, ChromeState> chromeProvider,
  String? loginPath,
  RootRoutesBuilder? extraRoutes,
  String? restorationScopeId,
  RouteAuthPolicy? routePolicy,
}) {
  assert(branches.isNotEmpty, 'router needs at least one tab branch');

  final rootKey = GlobalKey<NavigatorState>(debugLabel: 'rootNav');
  final refresh = _AuthRefreshListenable(ref);
  ref.onDispose(refresh.dispose);
  final restorationEnabled = restorationScopeId != null;

  return GoRouter(
    navigatorKey: rootKey,
    initialLocation: branches.first.path,
    refreshListenable: refresh,
    restorationScopeId: restorationScopeId,
    redirect: (context, state) => _resolveRedirect(
      auth: ref.read(authStateProvider),
      location: state.matchedLocation,
      uri: state.uri,
      branches: branches,
      loginPath: loginPath,
      policy: routePolicy,
    ),
    routes: [
      StatefulShellRoute.indexedStack(
        restorationScopeId: restorationEnabled ? 'shell' : null,
        builder: (context, state, navigationShell) {
          return AppShell(
            navigationShell: navigationShell,
            branches: branches,
            controllerProvider: chromeProvider,
            fullPath: state.fullPath ?? state.matchedLocation,
          );
        },
        branches: [
          for (final branch in branches)
            StatefulShellBranch(
              restorationScopeId:
                  restorationEnabled ? 'branch_${branch.path}' : null,
              routes: [
                GoRoute(
                  path: branch.path,
                  builder: (context, state) => branch.builder(context),
                ),
              ],
            ),
        ],
      ),
      // App-provided full-screen routes (e.g. detail) pushed on the root
      // navigator so the shell + bottom nav are not in the tree.
      ...?extraRoutes?.call(rootKey),
    ],
  );
}

/// Computes the redirect target for the current [location], or `null` to stay.
///
/// Pure function of the read-only [auth] snapshot + the app's [policy] so it is
/// trivially testable and safe to call during route resolution. Order matters:
/// 1. `unknown` -> hold on splash (flash-of-login guard, §5.3); already on
///    splash -> stay.
/// 2. settled + sitting on splash -> leave to the first branch.
/// 3. authenticated + sitting on login -> decode `?redirect=` or first branch.
/// 4. `public` level -> never gate (onyu guest-first).
/// 5. `protected`/`stepUp` + unauthenticated -> `loginPath?redirect=<dest>`.
///
/// Step-up re-auth is enforced in the action layer, not here (§5.5).
String? _resolveRedirect({
  required AuthState auth,
  required String location,
  required Uri uri,
  required List<ShellBranch> branches,
  required String? loginPath,
  required RouteAuthPolicy? policy,
}) {
  final home = branches.first.path;

  // No policy: keep the permissive legacy behavior (only bounce an
  // authenticated user off the login screen).
  if (policy == null) {
    if (auth.isAuthenticated &&
        loginPath != null &&
        location == loginPath) {
      return home;
    }
    return null;
  }

  // (a) Auth status not yet resolved: hold on splash to avoid a login flash.
  if (auth.status == AuthStatus.unknown) {
    return location == policy.splashPath ? null : policy.splashPath;
  }

  // (b) Settled while parked on splash: move on to the first branch.
  if (location == policy.splashPath) {
    return home;
  }

  // (c) Authenticated user sitting on login: honor an intended destination.
  if (auth.isAuthenticated && location == policy.loginPath) {
    final dest = uri.queryParameters['redirect'];
    if (dest != null && dest.isNotEmpty) return dest;
    return home;
  }

  // (c2) Already on the login screen (unauthenticated): let them log in.
  if (location == policy.loginPath) {
    return null;
  }

  final level = policy.levelFor(location);

  // (d) Public routes are never gated (onyu guest-first).
  if (level == RouteAuthLevel.public) {
    return null;
  }

  // (e) Protected/stepUp + unauthenticated: gate to login, preserving dest.
  if (!auth.isAuthenticated) {
    final encoded = Uri.encodeQueryComponent(location);
    return '${policy.loginPath}?redirect=$encoded';
  }

  // Authenticated on a gated route, or step-up (action-layer concern): stay.
  return null;
}

/// Signature for app-provided root-level routes. Receives the router's root
/// [NavigatorState] key so full-screen routes can set `parentNavigatorKey` and
/// thereby render outside the shell (no bottom nav).
typedef RootRoutesBuilder = List<RouteBase> Function(
  GlobalKey<NavigatorState> rootKey,
);

/// Bridges [authStateProvider] to a [Listenable] for the router's
/// `refreshListenable`.
///
/// Listens to the provider and notifies go_router on every auth change, so
/// redirects re-run. Read-only: it never mutates auth state.
class _AuthRefreshListenable extends ChangeNotifier {
  _AuthRefreshListenable(this._ref) {
    _sub = _ref.listen<AuthState>(
      authStateProvider,
      (_, __) => notifyListeners(),
    );
  }

  final Ref _ref;
  late final ProviderSubscription<AuthState> _sub;

  @override
  void dispose() {
    _sub.close();
    super.dispose();
  }
}
