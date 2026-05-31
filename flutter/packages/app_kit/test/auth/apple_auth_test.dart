import 'dart:convert';

import 'package:app_kit/app_kit.dart';
import 'package:app_kit/src/auth/social/apple_auth.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gotrue/gotrue.dart' show OAuthProvider;

/// Records the nonce Apple was asked to sign and returns a canned token.
class _FakeApple implements AppleCredentialPort {
  _FakeApple({this.token = 'apple.id.token'});
  final String? token;
  String? seenNonce;

  @override
  Future<String?> getAppleIdToken({required String nonce}) async {
    seenNonce = nonce;
    return token;
  }
}

void main() {
  group('AppleNonce (H-5)', () {
    test('rawNonce is high-entropy and the requested length', () {
      final a = AppleNonce.generateRawNonce();
      final b = AppleNonce.generateRawNonce();
      expect(a.length, 32);
      expect(a, isNot(equals(b)), reason: 'CSPRNG must not repeat');
    });

    test('sha256OfNonce matches an independent SHA-256 of rawNonce', () {
      const rawNonce = 'fixed-raw-nonce-value';
      final expected = sha256.convert(utf8.encode(rawNonce)).toString();
      expect(AppleNonce.sha256OfNonce(rawNonce), expected);
    });
  });

  group('AppleAuthService', () {
    test('signs Apple request with sha256(rawNonce), returns rawNonce to '
        'Supabase', () async {
      final apple = _FakeApple();
      final service = AppleAuthService(apple);

      final cred = await service.signIn();

      // Provider + token plumbed through.
      expect(cred.provider, OAuthProvider.apple);
      expect(cred.idToken, 'apple.id.token');

      // H-5: the nonce sent to Apple is the SHA-256 of the rawNonce we keep,
      // and we hand the UNHASHED rawNonce to Supabase for re-hash comparison.
      expect(cred.rawNonce, isNotNull);
      expect(apple.seenNonce, AppleNonce.sha256OfNonce(cred.rawNonce!));
      expect(apple.seenNonce, isNot(equals(cred.rawNonce)));
    });

    test('throws when Apple returns no identity token', () async {
      final service = AppleAuthService(_FakeApple(token: null));
      await expectLater(service.signIn(), throwsStateError);
    });
  });
}
