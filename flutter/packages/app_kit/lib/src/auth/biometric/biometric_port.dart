/// Biometric / device-lock gate port (CLIENT-LOCAL, SDK-neutral).
///
/// Mirrors the `auth_ports.dart` / `payment_backend.dart` seam convention:
/// nothing here imports `local_auth`, so the boundary stays one-way and the
/// gate logic is testable with a hand-written fake (no `mockito`/`mocktail`).
/// Production wires it to `LocalAuthBiometricPort` in `biometric_wiring.dart`
/// (excluded from unit tests).
///
/// §8-B BOUNDARY — this is a **local unlock gate only**, NOT an auth state.
/// The Supabase session already lives in the secure store
/// (`SecureSessionStorage`); biometric verification re-confirms the *device
/// holder* before exposing an already-authenticated session (app-resume lock,
/// sensitive screens). It MUST NEVER touch the global `AuthStatus` /
/// `authStateProvider` from `core` (the §8-B one-way boundary): a failed or
/// unavailable biometric check does not sign the user out, and a successful one
/// does not sign anyone in. It only flips a local "unlocked" flag the app uses
/// to reveal/hide content.
library;

import 'package:meta/meta.dart';

/// Outcome of a biometric/device-credential unlock attempt.
enum BiometricResult {
  /// The user authenticated (biometric or device passcode fallback).
  success,

  /// The user cancelled or failed authentication (wrong/absent biometric).
  failed,

  /// No biometric/device credential is available or enrolled on this device.
  unavailable,
}

/// SDK-neutral port over the device's biometric/credential prompt.
///
/// Production wraps `local_auth`; tests supply a fake returning canned values.
abstract class BiometricPort {
  /// Whether the device can attempt a biometric/device-credential check
  /// (hardware present AND a credential is enrolled). When `false`, callers
  /// should treat the gate as open (do not lock the user out of their own
  /// already-authenticated session over a missing sensor).
  Future<bool> get isAvailable;

  /// Prompts the user to authenticate, showing [localizedReason] (Korean).
  /// Returns whether the holder authenticated. Implementations never throw —
  /// platform errors map to `false`.
  Future<bool> authenticate({required String localizedReason});
}

/// Local unlock gate built over a [BiometricPort].
///
/// Pure of any SDK: it only sequences the port and tracks an in-memory
/// "unlocked" flag. It deliberately holds NO reference to the auth controller
/// or `core` auth state (§8-B): unlocking reveals an existing session; it never
/// creates or destroys one.
@immutable
class BiometricGate {
  /// Creates a [BiometricGate] over a [BiometricPort].
  const BiometricGate(this._port);

  final BiometricPort _port;

  /// Korean default prompt reason (apps may override per call site).
  static const String defaultReason = '본인 확인을 위해 잠금을 해제해 주세요.';

  /// Attempts to unlock.
  ///
  /// When the device cannot do biometrics ([BiometricPort.isAvailable] is
  /// `false`) the gate is **open** ([BiometricResult.unavailable]) so a user is
  /// never locked out of their own session by a missing sensor — the calling
  /// app decides whether that counts as unlocked. When available, the result
  /// reflects the prompt: [BiometricResult.success] or
  /// [BiometricResult.failed].
  Future<BiometricResult> unlock({String reason = defaultReason}) async {
    if (!await _port.isAvailable) {
      return BiometricResult.unavailable;
    }
    final ok = await _port.authenticate(localizedReason: reason);
    return ok ? BiometricResult.success : BiometricResult.failed;
  }
}
