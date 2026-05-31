import 'dart:async';

import 'package:app_kit/app_kit.dart';
import 'package:core/core.dart' as core;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// Minimal PushBackend exposing a settable token + token-refresh stream.
class _FakeBackend implements PushBackend {
  String? token = 'tok-A';
  final _tokenRefresh = StreamController<String>.broadcast();

  void rotate(String t) => _tokenRefresh.add(t);

  @override
  Future<String?> getToken() async => token;

  @override
  Stream<String> get onTokenRefresh => _tokenRefresh.stream;

  @override
  Future<PushPermission> requestPermission() async =>
      PushPermission.authorized;

  @override
  Stream<PushMessage> get onForegroundMessage => const Stream.empty();

  @override
  Future<PushMessage?> getInitialMessage() async => null;

  @override
  Stream<PushMessage> get onMessageOpenedApp => const Stream.empty();

  Future<void> dispose() => _tokenRefresh.close();
}

/// Records upsert / delete calls.
class _RecordingStore implements DeviceTokenStore {
  final List<({String userId, String token, String platform})> upserts = [];
  final List<({String userId, String? token})> deletes = [];

  @override
  Future<void> upsert({
    required String userId,
    required String token,
    required String platform,
  }) async {
    upserts.add((userId: userId, token: token, platform: platform));
  }

  @override
  Future<void> deleteToken({required String userId, String? token}) async {
    deletes.add((userId: userId, token: token));
  }
}

/// Controllable auth controller for driving authStateProvider in tests.
class _TestAuth extends core.AuthController {
  @override
  core.AuthState build() => core.AuthState.unauthenticated;

  core.AuthState get value => state;
  set value(core.AuthState next) => state = next;
}

/// Hosts the registrar inside a provider so `ref.listen` is valid.
final _registrarProvider = Provider<DeviceTokenRegistrar>((ref) {
  throw UnimplementedError('overridden per test');
});

void main() {
  group('DeviceTokenRegistrar (M3)', () {
    late _FakeBackend backend;
    late _RecordingStore store;
    late _TestAuth auth;

    ProviderContainer build() {
      backend = _FakeBackend();
      store = _RecordingStore();
      auth = _TestAuth();
      final container = ProviderContainer(
        overrides: [
          core.authStateProvider.overrideWith(() => auth),
          _registrarProvider.overrideWith((ref) {
            final registrar = DeviceTokenRegistrar(
              backend: backend,
              store: store,
              platform: DevicePlatform.ios,
            )..start(ref);
            ref.onDispose(() => unawaited(registrar.dispose()));
            return registrar;
          }),
        ],
      );
      addTearDown(container.dispose);
      addTearDown(backend.dispose);
      // Realize both providers so subscriptions are live.
      container
        ..read(core.authStateProvider)
        ..read(_registrarProvider);
      return container;
    }

    test('authenticated -> upserts (user_id, token, platform)', () async {
      build();
      auth.value = core.AuthState.authenticated('u-1');
      await Future<void>.delayed(Duration.zero);

      expect(store.upserts, hasLength(1));
      expect(store.upserts.single.userId, 'u-1');
      expect(store.upserts.single.token, 'tok-A');
      expect(store.upserts.single.platform, 'ios');
    });

    test('sign-out -> deletes the token (stale-send guard)', () async {
      build();
      auth.value = core.AuthState.authenticated('u-1');
      await Future<void>.delayed(Duration.zero);

      auth.value = core.AuthState.unauthenticated;
      await Future<void>.delayed(Duration.zero);

      expect(store.deletes, hasLength(1));
      expect(store.deletes.single.userId, 'u-1');
      expect(store.deletes.single.token, 'tok-A');
    });

    test('account switch -> deletes prior identity then upserts the new',
        () async {
      build();
      auth.value = core.AuthState.authenticated('u-1');
      await Future<void>.delayed(Duration.zero);

      backend.token = 'tok-B';
      auth.value = core.AuthState.authenticated('u-2');
      await Future<void>.delayed(Duration.zero);

      // Prior identity's token deleted (M3).
      expect(store.deletes.single.userId, 'u-1');
      // New identity upserted.
      expect(store.upserts.last.userId, 'u-2');
      expect(store.upserts.last.token, 'tok-B');
    });

    test('token rotation while authenticated re-upserts', () async {
      build();
      auth.value = core.AuthState.authenticated('u-1');
      await Future<void>.delayed(Duration.zero);

      backend.rotate('tok-rotated');
      await Future<void>.delayed(Duration.zero);

      expect(store.upserts.last.token, 'tok-rotated');
      expect(store.upserts.last.userId, 'u-1');
    });

    test('token rotation while signed out does not upsert', () async {
      build();
      backend.rotate('tok-x');
      await Future<void>.delayed(Duration.zero);

      expect(store.upserts, isEmpty);
    });
  });
}
