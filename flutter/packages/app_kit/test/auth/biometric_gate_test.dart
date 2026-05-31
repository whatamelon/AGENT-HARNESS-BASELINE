import 'package:app_kit/app_kit.dart';
import 'package:flutter_test/flutter_test.dart';

/// Hand-written fake [BiometricPort] (harness convention — no mockito/mocktail).
class _FakeBiometricPort implements BiometricPort {
  _FakeBiometricPort({required this.available, this.authResult = true});

  final bool available;
  final bool authResult;
  String? lastReason;
  int authCalls = 0;

  @override
  Future<bool> get isAvailable async => available;

  @override
  Future<bool> authenticate({required String localizedReason}) async {
    authCalls++;
    lastReason = localizedReason;
    return authResult;
  }
}

void main() {
  group('BiometricGate.unlock', () {
    test('unavailable device -> unavailable, never prompts', () async {
      final port = _FakeBiometricPort(available: false);
      final gate = BiometricGate(port);

      final result = await gate.unlock();

      expect(result, BiometricResult.unavailable);
      expect(port.authCalls, 0, reason: 'must not prompt when unavailable');
    });

    test('available + successful auth -> success', () async {
      final port = _FakeBiometricPort(available: true);
      final gate = BiometricGate(port);

      final result = await gate.unlock();

      expect(result, BiometricResult.success);
      expect(port.authCalls, 1);
    });

    test('available + failed auth -> failed', () async {
      final port = _FakeBiometricPort(available: true, authResult: false);
      final gate = BiometricGate(port);

      final result = await gate.unlock();

      expect(result, BiometricResult.failed);
      expect(port.authCalls, 1);
    });

    test('passes the localized reason through to the port', () async {
      final port = _FakeBiometricPort(available: true);
      final gate = BiometricGate(port);

      await gate.unlock(reason: '결제 확인을 위해 인증해 주세요.');

      expect(port.lastReason, '결제 확인을 위해 인증해 주세요.');
    });

    test('uses the Korean default reason when none is given', () async {
      final port = _FakeBiometricPort(available: true);
      final gate = BiometricGate(port);

      await gate.unlock();

      expect(port.lastReason, BiometricGate.defaultReason);
      expect(BiometricGate.defaultReason, contains('잠금'));
    });
  });
}
