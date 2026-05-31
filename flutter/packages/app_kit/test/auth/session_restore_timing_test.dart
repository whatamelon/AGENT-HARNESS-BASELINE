/// Cold-start session-restore TIMING contract (closes the open verification
/// item "secure localStorage에서 supabase_flutter 2.12 initialSession 복원
/// 타이밍 스모크").
///
/// A live-Supabase/device test is out of scope; this proves the ORDERING the
/// production code promises (§5.3/§13.6) deterministically with fakes:
///
///  1. GIVEN a persisted session in `SecureSessionStorage` (over the in-memory
///     [SecureKeyValueStore] fake) AND `hasRestorableSession == true` while
///     `currentUserId == null` at build time → the controller seeds
///     `AuthStatus.unknown` (the flash-of-login guard), NOT `unauthenticated`.
///  2. WHEN the `initialSession` event arrives with a user → `authenticated`.
///  3. The observed sequence is `unknown` → `authenticated` with NO
///     `unauthenticated` flash in between.
///  4. GIVEN `hasRestorableSession == false` and no user → initial state is
///     `unauthenticated` (no spurious splash).
///
/// It also proves the snapshot SOURCE: the fake port's `hasRestorableSession`
/// is fed from a real `SecureSessionStorage.hasAccessToken()` over the
/// in-memory store — the same chain production wires via
/// [SupabaseSessionBootstrap] in `initSupabaseSecure`.
library;

import 'dart:async';

import 'package:app_kit/app_kit.dart';
import 'package:core/core.dart' as core;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gotrue/gotrue.dart' as gotrue;

/// In-memory secure store standing in for the Keychain/Keystore backend.
///
/// Mirrors the fake in `secure_session_storage_test.dart`; kept local so this
/// file is self-contained (test files cannot import each other's privates).
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

/// GoTrue port whose `hasRestorableSession` is sourced from the SAME snapshot
/// path as production: a boolean read once from the secure store, exactly as
/// `initSupabaseSecure` snapshots `SecureSessionStorage.hasAccessToken()` into
/// [SupabaseSessionBootstrap]. The `onAuthStateChange` stream is caller-driven.
class _FakeGoTrue implements GoTrueAuthPort {
  _FakeGoTrue({required this.hasRestorableSession});

  @override
  final bool hasRestorableSession;

  final StreamController<gotrue.AuthState> _controller =
      StreamController<gotrue.AuthState>.broadcast();

  void emit(gotrue.AuthChangeEvent event, {String? userId}) {
    _controller.add(gotrue.AuthState(event, _sessionFor(userId)));
  }

  @override
  Stream<gotrue.AuthState> get onAuthStateChange => _controller.stream;

  // Cold start: the SDK has not replayed `initialSession` yet, so there is no
  // current user at build() time — the whole point of the `unknown` seed.
  @override
  String? get currentUserId => null;

  @override
  Future<void> signInWithIdToken(IdTokenCredential credential) async {}

  @override
  Future<void> signOut() async {}

  Future<void> dispose() => _controller.close();
}

gotrue.Session? _sessionFor(String? userId) {
  if (userId == null) return null;
  return gotrue.Session(
    accessToken: 'access-$userId',
    tokenType: 'bearer',
    user: gotrue.User(
      id: userId,
      appMetadata: const <String, dynamic>{},
      userMetadata: const <String, dynamic>{},
      aud: 'authenticated',
      createdAt: '2026-01-01T00:00:00Z',
    ),
  );
}

class _NoopApple implements AppleCredentialPort {
  const _NoopApple();
  @override
  Future<String?> getAppleIdToken({required String nonce}) async => null;
}

class _NoopKakao implements KakaoLoginPort {
  const _NoopKakao();
  @override
  Future<String?> getKakaoIdToken() async => null;
}

/// Wires a controller to [goTrue] and starts recording the observed
/// [core.AuthStatus] sequence.
///
/// The sequence is: the synchronously seeded `build()` value (read once), then
/// every subsequent value the provider emits via the listener. Capturing the
/// seed first is what lets us prove there is NO `unauthenticated` flash between
/// the `unknown` seed and the `authenticated` resolution.
({
  ProviderContainer container,
  SupabaseAuthController controller,
  List<core.AuthStatus> sequence,
}) _wire(_FakeGoTrue goTrue) {
  final controller = SupabaseAuthController()
    ..configure(
      goTrue: () => goTrue,
      apple: () => const AppleAuthService(_NoopApple()),
      kakao: () => const KakaoAuthService(_NoopKakao()),
    );
  final container = ProviderContainer(
    overrides: [core.authStateProvider.overrideWith(() => controller)],
  );
  addTearDown(container.dispose);

  // Read the seed first (triggers build()), then record every transition.
  final sequence = <core.AuthStatus>[
    container.read(core.authStateProvider).status,
  ];
  final sub = container.listen<core.AuthState>(
    core.authStateProvider,
    (_, next) => sequence.add(next.status),
  );
  addTearDown(sub.close);

  return (container: container, controller: controller, sequence: sequence);
}

void main() {
  group('cold-start session-restore timing (§5.3/§13.6)', () {
    // SupabaseSessionBootstrap is a process-global static; reset between tests
    // so a snapshot from one test can never leak into another.
    setUp(SupabaseSessionBootstrap.reset);
    tearDown(SupabaseSessionBootstrap.reset);

    test(
      'SecureSessionStorage.hasAccessToken() round-trips over the in-memory '
      'store (proves the bootstrap snapshot source)',
      () async {
        final store = _MemoryStore();
        final storage = SecureSessionStorage(store: store);
        await storage.initialize();

        // No session yet → snapshot would be false.
        expect(await storage.hasAccessToken(), isFalse);

        // Persist a session string (what gotrue writes through LocalStorage).
        await storage.persistSession(
          '{"access_token":"a","refresh_token":"r","user":{"id":"u-disk"}}',
        );

        // The snapshot path production uses: hasAccessToken() == true and the
        // blob round-trips byte-for-byte.
        expect(await storage.hasAccessToken(), isTrue);
        expect(
          await storage.accessToken(),
          '{"access_token":"a","refresh_token":"r","user":{"id":"u-disk"}}',
        );
      },
    );

    test(
      'persisted session + hasRestorableSession==true, no user yet → seeds '
      'unknown (flash-of-login guard), then resolves to authenticated on '
      'initialSession with NO unauthenticated flash',
      () async {
        // GIVEN: a session is persisted on disk and the cold-start snapshot
        // (the same value initSupabaseSecure derives from
        // SecureSessionStorage.hasAccessToken()) is true, but the SDK has not
        // yet replayed initialSession so currentUserId is still null.
        final store = _MemoryStore();
        final storage = SecureSessionStorage(store: store);
        await storage.initialize();
        await storage.persistSession(
          '{"access_token":"a","refresh_token":"r"}',
        );
        final restorableSnapshot = await storage.hasAccessToken();
        SupabaseSessionBootstrap.hasRestorableSession = restorableSnapshot;
        expect(restorableSnapshot, isTrue);

        final goTrue = _FakeGoTrue(
          hasRestorableSession: SupabaseSessionBootstrap.hasRestorableSession,
        );
        addTearDown(goTrue.dispose);

        final wired = _wire(goTrue);

        // THEN: seeded state is unknown — NOT unauthenticated. This is the
        // flash-of-login guard: the router shows splash, not the login screen.
        expect(
          wired.container.read(core.authStateProvider).status,
          core.AuthStatus.unknown,
        );

        // WHEN: the SDK replays the restored session as initialSession.
        goTrue.emit(gotrue.AuthChangeEvent.initialSession, userId: 'u-restore');
        await Future<void>.delayed(Duration.zero);

        // AND: state resolves to authenticated with the restored user id.
        final resolved = wired.container.read(core.authStateProvider);
        expect(resolved.status, core.AuthStatus.authenticated);
        expect(resolved.userId, 'u-restore');

        // ORDERING: exactly unknown → authenticated. No unauthenticated flash
        // ever appeared between the seed and the resolution.
        expect(
          wired.sequence,
          <core.AuthStatus>[
            core.AuthStatus.unknown,
            core.AuthStatus.authenticated,
          ],
        );
        expect(
          wired.sequence.contains(core.AuthStatus.unauthenticated),
          isFalse,
          reason: 'a flash-of-login would surface unauthenticated mid-restore',
        );
      },
    );

    test(
      'hasRestorableSession==false and no user → seeds unauthenticated '
      '(no spurious splash)',
      () async {
        // GIVEN: nothing persisted → the snapshot is false.
        final store = _MemoryStore();
        final storage = SecureSessionStorage(store: store);
        await storage.initialize();
        final restorableSnapshot = await storage.hasAccessToken();
        SupabaseSessionBootstrap.hasRestorableSession = restorableSnapshot;
        expect(restorableSnapshot, isFalse);

        final goTrue = _FakeGoTrue(
          hasRestorableSession: SupabaseSessionBootstrap.hasRestorableSession,
        );
        addTearDown(goTrue.dispose);

        final wired = _wire(goTrue);

        // THEN: seeded straight to unauthenticated — no unknown splash flicker.
        expect(
          wired.container.read(core.authStateProvider).status,
          core.AuthStatus.unauthenticated,
        );
        expect(
          wired.sequence,
          <core.AuthStatus>[core.AuthStatus.unauthenticated],
        );
        expect(
          wired.sequence.contains(core.AuthStatus.unknown),
          isFalse,
          reason: 'no restorable session must not show a splash',
        );
      },
    );

    test(
      'the unknown seed is observed strictly BEFORE authenticated '
      '(index ordering)',
      () async {
        final store = _MemoryStore();
        final storage = SecureSessionStorage(store: store);
        await storage.persistSession('{"access_token":"a"}');
        SupabaseSessionBootstrap.hasRestorableSession =
            await storage.hasAccessToken();

        final goTrue = _FakeGoTrue(
          hasRestorableSession: SupabaseSessionBootstrap.hasRestorableSession,
        );
        addTearDown(goTrue.dispose);

        final wired = _wire(goTrue);
        goTrue.emit(gotrue.AuthChangeEvent.initialSession, userId: 'u-r2');
        await Future<void>.delayed(Duration.zero);

        final unknownAt = wired.sequence.indexOf(core.AuthStatus.unknown);
        final authedAt = wired.sequence.indexOf(core.AuthStatus.authenticated);
        expect(unknownAt, isNonNegative);
        expect(authedAt, isNonNegative);
        expect(
          unknownAt,
          lessThan(authedAt),
          reason: 'unknown must precede authenticated during restore',
        );
      },
    );
  });
}
