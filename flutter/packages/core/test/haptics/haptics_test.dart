import 'package:core/core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// Hand-written recording fake (no mockito/mocktail, per harness convention).
class _RecordingHaptics implements Haptics {
  final List<HapticIntent> fired = <HapticIntent>[];

  @override
  Future<void> perform(HapticIntent intent) async => fired.add(intent);

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

/// A mutable test clock for deterministic throttle assertions.
class _FakeClock {
  DateTime now = DateTime(2026);

  void advance(Duration d) => now = now.add(d);
  DateTime call() => now;
}

void main() {
  group('NoopHaptics', () {
    test('every call is a no-op and never throws', () async {
      const haptics = NoopHaptics();
      await haptics.perform(HapticIntent.medium);
      await haptics.selection();
      await haptics.light();
      await haptics.medium();
      await haptics.heavy();
      await haptics.success();
      await haptics.warning();
      await haptics.error();
    });
  });

  group('Haptics convenience methods', () {
    test('each delegates to perform with the matching intent', () async {
      final recording = _RecordingHaptics();

      await recording.selection();
      await recording.light();
      await recording.medium();
      await recording.heavy();
      await recording.success();
      await recording.warning();
      await recording.error();

      expect(recording.fired, <HapticIntent>[
        HapticIntent.selection,
        HapticIntent.light,
        HapticIntent.medium,
        HapticIntent.heavy,
        HapticIntent.success,
        HapticIntent.warning,
        HapticIntent.error,
      ]);
    });
  });

  group('ThrottlingHaptics', () {
    test('suppresses a same-intent fire within minInterval', () async {
      final inner = _RecordingHaptics();
      final clock = _FakeClock();
      final haptics = ThrottlingHaptics(inner, clock: clock.call);

      await haptics.selection(); // accepted
      clock.advance(const Duration(milliseconds: 40));
      await haptics.selection(); // dropped (within interval)

      expect(inner.fired, <HapticIntent>[HapticIntent.selection]);
    });

    test('accepts a same-intent fire once minInterval has elapsed', () async {
      final inner = _RecordingHaptics();
      final clock = _FakeClock();
      final haptics = ThrottlingHaptics(inner, clock: clock.call);

      await haptics.selection(); // accepted
      clock.advance(const Duration(milliseconds: 80));
      await haptics.selection(); // accepted (interval elapsed)
      clock.advance(const Duration(milliseconds: 81));
      await haptics.selection(); // accepted

      expect(inner.fired, <HapticIntent>[
        HapticIntent.selection,
        HapticIntent.selection,
        HapticIntent.selection,
      ]);
    });

    test('throttles each intent independently', () async {
      final inner = _RecordingHaptics();
      final clock = _FakeClock();
      final haptics = ThrottlingHaptics(inner, clock: clock.call);

      // Two different intents at the same instant both pass — independent keys.
      await haptics.selection();
      await haptics.success();
      // A second selection at the same instant is dropped; success unaffected.
      await haptics.selection();

      expect(inner.fired, <HapticIntent>[
        HapticIntent.selection,
        HapticIntent.success,
      ]);
    });

    test('first fire of an intent is always accepted', () async {
      final inner = _RecordingHaptics();
      final clock = _FakeClock();
      final haptics = ThrottlingHaptics(inner, clock: clock.call);

      await haptics.error();
      expect(inner.fired, <HapticIntent>[HapticIntent.error]);
    });
  });

  group('hapticsProvider', () {
    test('default binding is NoopHaptics', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      expect(container.read(hapticsProvider), isA<NoopHaptics>());
    });

    test('app can override with a real implementation', () {
      final recording = _RecordingHaptics();
      final container = ProviderContainer(
        overrides: [
          hapticsProvider.overrideWithValue(recording),
        ],
      );
      addTearDown(container.dispose);

      expect(container.read(hapticsProvider), same(recording));
    });
  });

  group('HapticsSettings', () {
    test('enabled by default', () {
      expect(const HapticsSettings().enabled, isTrue);
    });

    test('equality and hashCode by enabled', () {
      expect(const HapticsSettings(), const HapticsSettings());
      expect(
        const HapticsSettings(enabled: false) == const HapticsSettings(),
        isFalse,
      );
      expect(
        const HapticsSettings().hashCode,
        const HapticsSettings().hashCode,
      );
    });
  });
}
