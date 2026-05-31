import 'package:app_kit/app_kit.dart';
import 'package:flutter_test/flutter_test.dart';

/// In-memory secure store standing in for the Keychain/Keystore backend.
class _MemoryStore implements SecureKeyValueStore {
  final Map<String, String> _data = {};

  @override
  Future<bool> containsKey(String key) async => _data.containsKey(key);

  @override
  Future<String?> read(String key) async => _data[key];

  @override
  Future<void> write(String key, String value) async => _data[key] = value;

  @override
  Future<void> delete(String key) async => _data.remove(key);
}

void main() {
  group('SecureSessionStorage', () {
    test('persist -> hasAccessToken -> accessToken roundtrip', () async {
      final store = _MemoryStore();
      final storage = SecureSessionStorage(store: store);
      await storage.initialize();

      expect(await storage.hasAccessToken(), isFalse);

      await storage.persistSession('{"access_token":"a","refresh_token":"r"}');
      expect(await storage.hasAccessToken(), isTrue);
      expect(
        await storage.accessToken(),
        '{"access_token":"a","refresh_token":"r"}',
      );
    });

    test('removePersistedSession clears the session', () async {
      final store = _MemoryStore();
      final storage = SecureSessionStorage(store: store);
      await storage.persistSession('session-blob');

      await storage.removePersistedSession();
      expect(await storage.hasAccessToken(), isFalse);
      expect(await storage.accessToken(), isNull);
    });

    test('honours a custom persistSessionKey', () async {
      final store = _MemoryStore();
      final storage = SecureSessionStorage(
        store: store,
        persistSessionKey: 'custom.key',
      );
      await storage.persistSession('v');
      expect(await store.read('custom.key'), 'v');
    });
  });

  group('SecureGotrueAsyncStorage (PKCE verifier)', () {
    test('setItem / getItem / removeItem roundtrip', () async {
      final store = _MemoryStore();
      final storage = SecureGotrueAsyncStorage(store: store);

      await storage.setItem(key: 'pkce', value: 'verifier-123');
      expect(await storage.getItem(key: 'pkce'), 'verifier-123');

      await storage.removeItem(key: 'pkce');
      expect(await storage.getItem(key: 'pkce'), isNull);
    });
  });
}
