import 'package:app_kit/app_kit.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('RouteWhitelist (§H-3)', () {
    final whitelist = RouteWhitelist(
      allowedPrefixes: const {
        '/park/contract',
        '/park/reservation',
        '/onyu/guide',
      },
      homeFallback: '/park',
    );

    test('allows an exact prefix match', () {
      final r = whitelist.resolvePath('/park/contract');
      expect(r.route, '/park/contract');
      expect(r.wasAllowed, isTrue);
    });

    test('allows a sub-path of an allowed prefix', () {
      final r = whitelist.resolvePath('/park/contract/123');
      expect(r.route, '/park/contract/123');
      expect(r.wasAllowed, isTrue);
    });

    test('rejects a privilege-escalation route -> home fallback', () {
      final r = whitelist.resolvePath('/admin/users');
      expect(r.route, '/park');
      expect(r.wasAllowed, isFalse);
    });

    test('rejects a prefix-collision that is not a real sub-path', () {
      // `/park/contractzzz` must NOT be allowed by the `/park/contract` prefix.
      final r = whitelist.resolvePath('/park/contractzzz');
      expect(r.wasAllowed, isFalse);
      expect(r.route, '/park');
    });

    test('null / empty path falls back to home', () {
      expect(whitelist.resolvePath(null).route, '/park');
      expect(whitelist.resolvePath('').route, '/park');
      expect(whitelist.resolvePath('   ').route, '/park');
    });

    test('strips query and fragment before matching', () {
      final r = whitelist.resolvePath('/park/reservation?date=2026-06-01#top');
      expect(r.route, '/park/reservation');
      expect(r.wasAllowed, isTrue);
    });

    test('normalizes a full URL down to its path', () {
      final r = whitelist.resolvePath('https://yipark.app/onyu/guide/step1');
      expect(r.route, '/onyu/guide/step1');
      expect(r.wasAllowed, isTrue);
    });

    test('collapses duplicate slashes and trailing slash', () {
      final r = whitelist.resolvePath('/park//contract/');
      expect(r.route, '/park/contract');
      expect(r.wasAllowed, isTrue);
    });

    test('non-absolute path is rejected', () {
      expect(whitelist.resolvePath('park/contract').wasAllowed, isFalse);
    });

    test('rejects a `..` traversal escaping an allowed prefix', () {
      // `/park/contract/../admin` resolves to `/admin` BEFORE matching, so the
      // `/park/contract` prefix can never authorize it (H-3).
      final r = whitelist.resolvePath('/park/contract/../admin');
      expect(r.route, '/park');
      expect(r.wasAllowed, isFalse);
    });

    test('rejects a multi-segment `..` traversal to /admin', () {
      final r = whitelist.resolvePath('/onyu/guide/../../admin');
      expect(r.route, '/park');
      expect(r.wasAllowed, isFalse);
    });

    test('rejects a mixed `.`/`..` traversal to /admin', () {
      final r = whitelist.resolvePath('/park/contract/./../../admin');
      expect(r.route, '/park');
      expect(r.wasAllowed, isFalse);
    });

    test('rejects a percent-encoded `..` traversal (%2e%2e)', () {
      final r = whitelist.resolvePath('/park/contract/%2e%2e/admin');
      expect(r.route, '/park');
      expect(r.wasAllowed, isFalse);
    });

    test('keeps an allowed route that contains harmless `.` segments', () {
      // `/park/contract/.` normalizes to `/park/contract` — still allowed.
      final r = whitelist.resolvePath('/park/contract/.');
      expect(r.route, '/park/contract');
      expect(r.wasAllowed, isTrue);
    });

    test('duplicate-slash + trailing-dot allowed route survives', () {
      final r = whitelist.resolvePath('/park//contract');
      expect(r.route, '/park/contract');
      expect(r.wasAllowed, isTrue);
    });

    test('referral survives only on an allowed route', () {
      final ok = whitelist.resolvePath('/park/contract', referralCode: 'R1');
      expect(ok.referralCode, 'R1');

      // Disallowed route must drop the referral (no smuggling).
      final rejected = whitelist.resolvePath('/admin', referralCode: 'R1');
      expect(rejected.referralCode, isNull);
      expect(rejected.wasAllowed, isFalse);
    });
  });
}
