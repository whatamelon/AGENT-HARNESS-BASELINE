/// Kakao sign-in producing a Supabase-ready [IdTokenCredential].
///
/// API confirmation (schema-no-guess, against pub cache sources):
///   - `gotrue` `signInWithIdToken` doc explicitly lists Kakao among supported
///     providers, and `OAuthProvider.kakao` exists
///     (gotrue-2.20.0/lib/src/gotrue_client.dart:391, types.dart:40). So the
///     OIDC ID-token path is first-class — no deep-link `signInWithOAuth`
///     workaround is required.
///   - `kakao_flutter_sdk_user` `loginWithKakaoTalk` / `loginWithKakaoAccount`
///     accept a `nonce` and the returned `OAuthToken.idToken` is the OIDC token
///     (kakao_flutter_sdk_user-1.10.0/lib/src/user_api.dart:47,
///     kakao_flutter_sdk_auth-1.10.0/lib/src/model/oauth_token.dart:39).
///
/// To receive `idToken`, the Kakao app must have OpenID Connect activated in
/// the Kakao Developers console (P3-integration / backend concern). The
/// Supabase Kakao provider `client id` / allowed audience is likewise a console
/// setting.
library;

import 'package:app_kit/src/auth/auth_ports.dart';
import 'package:gotrue/gotrue.dart' show OAuthProvider;

/// Produces a Kakao [IdTokenCredential] ready for `signInWithIdToken`.
class KakaoAuthService {
  /// Creates a [KakaoAuthService].
  const KakaoAuthService(this._kakao);

  final KakaoLoginPort _kakao;

  /// Runs Kakao login and returns the credential, or throws [StateError] if
  /// Kakao returns no OIDC ID token (OIDC likely not enabled for the app).
  Future<IdTokenCredential> signIn() async {
    final idToken = await _kakao.getKakaoIdToken();
    if (idToken == null || idToken.isEmpty) {
      throw StateError('kakao-no-id-token');
    }

    // Kakao does not require nonce echo through Supabase here; the nonce (if
    // used) is verified by Kakao when minting the OIDC token.
    return IdTokenCredential(
      provider: OAuthProvider.kakao,
      idToken: idToken,
    );
  }
}
