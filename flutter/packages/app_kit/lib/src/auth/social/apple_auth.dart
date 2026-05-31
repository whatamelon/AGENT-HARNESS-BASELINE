/// Apple sign-in with H-5 nonce binding.
///
/// Flow (standard for Supabase native Apple):
///   1. Generate a high-entropy `rawNonce` (CSPRNG).
///   2. Request the Apple credential with `nonce: sha256(rawNonce)` — Apple
///      embeds that hash in the returned ID token's `nonce` claim.
///   3. Hand Supabase `signInWithIdToken(idToken, nonce: rawNonce)`; Supabase
///      re-hashes `rawNonce` and compares, defeating replay.
///
/// P3-integration: the `aud` of the Apple token must match the Service ID /
/// bundle id configured in the yipark Supabase Apple provider console; that is
/// a backend/console setting, not client code.
library;

import 'dart:convert';
import 'dart:math';

import 'package:app_kit/src/auth/auth_ports.dart';
import 'package:crypto/crypto.dart';
import 'package:gotrue/gotrue.dart' show OAuthProvider;
import 'package:meta/meta.dart';

/// Cryptographic helpers for the Apple nonce, isolated for unit testing.
@visibleForTesting
class AppleNonce {
  /// Generates a URL-safe `rawNonce` of [length] chars from a CSPRNG.
  static String generateRawNonce([int length = 32]) {
    const charset =
        'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-._';
    final rng = Random.secure();
    return List<String>.generate(
      length,
      (_) => charset[rng.nextInt(charset.length)],
    ).join();
  }

  /// Returns the hex SHA-256 of [rawNonce] — the value sent to Apple.
  static String sha256OfNonce(String rawNonce) =>
      sha256.convert(utf8.encode(rawNonce)).toString();
}

/// Produces an Apple [IdTokenCredential] ready for `signInWithIdToken`.
class AppleAuthService {
  /// Creates an [AppleAuthService].
  const AppleAuthService(this._apple);

  final AppleCredentialPort _apple;

  /// Runs the Apple sign-in and returns the credential, or throws
  /// [StateError] if Apple returns no identity token.
  Future<IdTokenCredential> signIn() async {
    final rawNonce = AppleNonce.generateRawNonce();
    final hashedNonce = AppleNonce.sha256OfNonce(rawNonce);

    final idToken = await _apple.getAppleIdToken(nonce: hashedNonce);
    if (idToken == null || idToken.isEmpty) {
      throw StateError('apple-no-identity-token');
    }

    return IdTokenCredential(
      provider: OAuthProvider.apple,
      idToken: idToken,
      rawNonce: rawNonce,
    );
  }
}
