/// H-5 hardened session persistence backed by the platform secure enclave
/// (iOS Keychain / Android Keystore-encrypted store) via
/// `flutter_secure_storage`.
///
/// Supabase persists the session JSON (with the refresh token) through its
/// [LocalStorage] port, and the PKCE code verifier through its
/// [GotrueAsyncStorage] port. The default supabase_flutter wiring routes both
/// to `shared_preferences` (PLAINTEXT) — forbidden here (§8-A H-5). These
/// adapters replace that with the secure store; wire them at
/// `Supabase.initialize` via
/// `FlutterAuthClientOptions(localStorage: ..., pkceAsyncStorage: ...)`.
library;

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:gotrue/gotrue.dart' show GotrueAsyncStorage;
import 'package:supabase_flutter/supabase_flutter.dart' show LocalStorage;

/// The minimal key/value contract this module needs from a secure backend.
///
/// Lets tests supply an in-memory fake instead of touching the real Keychain.
abstract class SecureKeyValueStore {
  /// Reads the value for [key], or `null` when absent.
  Future<String?> read(String key);

  /// Writes [value] under [key].
  Future<void> write(String key, String value);

  /// Removes [key].
  Future<void> delete(String key);

  /// Whether [key] is present.
  Future<bool> containsKey(String key);
}

/// Production [SecureKeyValueStore] over `flutter_secure_storage`.
///
/// iOS: Keychain, accessible only after first unlock on this device (no iCloud
/// sync / backup of tokens). Android: Keystore-encrypted shared prefs.
class FlutterSecureKeyValueStore implements SecureKeyValueStore {
  /// Creates a [FlutterSecureKeyValueStore].
  const FlutterSecureKeyValueStore({
    FlutterSecureStorage storage = const FlutterSecureStorage(
      iOptions: IOSOptions(
        accessibility: KeychainAccessibility.first_unlock_this_device,
      ),
      aOptions: AndroidOptions(encryptedSharedPreferences: true),
    ),
  }) : _storage = storage;

  final FlutterSecureStorage _storage;

  @override
  Future<String?> read(String key) => _storage.read(key: key);

  @override
  Future<void> write(String key, String value) =>
      _storage.write(key: key, value: value);

  @override
  Future<void> delete(String key) => _storage.delete(key: key);

  @override
  Future<bool> containsKey(String key) => _storage.containsKey(key: key);
}

/// Supabase session [LocalStorage] backed by a [SecureKeyValueStore].
///
/// Stores the full session string (refresh token included) encrypted at rest.
class SecureSessionStorage extends LocalStorage {
  /// Creates a [SecureSessionStorage].
  SecureSessionStorage({
    required SecureKeyValueStore store,
    String persistSessionKey = _defaultSessionKey,
  })  : _store = store,
        _key = persistSessionKey;

  static const _defaultSessionKey = 'yipark.supabase.session';

  final SecureKeyValueStore _store;
  final String _key;

  @override
  Future<void> initialize() async {
    // No async warm-up needed; present only for the LocalStorage contract.
  }

  @override
  Future<bool> hasAccessToken() => _store.containsKey(_key);

  @override
  Future<String?> accessToken() => _store.read(_key);

  @override
  Future<void> removePersistedSession() => _store.delete(_key);

  @override
  Future<void> persistSession(String persistSessionString) =>
      _store.write(_key, persistSessionString);
}

/// Secure [GotrueAsyncStorage] for the PKCE code verifier.
///
/// The verifier is short-lived but is a sign-in secret, so it also stays out of
/// plaintext `shared_preferences`.
class SecureGotrueAsyncStorage extends GotrueAsyncStorage {
  /// Creates a [SecureGotrueAsyncStorage].
  SecureGotrueAsyncStorage({required SecureKeyValueStore store})
      : _store = store;

  final SecureKeyValueStore _store;

  @override
  Future<String?> getItem({required String key}) => _store.read(key);

  @override
  Future<void> setItem({required String key, required String value}) =>
      _store.write(key, value);

  @override
  Future<void> removeItem({required String key}) => _store.delete(key);
}
