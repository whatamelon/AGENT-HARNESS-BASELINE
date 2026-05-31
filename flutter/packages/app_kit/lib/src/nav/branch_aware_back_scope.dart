/// Branch-aware system-back handling (§4.3) built on the current
/// [PopScope] / `onPopInvokedWithResult` API (`WillPopScope` is removed and
/// `onPopInvoked` is deprecated).
///
/// Two small widgets, no Riverpod, no app-domain knowledge:
/// - [BranchAwareBackScope]: a branch root's back policy. Non-home tabs send
///   system-back to the home tab (toss pattern); the home tab requires a
///   double-tap within 2s to exit (당근/토스 pattern).
/// - [UnsavedGuard]: a dirty-form guard that asks for discard confirmation
///   before allowing a pop.
///
/// Predictive-back (Android 14): `canPop` is kept *truthful* — `false` only
/// while we actually intercept — so the OS animation matches reality.
library;

import 'dart:async' show unawaited;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show SystemNavigator;

/// Wraps a branch root with branch-aware system-back behavior.
///
/// Place this around the content of each tab's root route. It never pops the
/// route itself; instead it routes the back gesture to the injected callbacks.
class BranchAwareBackScope extends StatefulWidget {
  /// Creates a [BranchAwareBackScope].
  const BranchAwareBackScope({
    required this.isHomeTab,
    required this.onGoHomeTab,
    required this.child,
    this.exitHintText = '한 번 더 누르면 종료됩니다',
    this.doubleTapWindow = const Duration(seconds: 2),
    super.key,
  });

  /// Whether the wrapped branch is the home tab. The home tab uses the
  /// double-tap-to-exit policy; every other tab redirects to the home tab.
  final bool isHomeTab;

  /// Invoked when a non-home tab receives system-back: switch to the home tab
  /// (the caller owns the actual tab switch).
  final VoidCallback onGoHomeTab;

  /// The branch content.
  final Widget child;

  /// Snackbar text shown on the first home-tab back press.
  final String exitHintText;

  /// How long the second back press has to arrive to confirm exit.
  final Duration doubleTapWindow;

  @override
  State<BranchAwareBackScope> createState() => _BranchAwareBackScopeState();
}

class _BranchAwareBackScopeState extends State<BranchAwareBackScope> {
  DateTime? _lastBackAt;

  void _handlePop(bool didPop) {
    if (didPop) return;
    if (!widget.isHomeTab) {
      widget.onGoHomeTab();
      return;
    }
    final now = DateTime.now();
    final last = _lastBackAt;
    if (last == null || now.difference(last) > widget.doubleTapWindow) {
      _lastBackAt = now;
      ScaffoldMessenger.maybeOf(context)
        ?..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(widget.exitHintText),
            duration: widget.doubleTapWindow,
          ),
        );
      return;
    }
    unawaited(SystemNavigator.pop());
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      // Branch roots always intercept system-back; we never let the framework
      // pop the branch route itself.
      canPop: false,
      onPopInvokedWithResult: (didPop, _) => _handlePop(didPop),
      child: widget.child,
    );
  }
}

/// Guards a dirty form against accidental back-dismissal (§4.3).
///
/// While [isDirty] is `true`, system-back is intercepted and [onConfirmDiscard]
/// runs (e.g. a discard bottom sheet that returns `true` to discard). If the
/// user confirms, [onConfirmedPop] performs the actual navigation (the guard
/// never pops on the caller's behalf, avoiding double-pop). When the form is
/// clean, `canPop` is `true` so back works natively (predictive-back friendly).
class UnsavedGuard extends StatelessWidget {
  /// Creates an [UnsavedGuard].
  const UnsavedGuard({
    required this.isDirty,
    required this.onConfirmDiscard,
    required this.onConfirmedPop,
    required this.child,
    super.key,
  });

  /// Whether the form has unsaved changes. When `false`, back is unguarded.
  final bool isDirty;

  /// Asks the user to discard; resolves `true` to proceed with the pop.
  final Future<bool> Function() onConfirmDiscard;

  /// Performs the actual pop once discard is confirmed (caller-owned).
  final VoidCallback onConfirmedPop;

  /// The guarded form content.
  final Widget child;

  Future<void> _handlePop(bool didPop) async {
    if (didPop) return;
    final shouldPop = await onConfirmDiscard();
    if (shouldPop) onConfirmedPop();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !isDirty,
      onPopInvokedWithResult: (didPop, _) => unawaited(_handlePop(didPop)),
      child: child,
    );
  }
}
