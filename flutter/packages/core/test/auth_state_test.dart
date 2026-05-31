import 'package:core/core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AuthState', () {
    test('default stub is unauthenticated', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final state = container.read(authStateProvider);
      expect(state.status, AuthStatus.unauthenticated);
      expect(state.isAuthenticated, isFalse);
      expect(state.userId, isNull);
    });

    test('authenticated factory sets status and id', () {
      final state = AuthState.authenticated('u1');
      expect(state.status, AuthStatus.authenticated);
      expect(state.isAuthenticated, isTrue);
      expect(state.userId, 'u1');
    });

    test('equality by status and userId', () {
      expect(AuthState.authenticated('u1'), AuthState.authenticated('u1'));
      expect(
        AuthState.authenticated('u1') == AuthState.authenticated('u2'),
        isFalse,
      );
      expect(
        AuthState.authenticated('u1').hashCode,
        AuthState.authenticated('u1').hashCode,
      );
      expect(AuthState.unauthenticated.isAuthenticated, isFalse);
    });

    test('signOut stub is a no-op and keeps state', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      await container.read(authStateProvider.notifier).signOut();
      expect(container.read(authStateProvider).isAuthenticated, isFalse);
    });
  });
}
