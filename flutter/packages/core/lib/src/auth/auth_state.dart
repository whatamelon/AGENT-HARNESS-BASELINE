/// Read-only authentication state surface.
///
/// This is the §8-B one-way boundary: the shell (app_kit) and routing redirect
/// subscribe to [authStateProvider] WITHOUT knowing how auth is implemented.
/// `core` therefore never depends on a concrete auth implementation; P3 wires
/// Supabase by overriding [authStateProvider] / filling [AuthController].
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:meta/meta.dart';

/// Coarse authentication status.
enum AuthStatus {
  /// Initial / not yet resolved (e.g. session restore in flight).
  unknown,

  /// A user session is active.
  authenticated,

  /// No active user session.
  unauthenticated,
}

/// Immutable snapshot of the current auth state.
@immutable
class AuthState {
  /// Creates an [AuthState].
  const AuthState({
    this.status = AuthStatus.unauthenticated,
    this.userId,
  });

  /// Builds an authenticated state for [userId].
  factory AuthState.authenticated(String userId) => AuthState(
        status: AuthStatus.authenticated,
        userId: userId,
      );

  /// The unknown/initial state.
  static const AuthState unknown = AuthState(status: AuthStatus.unknown);

  /// The signed-out state.
  static const AuthState unauthenticated = AuthState();

  /// Current status.
  final AuthStatus status;

  /// Authenticated user id, or `null` when not authenticated.
  final String? userId;

  /// Whether a user is currently authenticated.
  bool get isAuthenticated => status == AuthStatus.authenticated;

  @override
  bool operator ==(Object other) =>
      other is AuthState && other.status == status && other.userId == userId;

  @override
  int get hashCode => Object.hash(status, userId);
}

/// Holds and exposes [AuthState].
///
/// P0 stub: starts [AuthState.unauthenticated] and mutating methods are no-ops.
/// P3 overrides [authStateProvider] with a Supabase-backed controller that
/// emits real session changes and implements these methods.
class AuthController extends Notifier<AuthState> {
  @override
  AuthState build() => AuthState.unauthenticated;

  /// Signs the current user out.
  ///
  // TODO(p3): wire to Supabase auth.signOut() and update state.
  Future<void> signOut() async {
    // No-op stub. P3 fills this in.
  }
}

/// The read-only auth surface for the rest of the app.
///
/// Consumers (router/shell) read this provider only; they never import or
/// reference any auth implementation directly. P3 supplies the real controller
/// via `ProviderScope` override.
final NotifierProvider<AuthController, AuthState> authStateProvider =
    NotifierProvider<AuthController, AuthState>(AuthController.new);
