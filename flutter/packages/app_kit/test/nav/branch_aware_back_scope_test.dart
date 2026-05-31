import 'package:app_kit/src/nav/branch_aware_back_scope.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// Sends a platform system-back (predictive-back / hardware back) to the
/// engine, driving [PopScope.onPopInvokedWithResult].
Future<void> _systemBack(WidgetTester tester) async {
  await tester.binding.defaultBinaryMessenger.handlePlatformMessage(
    'flutter/navigation',
    const JSONMethodCodec().encodeMethodCall(
      const MethodCall('popRoute'),
    ),
    (_) {},
  );
  await tester.pumpAndSettle();
}

void main() {
  group('BranchAwareBackScope', () {
    testWidgets('non-home tab system-back invokes onGoHomeTab', (tester) async {
      var wentHome = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: BranchAwareBackScope(
              isHomeTab: false,
              onGoHomeTab: () => wentHome++,
              child: const Text('design tab'),
            ),
          ),
        ),
      );

      await _systemBack(tester);
      expect(wentHome, 1);
      expect(find.byType(SnackBar), findsNothing);
    });

    testWidgets('home tab requires double-tap within window to exit',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: BranchAwareBackScope(
              isHomeTab: true,
              onGoHomeTab: () {},
              child: const Text('home tab'),
            ),
          ),
        ),
      );

      // First back: shows the hint snackbar, does not exit.
      await _systemBack(tester);
      expect(find.text('한 번 더 누르면 종료됩니다'), findsOneWidget);

      // Second back within the window: would call SystemNavigator.pop().
      // We only assert it does not throw and the widget survives.
      await _systemBack(tester);
      expect(find.text('home tab'), findsOneWidget);
    });

    testWidgets('home tab back after the window resets (no exit)',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: BranchAwareBackScope(
              isHomeTab: true,
              onGoHomeTab: () {},
              doubleTapWindow: const Duration(milliseconds: 300),
              child: const Text('home tab'),
            ),
          ),
        ),
      );

      await _systemBack(tester);
      expect(find.byType(SnackBar), findsOneWidget);
      // Let the window lapse; the next back should be treated as a first tap.
      await tester.pump(const Duration(milliseconds: 500));
      await _systemBack(tester);
      expect(find.text('home tab'), findsOneWidget);
    });
  });

  group('UnsavedGuard', () {
    testWidgets('dirty form intercepts back and asks to discard',
        (tester) async {
      var confirmCalls = 0;
      var poppedFor = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: UnsavedGuard(
              isDirty: true,
              onConfirmDiscard: () async {
                confirmCalls++;
                return false; // user cancels -> stay.
              },
              onConfirmedPop: () => poppedFor++,
              child: const Text('dirty form'),
            ),
          ),
        ),
      );

      await _systemBack(tester);
      expect(confirmCalls, 1);
      expect(poppedFor, 0); // not confirmed -> no pop.
      expect(find.text('dirty form'), findsOneWidget);
    });

    testWidgets('confirmed discard calls onConfirmedPop', (tester) async {
      var poppedFor = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: UnsavedGuard(
              isDirty: true,
              onConfirmDiscard: () async => true,
              onConfirmedPop: () => poppedFor++,
              child: const Text('dirty form'),
            ),
          ),
        ),
      );

      await _systemBack(tester);
      expect(poppedFor, 1);
    });

    testWidgets('clean form does not intercept (canPop true)', (tester) async {
      var confirmCalls = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: UnsavedGuard(
              isDirty: false,
              onConfirmDiscard: () async {
                confirmCalls++;
                return true;
              },
              onConfirmedPop: () {},
              child: const Text('clean form'),
            ),
          ),
        ),
      );

      // With canPop:true and nothing to pop (root route), the discard
      // confirm must not run.
      await _systemBack(tester);
      expect(confirmCalls, 0);
    });
  });
}
