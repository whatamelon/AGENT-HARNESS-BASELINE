import 'package:core/core.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('redactSensitive', () {
    test('masks a bare JWT token', () {
      const token =
          'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9'
          '.eyJzdWIiOiJ1c2VyLTEyMyIsImV4cCI6OTk5OTk5OTk5OX0'
          '.SflKxwRJSMeKKF2QT4fwpMeJf36POk6yJV_adQssw5c';
      final result = redactSensitive('token=$token');
      expect(
        result.contains('eyJ'),
        isFalse,
        reason: 'JWT header must be masked',
      );
      expect(
        result.contains('***JWT***'),
        isTrue,
        reason: 'JWT sentinel must appear',
      );
    });

    test('masks Bearer token', () {
      // _bearer fires first → "Bearer ***"; then _apiKeyHeader masks the
      // header name too → "Authorization: ***". Either way the raw token
      // is gone and no sensitive value survives.
      const input = 'Authorization: Bearer abc123def456';
      final result = redactSensitive(input);
      expect(result.contains('abc123def456'), isFalse);
      expect(result.contains('***'), isTrue);
    });

    test('masks email address', () {
      final result = redactSensitive('contact user@example.com please');
      expect(result.contains('user@example.com'), isFalse);
      expect(result.contains('***@***'), isTrue);
    });

    test('masks KR phone number', () {
      final result = redactSensitive('call 010-1234-5678 now');
      expect(result.contains('010-1234-5678'), isFalse);
    });

    test('masks apikey header', () {
      final result = redactSensitive('apikey: supersecretkey');
      expect(result.contains('supersecretkey'), isFalse);
    });

    test('does not alter unrelated text', () {
      const clean = 'GET /park/contract?page=1 200 OK';
      expect(redactSensitive(clean), clean);
    });

    test('JWT inside Bearer is fully masked', () {
      const jwt =
          'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9'
          '.eyJzdWIiOiJ1c2VyLTEyMyJ9'
          '.SflKxwRJSMeKKF2QT4fwpMeJf36POk6yJV_adQssw5c';
      final result = redactSensitive('Bearer $jwt');
      expect(result.contains('eyJ'), isFalse);
    });
  });
}
