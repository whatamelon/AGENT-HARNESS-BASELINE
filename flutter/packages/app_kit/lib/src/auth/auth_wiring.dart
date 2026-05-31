/// Production wiring: binds the auth ports to the real SDKs and exposes a
/// secure `Supabase.initialize` helper.
///
/// This file is the only place that imports the social/secure SDKs against a
/// live runtime; it is intentionally excluded from unit tests (which use the
/// port fakes). P3-integration (key arrival) exercises it end-to-end.
library;

import 'package:app_kit/src/auth/auth_ports.dart';
import 'package:app_kit/src/auth/secure_session_storage.dart';
import 'package:kakao_flutter_sdk_user/kakao_flutter_sdk_user.dart' as kakao;
import 'package:sign_in_with_apple/sign_in_with_apple.dart' as apple;
import 'package:supabase_flutter/supabase_flutter.dart' as sb;

/// [GoTrueAuthPort] over the live `supabase.auth` client.
class SupabaseGoTruePort implements GoTrueAuthPort {
  /// Creates a [SupabaseGoTruePort].
  ///
  /// [hasRestorableSession] is the snapshot of `LocalStorage.hasAccessToken`
  /// taken once during `initSupabaseSecure`; it lets the controller distinguish
  /// a true signed-out boot from a session-restore-in-flight boot.
  SupabaseGoTruePort(this._auth, {bool hasRestorableSession = false})
      : _hasRestorableSession = hasRestorableSession;

  /// Builds from the global Supabase instance.
  ///
  /// [hasRestorableSession] is supplied by `initSupabaseSecure` (it read the
  /// secure store before the SDK finished replaying `initialSession`).
  factory SupabaseGoTruePort.instance({bool hasRestorableSession = false}) =>
      SupabaseGoTruePort(
        sb.Supabase.instance.client.auth,
        hasRestorableSession: hasRestorableSession,
      );

  final sb.GoTrueClient _auth;
  final bool _hasRestorableSession;

  @override
  Stream<sb.AuthState> get onAuthStateChange => _auth.onAuthStateChange;

  @override
  String? get currentUserId => _auth.currentUser?.id;

  @override
  bool get hasRestorableSession => _hasRestorableSession;

  @override
  Future<void> signInWithIdToken(IdTokenCredential credential) async {
    await _auth.signInWithIdToken(
      provider: credential.provider,
      idToken: credential.idToken,
      nonce: credential.rawNonce,
      accessToken: credential.accessToken,
    );
  }

  @override
  Future<void> signOut() => _auth.signOut();
}

/// [AppleCredentialPort] over `sign_in_with_apple`.
class SignInWithApplePort implements AppleCredentialPort {
  /// Creates a [SignInWithApplePort].
  const SignInWithApplePort();

  @override
  Future<String?> getAppleIdToken({required String nonce}) async {
    final credential = await apple.SignInWithApple.getAppleIDCredential(
      scopes: const [
        apple.AppleIDAuthorizationScopes.email,
        apple.AppleIDAuthorizationScopes.fullName,
      ],
      nonce: nonce,
    );
    return credential.identityToken;
  }
}

/// [KakaoLoginPort] over `kakao_flutter_sdk_user`.
///
/// Prefers the KakaoTalk app when installed, falling back to the account web
/// flow. Requests an OIDC `idToken` (Kakao app must have OIDC enabled).
class KakaoLoginAdapter implements KakaoLoginPort {
  /// Creates a [KakaoLoginAdapter].
  const KakaoLoginAdapter();

  @override
  Future<String?> getKakaoIdToken() async {
    final talkInstalled = await kakao.isKakaoTalkInstalled();
    final token = talkInstalled
        ? await kakao.UserApi.instance.loginWithKakaoTalk()
        : await kakao.UserApi.instance.loginWithKakaoAccount();
    return token.idToken;
  }
}

/// Cold-start snapshot of whether a restorable session exists on disk.
///
/// `initSupabaseSecure` reads the secure session store ONCE right after
/// `Supabase.initialize` (before the SDK has finished replaying
/// `initialSession`) and records the result here. The auth controller reads
/// [hasRestorableSession] synchronously in `build()` to seed
/// `AuthStatus.unknown` instead of flashing `unauthenticated` (§5.3/§13.6).
///
/// This is a tiny boot-time fact, not app state — kept off `core.AuthState`
/// (which stays pure, §8-B). Tests reset it via [reset].
class SupabaseSessionBootstrap {
  SupabaseSessionBootstrap._();

  /// Whether the secure store held a session at init time.
  ///
  /// Set by [initSupabaseSecure]; read synchronously by the auth controller.
  static bool hasRestorableSession = false;

  /// Resets to the default (no restorable session) — for tests.
  static void reset() {
    hasRestorableSession = false;
  }
}

/// Initializes Supabase with H-5 secure session + PKCE storage.
///
/// This is the ONLY allowed call site for `Supabase.initialize` in the whole
/// workspace (§5.1) — a CI guard (`tool/guard_supabase_init.sh`) fails the
/// build if `Supabase.initialize` appears anywhere else, so the insecure
/// plaintext path can never be reintroduced silently.
///
/// PKCE (`authFlowType: pkce`) and `autoRefreshToken: true` are set explicitly
/// (§13.6/§5.1) rather than relying on SDK defaults, so the security posture is
/// visible at the wiring site and survives an SDK default change. Verified
/// against supabase_flutter 2.12.4 `FlutterAuthClientOptions`
/// (lib/src/flutter_go_true_client_options.dart) + gotrue 2.20.0 `AuthFlowType`
/// (lib/src/types/types.dart) / `AuthClientOptions.autoRefreshToken`.
///
/// After init it snapshots [SecureSessionStorage.hasAccessToken] into
/// [SupabaseSessionBootstrap] so the controller can seed `unknown` on cold
/// start. Only the publishable anon key is embedded (§8-A H-4). Returns `false`
/// when Supabase env is absent (safe no-op for non-Supabase flavors/tests).
Future<bool> initSupabaseSecure({
  required String url,
  required String anonKey,
  SecureKeyValueStore? store,
}) async {
  if (url.isEmpty || anonKey.isEmpty) return false;
  final secure = store ?? const FlutterSecureKeyValueStore();
  final sessionStorage = SecureSessionStorage(store: secure);
  await sb.Supabase.initialize(
    url: url,
    anonKey: anonKey,
    authOptions: sb.FlutterAuthClientOptions(
      // Both are SDK defaults today, but pinned explicitly (§13.6/§5.1) so the
      // security posture is visible here and survives an SDK default change.
      // ignore: avoid_redundant_argument_values
      authFlowType: sb.AuthFlowType.pkce,
      // Pinned explicitly for the same reason as authFlowType above.
      // ignore: avoid_redundant_argument_values
      autoRefreshToken: true,
      localStorage: sessionStorage,
      pkceAsyncStorage: SecureGotrueAsyncStorage(store: secure),
    ),
  );
  // Snapshot whether a session exists on disk so the controller can seed
  // `unknown` (restore-in-flight) rather than flashing `unauthenticated`.
  final restorable = await sessionStorage.hasAccessToken();
  SupabaseSessionBootstrap.hasRestorableSession = restorable;
  return true;
}
