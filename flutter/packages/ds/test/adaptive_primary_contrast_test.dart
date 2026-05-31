import 'package:ds/ds.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// B-2 gate (DESIGN-HARNESS): for any injected seed, the derived on-primary
/// text color must clear WCAG 4.5:1 against the seed.
void main() {
  // Seven representative seeds spanning dark, saturated, mid-luminance grey,
  // and a deliberately light/yellow seed that must flip on-primary to ink.
  const seeds = <String, Color>{
    'ink #111114': Color(0xFF111114),
    'info #2E6FF2': Color(0xFF2E6FF2),
    'danger #E5342B': Color(0xFFE5342B),
    'yellow #F5C518': Color(0xFFF5C518),
    'success #16A34A': Color(0xFF16A34A),
    'purple #8E44AD': Color(0xFF8E44AD),
    'mid-grey #808080': Color(0xFF808080),
  };

  group('AdaptivePrimary.fromSeed — B-2 on-primary contrast', () {
    seeds.forEach((name, seed) {
      test('$name yields on-primary >= 4.5:1', () {
        final p = AdaptivePrimary.fromSeed(seed);
        final ratio = contrastRatio(p.onPrimary, p.primary);
        expect(
          ratio,
          greaterThanOrEqualTo(4.5),
          reason: '$name on-primary contrast was $ratio',
        );
      });
    });

    test('light yellow seed flips on-primary to ink (not white)', () {
      final p = AdaptivePrimary.fromSeed(const Color(0xFFF5C518));
      expect(p.onPrimary, DsPrimitive.neutralInk);
    });

    test('dark ink seed keeps on-primary white', () {
      final p = AdaptivePrimary.fromSeed();
      expect(p.onPrimary, DsPrimitive.neutral0);
    });

    test('default seed is ink', () {
      final p = AdaptivePrimary.fromSeed();
      expect(p.seed, DsPrimitive.neutralInk);
    });

    test('derived alphas match token spec', () {
      final p = AdaptivePrimary.fromSeed(const Color(0xFF2E6FF2));
      expect(p.soft.a, closeTo(0.10, 0.001));
      expect(p.border.a, closeTo(0.24, 0.001));
      expect(p.focusRing.a, closeTo(0.40, 0.001));
    });

    test('pressed is darker than seed (lightness -7%)', () {
      const seed = Color(0xFF2E6FF2);
      final p = AdaptivePrimary.fromSeed(seed);
      final seedL = HSLColor.fromColor(seed).lightness;
      final pressedL = HSLColor.fromColor(p.pressed).lightness;
      expect(pressedL, lessThan(seedL));
      // Tolerance covers HSL<->Color 8-bit round-trip quantization.
      expect(pressedL, closeTo((seedL - 0.07).clamp(0.0, 1.0), 0.01));
    });
  });
}
