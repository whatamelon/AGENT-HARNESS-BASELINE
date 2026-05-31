/// M3 — device token lifecycle bound to auth.
///
/// Subscribes to core's `authStateProvider` (the §8-B one-way boundary) and:
/// - on authenticated + token available -> upsert `(user_id, token, platform)`
/// - on sign-out / account switch        -> DELETE the token (stale-send guard)
///
/// The Supabase write is hidden behind [DeviceTokenStore] so the lifecycle
/// logic is unit-testable with a fake; production wires a
/// `SupabaseClient`-backed store (see `push_wiring.dart`). Token rotation
/// (`onTokenRefresh`) re-upserts while
/// authenticated. The table/column names are app-injected so the same package
/// serves apps with different schemas (yipark maps to `member_devices`).
library;

import 'dart:async';

import 'package:app_kit/src/push/push_backend.dart';
import 'package:core/core.dart' as core;
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// SDK-neutral upsert/delete sink for device tokens. Production wraps a
/// `SupabaseClient`; tests use a recording fake.
abstract class DeviceTokenStore {
  /// Upserts the token for [userId] (idempotent on the app's conflict key).
  Future<void> upsert({
    required String userId,
    required String token,
    required String platform,
  });

  /// Deletes the token for [userId] (M3 stale-send guard). When [token] is
  /// null, deletes all tokens owned by [userId] (full sign-out cleanup).
  Future<void> deleteToken({required String userId, String? token});
}

/// The host platform a token was issued for.
enum DevicePlatform {
  /// iOS / APNs.
  ios,

  /// Android / FCM.
  android,

  /// Web push.
  web;

  /// Wire value persisted in the store.
  String get wire => name;
}

/// Binds device-token registration to the auth lifecycle (M3).
class DeviceTokenRegistrar {
  /// Creates a [DeviceTokenRegistrar].
  DeviceTokenRegistrar({
    required PushBackend backend,
    required DeviceTokenStore store,
    required DevicePlatform platform,
    core.AppLogger logger = const core.AppLogger(name: 'push.token'),
  })  : _backend = backend,
        _store = store,
        _platform = platform,
        _logger = logger;

  final PushBackend _backend;
  final DeviceTokenStore _store;
  final DevicePlatform _platform;
  final core.AppLogger _logger;

  ProviderSubscription<core.AuthState>? _authSub;
  StreamSubscription<String>? _tokenRefreshSub;

  String? _currentUserId;
  String? _currentToken;

  /// Starts listening to `authStateProvider` and token rotation.
  ///
  /// Wire from a `ref` (e.g. a provider's `build`); call [dispose] on teardown.
  /// Reacts immediately to the current auth state and to every later change.
  void start(Ref ref) {
    _authSub = ref.listen<core.AuthState>(
      core.authStateProvider,
      (previous, next) => unawaited(_onAuthChanged(previous, next)),
      fireImmediately: true,
    );
    _tokenRefreshSub = _backend.onTokenRefresh.listen(_onTokenRefresh);
  }

  Future<void> _onAuthChanged(
    core.AuthState? previous,
    core.AuthState next,
  ) async {
    final previousUserId = previous?.userId;
    final nextUserId = next.isAuthenticated ? next.userId : null;
    if (previousUserId == nextUserId && _currentUserId == nextUserId) {
      return; // No identity transition.
    }

    // Account switch or sign-out: purge the *previous* user's token first so a
    // stale token never receives the next user's (or post-logout) pushes (M3).
    if (previousUserId != null && previousUserId != nextUserId) {
      await _deleteFor(previousUserId);
    }

    _currentUserId = nextUserId;
    if (nextUserId == null) {
      // Signed out: ensure no token lingers for the now-current null identity.
      _currentToken = null;
      return;
    }
    await _registerCurrent(nextUserId);
  }

  Future<void> _registerCurrent(String userId) async {
    final token = await _backend.getToken();
    if (token == null || token.isEmpty) {
      _logger.warn('no device token available; skip upsert');
      return;
    }
    _currentToken = token;
    await _upsert(userId, token);
  }

  void _onTokenRefresh(String token) {
    final userId = _currentUserId;
    _currentToken = token;
    if (userId == null) return; // Not authenticated: nothing to register yet.
    unawaited(_upsert(userId, token));
  }

  Future<void> _upsert(String userId, String token) async {
    try {
      await _store.upsert(
        userId: userId,
        token: token,
        platform: _platform.wire,
      );
      _logger.info('device token upserted (platform=${_platform.wire})');
    } on Object catch (e, st) {
      // Redact the device token from the SDK error before logging: a raw FCM
      // token is opaque and not caught by AppLogger's bearer/JWT pattern, so an
      // upstream error that echoes the token would leak it otherwise.
      _logger.error(
        'device token upsert failed: ${_redactToken('$e', token)}',
        stackTrace: st,
      );
    }
  }

  Future<void> _deleteFor(String userId) async {
    final token = _currentToken;
    try {
      await _store.deleteToken(userId: userId, token: token);
      _logger.info('device token deleted for prior identity (M3)');
    } on Object catch (e, st) {
      _logger.error(
        'device token delete failed: ${_redactToken('$e', token)}',
        stackTrace: st,
      );
    }
  }

  /// Masks the device [token] (and any AppLogger-known PII) out of an error
  /// string so a token is never written to logs in plaintext. Defence in depth
  /// alongside `AppLogger.redact`, whose token pattern only covers bearer/JWT
  /// shapes — not opaque FCM/APNs tokens.
  static String _redactToken(String message, String? token) {
    final redacted = core.AppLogger.redact(message);
    if (token == null || token.isEmpty) return redacted;
    return redacted.replaceAll(token, '[redacted-device-token]');
  }

  /// Cancels subscriptions. Does not delete the token (sign-out handles that).
  Future<void> dispose() async {
    _authSub?.close();
    _authSub = null;
    await _tokenRefreshSub?.cancel();
    _tokenRefreshSub = null;
  }
}
