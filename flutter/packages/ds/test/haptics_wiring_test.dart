import 'package:core/core.dart';
import 'package:ds/ds.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// Haptic seam wiring for ds interactive components.
///
/// Two contracts are proven here:
///   (a) Default behaviour is unchanged — with no `ProviderScope` override the
///       provider resolves to `NoopHaptics`, so interactions fire *no* haptic
///       and the component still renders/behaves exactly as before. Components
///       embedded with no `ProviderScope` at all (golden tests) must not crash.
///   (b) When an app overrides `hapticsProvider`, each component fires the
///       correct [HapticIntent] on its interaction.
///
/// No mocking framework: [_RecordingHaptics] is a hand-written fake that
/// records every intent it is asked to perform.
void main() {
  late _RecordingHaptics recorder;

  setUp(() => recorder = _RecordingHaptics());

  /// Hosts [child] WITHOUT a [ProviderScope]. Exercises the fallback path
  /// (`componentHaptics` returns `NoopHaptics`, never throws).
  Widget bareHost(Widget child) => MaterialApp(
        theme: buildTheme(),
        home: Scaffold(body: Center(child: child)),
      );

  /// Hosts [child] under a [ProviderScope] whose `hapticsProvider` is
  /// overridden with [recorder].
  Widget recordingHost(Widget child) => ProviderScope(
        overrides: [hapticsProvider.overrideWithValue(recorder)],
        child: bareHost(child),
      );

  /// Hosts [child] under a [ProviderScope] with the DEFAULT (NoopHaptics)
  /// wiring — used to assert the default never routes through the recorder.
  Widget defaultScopeHost(Widget child) => ProviderScope(
        child: bareHost(child),
      );

  group('(a) default behaviour unchanged (Noop / no override)', () {
    testWidgets('DsButton: no ProviderScope -> tap works, no crash, no haptic',
        (tester) async {
      var tapped = false;
      await tester.pumpWidget(
        bareHost(DsButton(label: '결제하기', onPressed: () => tapped = true)),
      );
      await tester.tap(find.byType(DsButton));
      await tester.pump();
      expect(tapped, isTrue, reason: 'onPressed must still fire');
      expect(
        recorder.intents,
        isEmpty,
        reason: 'no override installed -> recorder untouched',
      );
    });

    testWidgets('DsButton: default ProviderScope (Noop) records no haptic',
        (tester) async {
      var tapped = false;
      await tester.pumpWidget(
        defaultScopeHost(
          DsButton(label: '결제하기', onPressed: () => tapped = true),
        ),
      );
      await tester.tap(find.byType(DsButton));
      await tester.pump();
      expect(tapped, isTrue);
      expect(recorder.intents, isEmpty);
    });

    testWidgets('DsChip: no ProviderScope -> tap works, no haptic',
        (tester) async {
      var tapped = false;
      await tester.pumpWidget(
        bareHost(DsChip(label: '예약', onTap: () => tapped = true)),
      );
      await tester.tap(find.byType(DsChip));
      await tester.pump();
      expect(tapped, isTrue);
      expect(recorder.intents, isEmpty);
    });

    testWidgets('DsTextField: error with no scope -> no crash, no haptic',
        (tester) async {
      await tester.pumpWidget(
        bareHost(const DsTextField(label: '이메일')),
      );
      // Transition into error — the seam reads context but no scope exists.
      await tester.pumpWidget(
        bareHost(
          const DsTextField(
            label: '이메일',
            status: DsFieldStatus.error,
            helper: '형식이 올바르지 않습니다.',
          ),
        ),
      );
      await tester.pump();
      expect(tester.takeException(), isNull);
      expect(recorder.intents, isEmpty);
    });
  });

  group('(b) override fires the correct intent', () {
    testWidgets('DsButton primary -> light', (tester) async {
      await tester.pumpWidget(
        recordingHost(DsButton(label: '결제하기', onPressed: () {})),
      );
      await tester.tap(find.byType(DsButton));
      await tester.pump();
      expect(recorder.intents, [HapticIntent.light]);
    });

    testWidgets('DsButton destructive -> warning', (tester) async {
      await tester.pumpWidget(
        recordingHost(
          DsButton(
            label: '삭제',
            variant: DsButtonVariant.destructive,
            onPressed: () {},
          ),
        ),
      );
      await tester.tap(find.byType(DsButton));
      await tester.pump();
      expect(recorder.intents, [HapticIntent.warning]);
    });

    testWidgets('DsButton disabled -> no haptic', (tester) async {
      await tester.pumpWidget(
        recordingHost(const DsButton(label: '결제하기', onPressed: null)),
      );
      await tester.tap(find.byType(DsButton), warnIfMissed: false);
      await tester.pump();
      expect(recorder.intents, isEmpty);
    });

    testWidgets('DsChip toggle -> selection', (tester) async {
      await tester.pumpWidget(
        recordingHost(DsChip(label: '예약', onTap: () {})),
      );
      await tester.tap(find.byType(DsChip));
      await tester.pump();
      expect(recorder.intents, [HapticIntent.selection]);
    });

    testWidgets('DsChip with null onTap -> no haptic', (tester) async {
      await tester.pumpWidget(
        recordingHost(const DsChip(label: '예약')),
      );
      await tester.tap(find.byType(DsChip), warnIfMissed: false);
      await tester.pump();
      expect(recorder.intents, isEmpty);
    });

    testWidgets('DsTextField entering error -> error (once)', (tester) async {
      await tester.pumpWidget(
        recordingHost(const DsTextField(label: '이메일')),
      );
      // normal -> error transition.
      await tester.pumpWidget(
        recordingHost(
          const DsTextField(
            label: '이메일',
            status: DsFieldStatus.error,
            helper: '형식이 올바르지 않습니다.',
          ),
        ),
      );
      await tester.pump();
      expect(recorder.intents, [HapticIntent.error]);

      // Staying in error on a further rebuild must NOT re-fire.
      await tester.pumpWidget(
        recordingHost(
          const DsTextField(
            label: '이메일',
            status: DsFieldStatus.error,
            helper: '형식이 올바르지 않습니다.',
          ),
        ),
      );
      await tester.pump();
      expect(
        recorder.intents,
        [HapticIntent.error],
        reason: 'error fires on entry only, not on every rebuild',
      );
    });

    testWidgets('DsTextField normal -> success does not fire error',
        (tester) async {
      await tester.pumpWidget(
        recordingHost(const DsTextField(label: '이메일')),
      );
      await tester.pumpWidget(
        recordingHost(
          const DsTextField(label: '이메일', status: DsFieldStatus.success),
        ),
      );
      await tester.pump();
      expect(recorder.intents, isEmpty);
    });

    testWidgets('showDsBottomSheet open -> light', (tester) async {
      // Trigger via a plain GestureDetector (not DsButton) so the only haptic
      // recorded is the sheet's own open intent.
      await tester.pumpWidget(
        recordingHost(
          Builder(
            builder: (context) => GestureDetector(
              onTap: () => showDsBottomSheet<void>(
                context: context,
                builder: (_) => const Text('내용'),
              ),
              child: const Text('open'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      expect(recorder.intents, [HapticIntent.light]);
    });

    testWidgets('showDsSnackbar tone -> success/error fire, info silent',
        (tester) async {
      Future<void> fire(DsSnackTone tone) async {
        await tester.pumpWidget(
          recordingHost(
            Builder(
              builder: (context) => GestureDetector(
                onTap: () => showDsSnackbar(
                  context: context,
                  message: '알림',
                  tone: tone,
                ),
                child: const Text('show'),
              ),
            ),
          ),
        );
        await tester.tap(find.text('show'));
        await tester.pump();
      }

      await fire(DsSnackTone.success);
      expect(recorder.intents, [HapticIntent.success]);

      recorder.intents.clear();
      await fire(DsSnackTone.error);
      expect(recorder.intents, [HapticIntent.error]);

      recorder.intents.clear();
      await fire(DsSnackTone.info);
      expect(
        recorder.intents,
        isEmpty,
        reason: 'info is a neutral notice — no haptic',
      );
    });

    testWidgets('showDsDialog destructive confirm -> warning (once)',
        (tester) async {
      await tester.pumpWidget(
        recordingHost(
          Builder(
            builder: (context) => GestureDetector(
              onTap: () => showDsDialog(
                context: context,
                title: '삭제할까요?',
                confirmLabel: '삭제',
                variant: DsDialogVariant.destructive,
              ),
              child: const Text('open'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('삭제'));
      await tester.pump();
      // The destructive confirm CTA is a destructive DsButton -> one warning.
      // showDsDialog deliberately adds no second warning (no double buzz).
      expect(recorder.intents, [HapticIntent.warning]);
    });

    testWidgets('showDsDialog neutral confirm -> light (primary button)',
        (tester) async {
      await tester.pumpWidget(
        recordingHost(
          Builder(
            builder: (context) => GestureDetector(
              onTap: () => showDsDialog(
                context: context,
                title: '진행할까요?',
              ),
              child: const Text('open'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      // Neutral confirm CTA is a primary DsButton -> light (low-stakes).
      await tester.tap(find.text('확인'));
      await tester.pump();
      expect(recorder.intents, [HapticIntent.light]);
    });
  });
}

/// Hand-written [Haptics] fake that records the intents it is asked to perform.
class _RecordingHaptics implements Haptics {
  final List<HapticIntent> intents = <HapticIntent>[];

  @override
  Future<void> perform(HapticIntent intent) async => intents.add(intent);

  @override
  Future<void> selection() => perform(HapticIntent.selection);

  @override
  Future<void> light() => perform(HapticIntent.light);

  @override
  Future<void> medium() => perform(HapticIntent.medium);

  @override
  Future<void> heavy() => perform(HapticIntent.heavy);

  @override
  Future<void> success() => perform(HapticIntent.success);

  @override
  Future<void> warning() => perform(HapticIntent.warning);

  @override
  Future<void> error() => perform(HapticIntent.error);
}
