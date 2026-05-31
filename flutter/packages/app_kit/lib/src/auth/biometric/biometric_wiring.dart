/// Production biometric wiring — binds [BiometricPort] to `local_auth`.
///
/// This is the ONLY file that imports a `local_auth` type; like
/// `auth_wiring.dart` / `payment_wiring.dart` / `push_wiring.dart` it is
/// excluded from unit tests (which use the [BiometricPort] fake). It compiles
/// under `dart analyze` but is never executed by the harness test suite.
///
/// §8-B: this only exposes the device prompt — it has no connection to the
/// Supabase session or `core` auth state. See `biometric_port.dart`.
library;

import 'package:app_kit/src/auth/biometric/biometric_port.dart';
import 'package:local_auth/local_auth.dart';

/// [BiometricPort] over the `local_auth` plugin.
///
/// `biometricOnly: false` lets the OS fall back to the device passcode/pattern
/// when no biometric is enrolled — the gate still works on devices without a
/// fingerprint/face sensor. All `local_auth` exceptions are swallowed into
/// `false`/`unavailable` so the gate never throws across the seam.
class LocalAuthBiometricPort implements BiometricPort {
  /// Creates a [LocalAuthBiometricPort].
  LocalAuthBiometricPort([LocalAuthentication? auth])
      : _auth = auth ?? LocalAuthentication();

  final LocalAuthentication _auth;

  @override
  Future<bool> get isAvailable async {
    try {
      final supported = await _auth.isDeviceSupported();
      if (!supported) return false;
      return _auth.canCheckBiometrics;
    } on Object {
      return false;
    }
  }

  @override
  Future<bool> authenticate({required String localizedReason}) async {
    try {
      return await _auth.authenticate(
        localizedReason: localizedReason,
        options: const AuthenticationOptions(
          stickyAuth: true,
        ),
      );
    } on Object {
      // Any platform/plugin error is a failed unlock, never a crash.
      return false;
    }
  }
}
