/// Supabase-backed implementation of core's `AuthController`.
///
/// This is the heart of P3: the P2 shell/redirect code reads only
/// `authStateProvider` (the §8-B one-way boundary). The app injects this
/// controller via a `ProviderScope` override of `authStateProvider`, so no
/// shell/router code changes — the boundary stays one-way.
///
/// The controller subscribes to GoTrue `onAuthStateChange` and maps each event
/// to core's coarse `AuthState` (unknown / authenticated / unauthenticated).
/// Social sign-in delegates to [AppleAuthService] / [KakaoAuthService], then
/// exchanges the resulting [IdTokenCredential] via `signInWithIdToken`.
///
/// Three session-hardening behaviours layered on top (§5.3-5.4):
///  1. Cold-start `unknown` seeding — when no current user but a restorable
///     session exists on disk, seed `AuthStatus.unknown` (router shows splash)
///     until the first `onAuthStateChange` resolves. Removes flash-of-login.
///  2. Stream `onError` — captures retryable refresh errors WITHOUT signing the
///     user out (gotrue emits these via `addError`, not a `signedOut` event).
///  3. Forced-vs-expected sign-out — a `signedOut` event that the user did not
///     request (refresh expired/revoked) raises `sessionExpired` so the UI can
///     show "세션이 만료되었습니다" and preserve the intended destination, vs an
///     intentional `signOut` which is silent.
///
/// Observability is a no-op port by default (`AuthBreadcrumb`); the host wires
/// a real sink (e.g. Sentry breadcrumbs). It NEVER receives a token or session
/// object — only coarse event labels.
library;

import 'dart:async';

import 'package:app_kit/src/auth/auth_ports.dart';
import 'package:app_kit/src/auth/social/apple_auth.dart';
import 'package:app_kit/src/auth/social/kakao_auth.dart';
import 'package:core/core.dart' as core;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gotrue/gotrue.dart' as gotrue;

/// Observer port for auth breadcrumbs (token-free).
///
/// Receives coarse, non-sensitive event labels only (e.g. `tokenRefreshed`,
/// `forcedSignOut`, `refreshError`). The default is a no-op so unit tests and
/// flavors without an observability backend stay silent; the host injects a
/// real sink (Sentry breadcrumb, etc). NEVER log a token or session object.
typedef AuthBreadcrumb = void Function(String event);

void _noopBreadcrumb(String event) {}

/// Riverpod [core.AuthController] backed by Supabase/GoTrue.
class SupabaseAuthController extends core.AuthController {
  /// [clock] is a test/DI seam so tests can control the timestamp window
  /// without real wall-clock delays. Defaults to [DateTime.now] in production.
  SupabaseAuthController({DateTime Function()? clock})
      : _now = clock ?? DateTime.now;

  // ── Clock seam ────────────────────────────────────────────────────────────

  /// Clock function; final so it cannot be mutated after construction.
  final DateTime Function() _now;

  /// How long after [signOut] is called a `signedOut` event is still
  /// considered intentional. 5 s covers any realistic network round-trip.
  static const Duration _signOutWindow = Duration(seconds: 5);

  // ── Port factories (DI seams) ─────────────────────────────────────────────

  /// Test/DI seam: supplies the ports. Defaults are filled by [build] in
  /// production from the live Supabase instance.
  GoTrueAuthPort Function()? _goTrueFactory;
  AppleAuthService Function()? _appleFactory;
  KakaoAuthService Function()? _kakaoFactory;
  AuthBreadcrumb _breadcrumb = _noopBreadcrumb;

  GoTrueAuthPort? _goTrue;
  StreamSubscription<gotrue.AuthState>? _sub;

  /// Timestamp set when [signOut] is called. A subsequent `signedOut` event is
  /// treated as intentional only if it arrives within [_signOutWindow] of this
  /// timestamp. This bounds the race window where a remote token revoke fires a
  /// `signedOut` event concurrently with a user-initiated signOut() call,
  /// preventing the forced-expiry UX signal from being silently suppressed.
  DateTime? _expectedSignOutAt;

  /// Whether the last sign-out was forced (refresh expired/revoked) rather than
  /// user-initiated. Read-only signal for the UI; reset by
  /// [acknowledgeSessionExpired] or a successful re-auth. Kept off
  /// `core.AuthState` to keep it pure (§8-B).
  bool _sessionExpired = false;

  /// Whether the session was force-terminated (expired/revoked refresh token).
  ///
  /// The UI watches [sessionExpiredProvider] to surface a "세션이 만료되었습니다"
  /// message and route to login while preserving the intended destination.
  bool get sessionExpired => _sessionExpired;

  /// Configures the ports used by this controller.
  ///
  /// Call before the provider is first read (e.g. when building the override).
  /// In production, pass `SupabaseGoTruePort` / SDK-backed social services and
  /// optionally a [breadcrumb] sink (token-free).
  void configure({
    required GoTrueAuthPort Function() goTrue,
    required AppleAuthService Function() apple,
    required KakaoAuthService Function() kakao,
    AuthBreadcrumb? breadcrumb,
  }) {
    _goTrueFactory = goTrue;
    _appleFactory = apple;
    _kakaoFactory = kakao;
    _breadcrumb = breadcrumb ?? _noopBreadcrumb;
  }

  @override
  core.AuthState build() {
    final factory = _goTrueFactory;
    if (factory == null) {
      // Not configured (e.g. a flavor without Supabase): stay signed out.
      return core.AuthState.unauthenticated;
    }
    final goTrue = _goTrue = factory();

    _sub = goTrue.onAuthStateChange.listen(_onAuthEvent, onError: _onAuthError);
    ref.onDispose(() {
      unawaited(_sub?.cancel());
      _sub = null;
    });

    // Seed from any restored session before the first stream event lands.
    final userId = goTrue.currentUserId;
    if (userId != null) {
      return core.AuthState.authenticated(userId);
    }
    // No current user yet. If a session exists on disk the SDK is still
    // replaying `initialSession`; seed `unknown` so the router shows splash
    // instead of flashing the login screen (§5.3/§13.6). Otherwise the user is
    // genuinely signed out.
    return goTrue.hasRestorableSession
        ? core.AuthState.unknown
        : core.AuthState.unauthenticated;
  }

  void _onAuthEvent(gotrue.AuthState event) {
    final userId = event.session?.user.id;
    switch (event.event) {
      case gotrue.AuthChangeEvent.signedOut:
        _onSignedOut();
      case gotrue.AuthChangeEvent.tokenRefreshed:
        _breadcrumb('tokenRefreshed');
        _applySession(userId);
      case gotrue.AuthChangeEvent.signedIn:
      case gotrue.AuthChangeEvent.userUpdated:
      case gotrue.AuthChangeEvent.initialSession:
        _applySession(userId);
      case gotrue.AuthChangeEvent.passwordRecovery:
      case gotrue.AuthChangeEvent.mfaChallengeVerified:
      // userDeleted is deprecated in gotrue 2.20 but must stay in the switch
      // for exhaustiveness; it never fires in practice.
      // ignore: deprecated_member_use
      case gotrue.AuthChangeEvent.userDeleted:
        // These events don't change the coarse auth state.
        break;
    }
  }

  /// Applies a session-bearing event to coarse state, clearing any prior
  /// expiry flag once a real user id is present.
  void _applySession(String? userId) {
    if (userId != null) _sessionExpired = false;
    state = userId == null
        ? core.AuthState.unauthenticated
        : core.AuthState.authenticated(userId);
  }

  void _onSignedOut() {
    // Consume the timestamp on first use so a second signedOut (e.g. a revoke
    // racing closely after an intentional signOut) is treated as forced rather
    // than silently swallowing the expiry signal.
    final signOutAt = _expectedSignOutAt;
    _expectedSignOutAt = null;

    final isExpected = signOutAt != null &&
        _now().difference(signOutAt) <= _signOutWindow;

    if (isExpected) {
      // User asked for it: silent.
      _sessionExpired = false;
      _breadcrumb('signOut');
    } else {
      // Refresh expired/revoked (gotrue emits `signedOut` on a non-retryable
      // refresh failure, gotrue_client.dart:1402-1411). Flag it so the UI can
      // explain and preserve the intended destination.
      _sessionExpired = true;
      _breadcrumb('forcedSignOut');
    }
    state = core.AuthState.unauthenticated;
  }

  /// Captures retryable refresh errors surfaced via the stream's error channel
  /// (gotrue `addError`, gotrue_client.dart:1442). These do NOT sign the user
  /// out — the SDK will retry — so state is left unchanged; we only breadcrumb.
  void _onAuthError(Object error, StackTrace stackTrace) {
    // Never log the error object itself (it may embed request details); a
    // coarse label is enough for the breadcrumb trail.
    _breadcrumb('refreshError');
  }

  /// Clears the [sessionExpired] flag after the UI has shown the message.
  void acknowledgeSessionExpired() => _sessionExpired = false;

  /// Apple → Supabase. Surfaces failures by leaving state unchanged and
  /// rethrowing so the UI layer can render a message.
  Future<void> signInWithApple() async {
    final apple = _appleFactory?.call();
    final goTrue = _goTrue;
    if (apple == null || goTrue == null) {
      throw StateError('auth-not-configured');
    }
    final credential = await apple.signIn();
    await goTrue.signInWithIdToken(credential);
  }

  /// Kakao → Supabase.
  Future<void> signInWithKakao() async {
    final kakao = _kakaoFactory?.call();
    final goTrue = _goTrue;
    if (kakao == null || goTrue == null) {
      throw StateError('auth-not-configured');
    }
    final credential = await kakao.signIn();
    await goTrue.signInWithIdToken(credential);
  }

  @override
  Future<void> signOut() async {
    // Stamp the time so the resulting `signedOut` event is treated as
    // intentional only within [_signOutWindow]. Using a timestamp rather than
    // a boolean prevents a concurrent remote revoke from being silently
    // mislabelled as expected: the window self-expires and consume-on-event
    // clears it on first use.
    _expectedSignOutAt = _now();
    try {
      await _goTrue?.signOut();
    } catch (_) {
      // The event may not arrive if sign-out fails; clear the window so a
      // later forced expiry is not mislabelled.
      _expectedSignOutAt = null;
      rethrow;
    }
  }
}

/// Read-only "session was force-expired" signal for the UI (§5.4).
///
/// Stays separate from `core.authStateProvider` to keep `core.AuthState` pure
/// (§8-B): consumers that need the expiry reason watch this; the redirect logic
/// only ever needs the coarse `authStateProvider`. The app overrides this with
/// `sessionExpiredProvider.overrideWith(...)` bound to its controller instance,
/// or reads the controller's [SupabaseAuthController.sessionExpired] directly.
final Provider<bool> sessionExpiredProvider = Provider<bool>((ref) => false);
