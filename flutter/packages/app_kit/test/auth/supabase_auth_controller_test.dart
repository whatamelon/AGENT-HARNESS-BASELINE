import 'dart:async';

import 'package:app_kit/app_kit.dart';
import 'package:core/core.dart' as core;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gotrue/gotrue.dart' as gotrue;

/// In-memory GoTrue port: drive [emit]/[emitError] to simulate
/// `onAuthStateChange` events and errors.
class _FakeGoTrue implements GoTrueAuthPort {
  _FakeGoTrue({this.initialUserId, this.hasRestorableSession = false});
  final String? initialUserId;

  @override
  final bool hasRestorableSession;

  final _controller = StreamController<gotrue.AuthState>.broadcast();

  IdTokenCredential? signedInWith;
  bool signedOut = false;

  void emit(gotrue.AuthChangeEvent event, {String? userId}) {
    _controller.add(gotrue.AuthState(event, _sessionFor(userId)));
  }

  void emitError(Object error) {
    _controller.addError(error);
  }

  @override
  Stream<gotrue.AuthState> get onAuthStateChange => _controller.stream;

  @override
  String? get currentUserId => initialUserId;

  @override
  Future<void> signInWithIdToken(IdTokenCredential credential) async {
    signedInWith = credential;
  }

  @override
  Future<void> signOut() async {
    signedOut = true;
  }

  Future<void> dispose() => _controller.close();
}

gotrue.Session? _sessionFor(String? userId) {
  if (userId == null) return null;
  return gotrue.Session(
    accessToken: 'access-$userId',
    tokenType: 'bearer',
    user: gotrue.User(
      id: userId,
      appMetadata: const {},
      userMetadata: const {},
      aud: 'authenticated',
      createdAt: '2026-01-01T00:00:00Z',
    ),
  );
}

/// Builds a controller wired to [goTrue], with stub social services (unused by
/// the stream-mapping assertions). Optionally captures breadcrumbs and injects
/// a [clock] seam so tests can control the timestamp window without real
/// delays.
({ProviderContainer container, SupabaseAuthController controller}) _wire(
  _FakeGoTrue goTrue, {
  List<String>? crumbs,
  DateTime Function()? clock,
}) {
  final controller = SupabaseAuthController(clock: clock)
    ..configure(
      goTrue: () => goTrue,
      apple: () => const AppleAuthService(_NoopApple()),
      kakao: () => const KakaoAuthService(_NoopKakao()),
      breadcrumb: crumbs?.add,
    );
  final container = ProviderContainer(
    overrides: [core.authStateProvider.overrideWith(() => controller)],
  );
  addTearDown(container.dispose);
  return (container: container, controller: controller);
}

ProviderContainer _containerWith(_FakeGoTrue goTrue) => _wire(goTrue).container;

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

void main() {
  group('SupabaseAuthController', () {
    test('seeds from a restored session on build', () {
      final goTrue = _FakeGoTrue(initialUserId: 'u-seed');
      addTearDown(goTrue.dispose);
      final container = _containerWith(goTrue);

      final state = container.read(core.authStateProvider);
      expect(state.status, core.AuthStatus.authenticated);
      expect(state.userId, 'u-seed');
    });

    test('seeds unauthenticated when no restored session', () {
      final goTrue = _FakeGoTrue();
      addTearDown(goTrue.dispose);
      final container = _containerWith(goTrue);

      expect(
        container.read(core.authStateProvider).status,
        core.AuthStatus.unauthenticated,
      );
    });

    test('seeds unknown when a restorable session exists but no user yet', () {
      // Cold start: SDK has not replayed initialSession, but a session is on
      // disk. Must seed `unknown` (splash) — not flash unauthenticated.
      final goTrue = _FakeGoTrue(hasRestorableSession: true);
      addTearDown(goTrue.dispose);
      final container = _containerWith(goTrue);

      expect(
        container.read(core.authStateProvider).status,
        core.AuthStatus.unknown,
      );
    });

    test('unknown resolves to authenticated on initialSession', () async {
      final goTrue = _FakeGoTrue(hasRestorableSession: true);
      addTearDown(goTrue.dispose);
      final container = _containerWith(goTrue);
      final sub = container.listen(core.authStateProvider, (_, __) {});
      addTearDown(sub.close);

      expect(
        container.read(core.authStateProvider).status,
        core.AuthStatus.unknown,
      );

      goTrue.emit(gotrue.AuthChangeEvent.initialSession, userId: 'u-r');
      await Future<void>.delayed(Duration.zero);

      final state = container.read(core.authStateProvider);
      expect(state.status, core.AuthStatus.authenticated);
      expect(state.userId, 'u-r');
    });

    test('signedIn event maps to authenticated with the user id', () async {
      final goTrue = _FakeGoTrue();
      addTearDown(goTrue.dispose);
      final container = _containerWith(goTrue);
      // Keep the provider alive so its subscription is active.
      final sub = container.listen(core.authStateProvider, (_, __) {});
      addTearDown(sub.close);

      goTrue.emit(gotrue.AuthChangeEvent.signedIn, userId: 'u-1');
      await Future<void>.delayed(Duration.zero);

      final state = container.read(core.authStateProvider);
      expect(state.status, core.AuthStatus.authenticated);
      expect(state.userId, 'u-1');
    });

    test('signedOut event maps to unauthenticated', () async {
      final goTrue = _FakeGoTrue(initialUserId: 'u-1');
      addTearDown(goTrue.dispose);
      final container = _containerWith(goTrue);
      final sub = container.listen(core.authStateProvider, (_, __) {});
      addTearDown(sub.close);

      goTrue.emit(gotrue.AuthChangeEvent.signedOut);
      await Future<void>.delayed(Duration.zero);

      expect(
        container.read(core.authStateProvider).status,
        core.AuthStatus.unauthenticated,
      );
    });

    test('tokenRefreshed keeps the user authenticated', () async {
      final goTrue = _FakeGoTrue();
      addTearDown(goTrue.dispose);
      final container = _containerWith(goTrue);
      final sub = container.listen(core.authStateProvider, (_, __) {});
      addTearDown(sub.close);

      goTrue.emit(gotrue.AuthChangeEvent.tokenRefreshed, userId: 'u-2');
      await Future<void>.delayed(Duration.zero);

      expect(container.read(core.authStateProvider).userId, 'u-2');
    });

    test('signOut delegates to the GoTrue port', () async {
      final goTrue = _FakeGoTrue(initialUserId: 'u-1');
      addTearDown(goTrue.dispose);
      final container = _containerWith(goTrue);

      final controller =
          container.read(core.authStateProvider.notifier)
              as SupabaseAuthController;
      await controller.signOut();

      expect(goTrue.signedOut, isTrue);
    });

    test('signInWithKakao exchanges the credential via the GoTrue port',
        () async {
      final goTrue = _FakeGoTrue();
      addTearDown(goTrue.dispose);
      final controller = SupabaseAuthController()
        ..configure(
          goTrue: () => goTrue,
          apple: () => const AppleAuthService(_NoopApple()),
          kakao: () =>
              const KakaoAuthService(_TokenKakao('kakao.oidc.token')),
        );
      final container = ProviderContainer(
        overrides: [core.authStateProvider.overrideWith(() => controller)],
      );
      addTearDown(container.dispose);
      container.read(core.authStateProvider);

      await controller.signInWithKakao();

      expect(goTrue.signedInWith?.idToken, 'kakao.oidc.token');
    });

    group('forced vs expected sign-out (§5.4)', () {
      test('unexpected signedOut sets sessionExpired', () async {
        final goTrue = _FakeGoTrue(initialUserId: 'u-1');
        addTearDown(goTrue.dispose);
        final wired = _wire(goTrue);
        final sub = wired.container.listen(core.authStateProvider, (_, __) {});
        addTearDown(sub.close);

        // Refresh expired/revoked: gotrue emits signedOut without a signOut().
        goTrue.emit(gotrue.AuthChangeEvent.signedOut);
        await Future<void>.delayed(Duration.zero);

        expect(wired.controller.sessionExpired, isTrue);
        expect(
          wired.container.read(core.authStateProvider).status,
          core.AuthStatus.unauthenticated,
        );
      });

      test('intentional signOut does NOT set sessionExpired', () async {
        final goTrue = _FakeGoTrue(initialUserId: 'u-1');
        addTearDown(goTrue.dispose);
        final wired = _wire(goTrue);
        final sub = wired.container.listen(core.authStateProvider, (_, __) {});
        addTearDown(sub.close);

        await wired.controller.signOut();
        goTrue.emit(gotrue.AuthChangeEvent.signedOut);
        await Future<void>.delayed(Duration.zero);

        expect(wired.controller.sessionExpired, isFalse);
      });

      test('acknowledgeSessionExpired clears the flag', () async {
        final goTrue = _FakeGoTrue(initialUserId: 'u-1');
        addTearDown(goTrue.dispose);
        final wired = _wire(goTrue);
        final sub = wired.container.listen(core.authStateProvider, (_, __) {});
        addTearDown(sub.close);

        goTrue.emit(gotrue.AuthChangeEvent.signedOut);
        await Future<void>.delayed(Duration.zero);
        expect(wired.controller.sessionExpired, isTrue);

        wired.controller.acknowledgeSessionExpired();
        expect(wired.controller.sessionExpired, isFalse);
      });

      test('a fresh sign-in clears a prior expiry flag', () async {
        final goTrue = _FakeGoTrue(initialUserId: 'u-1');
        addTearDown(goTrue.dispose);
        final wired = _wire(goTrue);
        final sub = wired.container.listen(core.authStateProvider, (_, __) {});
        addTearDown(sub.close);

        goTrue.emit(gotrue.AuthChangeEvent.signedOut);
        await Future<void>.delayed(Duration.zero);
        expect(wired.controller.sessionExpired, isTrue);

        goTrue.emit(gotrue.AuthChangeEvent.signedIn, userId: 'u-9');
        await Future<void>.delayed(Duration.zero);
        expect(wired.controller.sessionExpired, isFalse);
      });

      test(
          'signedOut within the window after signOut() is treated as expected',
          () async {
        // Clock is fixed: signOut() stamps T=0, event arrives while still
        // within _signOutWindow → sessionExpired must remain false.
        final now = DateTime(2026, 1, 1, 12);
        final goTrue = _FakeGoTrue(initialUserId: 'u-1');
        addTearDown(goTrue.dispose);
        final wired = _wire(goTrue, clock: () => now);
        final sub = wired.container.listen(core.authStateProvider, (_, __) {});
        addTearDown(sub.close);

        await wired.controller.signOut();
        goTrue.emit(gotrue.AuthChangeEvent.signedOut);
        await Future<void>.delayed(Duration.zero);

        expect(wired.controller.sessionExpired, isFalse);
      });

      test(
          'signedOut that arrives OUTSIDE the window is treated as forced',
          () async {
        // Clock advances past _signOutWindow between signOut() and the event,
        // simulating a remote revoke that coincidentally follows an old stamp.
        var now = DateTime(2026, 1, 1, 12);
        final goTrue = _FakeGoTrue(initialUserId: 'u-1');
        addTearDown(goTrue.dispose);
        // clock is captured by reference via closure so we can advance it.
        final wired = _wire(goTrue, clock: () => now);
        final sub = wired.container.listen(core.authStateProvider, (_, __) {});
        addTearDown(sub.close);

        await wired.controller.signOut();
        // Advance clock by 10 s — well past the 5 s window.
        now = now.add(const Duration(seconds: 10));
        goTrue.emit(gotrue.AuthChangeEvent.signedOut);
        await Future<void>.delayed(Duration.zero);

        expect(wired.controller.sessionExpired, isTrue);
      });

      test(
          'signedOut without any preceding signOut() sets sessionExpired '
          '(no window set)', () async {
        // Explicitly no signOut() call — _expectedSignOutAt is null → forced.
        final goTrue = _FakeGoTrue(initialUserId: 'u-1');
        addTearDown(goTrue.dispose);
        final wired = _wire(goTrue);
        final sub = wired.container.listen(core.authStateProvider, (_, __) {});
        addTearDown(sub.close);

        goTrue.emit(gotrue.AuthChangeEvent.signedOut);
        await Future<void>.delayed(Duration.zero);

        expect(wired.controller.sessionExpired, isTrue);
      });
    });

    group('observability + retryable errors (§5.4)', () {
      test('stream error does not sign out; breadcrumbs refreshError',
          () async {
        final goTrue = _FakeGoTrue(initialUserId: 'u-1');
        addTearDown(goTrue.dispose);
        final crumbs = <String>[];
        final wired = _wire(goTrue, crumbs: crumbs);
        final sub = wired.container.listen(core.authStateProvider, (_, __) {});
        addTearDown(sub.close);

        goTrue.emitError(StateError('retryable refresh failure'));
        await Future<void>.delayed(Duration.zero);

        // Still authenticated — a retryable error must not sign the user out.
        expect(
          wired.container.read(core.authStateProvider).status,
          core.AuthStatus.authenticated,
        );
        expect(crumbs, contains('refreshError'));
      });

      test('tokenRefreshed + forcedSignOut leave breadcrumbs', () async {
        final goTrue = _FakeGoTrue(initialUserId: 'u-1');
        addTearDown(goTrue.dispose);
        final crumbs = <String>[];
        final wired = _wire(goTrue, crumbs: crumbs);
        final sub = wired.container.listen(core.authStateProvider, (_, __) {});
        addTearDown(sub.close);

        goTrue
          ..emit(gotrue.AuthChangeEvent.tokenRefreshed, userId: 'u-1')
          ..emit(gotrue.AuthChangeEvent.signedOut);
        await Future<void>.delayed(Duration.zero);

        expect(
          crumbs,
          containsAll(<String>['tokenRefreshed', 'forcedSignOut']),
        );
      });

      test('breadcrumb never receives a token or session object', () async {
        final goTrue = _FakeGoTrue(initialUserId: 'u-token');
        addTearDown(goTrue.dispose);
        final crumbs = <String>[];
        final wired = _wire(goTrue, crumbs: crumbs);
        final sub = wired.container.listen(core.authStateProvider, (_, __) {});
        addTearDown(sub.close);

        goTrue.emit(gotrue.AuthChangeEvent.tokenRefreshed, userId: 'u-token');
        await Future<void>.delayed(Duration.zero);

        // Coarse labels only; no access token leaks into the breadcrumb trail.
        for (final c in crumbs) {
          expect(c.contains('access-'), isFalse);
          expect(c.contains('u-token'), isFalse);
        }
      });
    });
  });
}

class _TokenKakao implements KakaoLoginPort {
  const _TokenKakao(this.token);
  final String token;
  @override
  Future<String?> getKakaoIdToken() async => token;
}
