/// Selective auth-gate policy (§5.5).
///
/// Pure data + a resolver function, mirroring the chrome policy resolver
/// pattern: the app owns the route -> level mapping (park is contractor-only,
/// onyu is guest-first), so the package never hardcodes which paths are public.
/// The router's redirect consumes a [RouteAuthPolicy] to decide gating.
library;

import 'package:meta/meta.dart';

/// Auth requirement for a route.
enum RouteAuthLevel {
  /// Never gated. Onyu emergency / funeral-guide / notices stay reachable for
  /// guests (guest-first). The redirect always lets these through.
  public,

  /// Requires an authenticated session. Unauthenticated users are sent to the
  /// login path with the intended destination preserved as `?redirect=`.
  protected,

  /// Requires authentication *and* a fresh re-auth at the action layer (e.g.
  /// biometric/server reauth before a high-risk action). For *routing* this
  /// behaves like [protected]; the step-up itself is enforced in the action
  /// layer, not the redirect (§5.5).
  stepUp,
}

/// Signature for the app-injected route -> auth-level resolver.
///
/// Given a router `fullPath`, return its [RouteAuthLevel]. See
/// [RouteAuthPolicy.levelFor].
typedef RouteAuthLevelResolver = RouteAuthLevel Function(String fullPath);

/// Immutable selective-gate policy for the router redirect.
///
/// Holds the app's [levelFor] resolver plus the login/splash paths the redirect
/// needs. Construct one per app and pass it to `buildAppRouter`.
@immutable
class RouteAuthPolicy {
  /// Creates a [RouteAuthPolicy].
  const RouteAuthPolicy({
    required this.levelFor,
    this.loginPath = '/login',
    this.splashPath = '/splash',
  });

  /// Resolves the [RouteAuthLevel] for a given router `fullPath`.
  final RouteAuthLevel Function(String fullPath) levelFor;

  /// Path of the login screen used when gating an unauthenticated user.
  final String loginPath;

  /// Path of the splash screen held while auth status is unknown
  /// (session restore in flight).
  final String splashPath;
}
