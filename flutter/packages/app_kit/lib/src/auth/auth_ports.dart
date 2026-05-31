/// Thin port interfaces that decouple the auth controller and social services
/// from the concrete SDKs (`gotrue`/`supabase_flutter`, `sign_in_with_apple`,
/// `kakao_flutter_sdk_user`).
///
/// Production wires these to the real SDKs; unit tests supply hand-written
/// fakes (the harness convention — no `mockito`/`mocktail`). This keeps the
/// §8-B one-way boundary intact: nothing here imports app logic, and the
/// controller never reaches a live network in tests.
library;

// Single-method ports are intentional DI seams (faked in unit tests); not
// folded into top-level functions.
// ignore_for_file: one_member_abstracts

import 'package:gotrue/gotrue.dart' show AuthState, OAuthProvider;
import 'package:meta/meta.dart';

/// Identity-provider credential produced by a social sign-in flow, ready to be
/// exchanged with Supabase via `signInWithIdToken`.
@immutable
class IdTokenCredential {
  /// Creates an [IdTokenCredential].
  const IdTokenCredential({
    required this.provider,
    required this.idToken,
    this.rawNonce,
    this.accessToken,
  });

  /// The Supabase OAuth provider this credential targets (apple/kakao).
  final OAuthProvider provider;

  /// The OIDC ID token issued by the provider.
  final String idToken;

  /// The unhashed (raw) nonce. Supabase compares its SHA-256 against the
  /// `nonce` claim embedded in [idToken] (H-5). `null` when the provider does
  /// not use a nonce.
  final String? rawNonce;

  /// Optional provider access token (only needed when the ID token carries an
  /// `at_hash` claim).
  final String? accessToken;
}

/// Port over the subset of GoTrue used by the auth controller.
///
/// Implemented in production by `SupabaseGoTruePort` (wraps `supabase.auth`);
/// faked in tests with a controllable stream.
abstract class GoTrueAuthPort {
  /// Emits on every auth state change (sign-in, sign-out, token refresh,
  /// initial session restore).
  Stream<AuthState> get onAuthStateChange;

  /// The current user id when a session is active, else `null`.
  String? get currentUserId;

  /// Whether a restorable session likely exists at build time.
  ///
  /// Seeded once during `initSupabaseSecure` (reads
  /// `LocalStorage.hasAccessToken` after init). Lets `build()` decide
  /// synchronously between `AuthStatus.unauthenticated` and
  /// `AuthStatus.unknown` (an in-flight session restore) WITHOUT an async
  /// call — avoiding the cold-start flash-of-login when [currentUserId] is
  /// still `null` because the SDK has not yet replayed `initialSession`
  /// (§5.3/§13.6).
  bool get hasRestorableSession;

  /// Exchanges a provider ID token for a Supabase session.
  Future<void> signInWithIdToken(IdTokenCredential credential);

  /// Signs the current user out and clears the persisted session.
  Future<void> signOut();
}

/// Port over Apple sign-in. Production wraps `sign_in_with_apple`.
abstract class AppleCredentialPort {
  /// Requests an Apple credential using [nonce] as the request nonce
  /// (the caller passes `sha256(rawNonce)` per H-5) and returns the
  /// identity token, or `null` if Apple returned none.
  Future<String?> getAppleIdToken({required String nonce});
}

/// Port over Kakao login. Production wraps `kakao_flutter_sdk_user`.
abstract class KakaoLoginPort {
  /// Performs Kakao login (KakaoTalk app or account web fallback) and returns
  /// the OIDC ID token, or `null` if Kakao returned none.
  Future<String?> getKakaoIdToken();
}
