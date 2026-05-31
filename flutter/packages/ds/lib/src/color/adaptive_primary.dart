import 'dart:math' as math;

import 'package:ds/src/gen/colors.dart';
import 'package:flutter/widgets.dart';

/// The six Adaptive Primary tokens derived from a single seed color.
///
/// Per ANDS v2.0 (tokens.json `primary.derive`), these are computed at runtime
/// rather than baked into generated code — so any injected brand seed yields a
/// consistent, contrast-safe primary family.
///
/// Derivation (from tokens.json):
/// - [pressed]   : seed lightness −7% (HSL)
/// - [soft]      : seed @ 10% alpha
/// - [border]    : seed @ 24% alpha
/// - [focusRing] : seed @ 40% alpha
/// - [onPrimary] : tiered for >=4.5:1 contrast —
///                 (1) luminance(seed) < 0.5 ? neutral/0 : neutral/ink;
///                 (2) flip to the other neutral if (1) fails the floor;
///                 (3) pure WCAG endpoint (#000000/#FFFFFF) if both neutrals fail
///                     (saturated mid-luminance seeds, e.g. #2E6FF2 / #E5342B).
@immutable
class AdaptivePrimary {
  const AdaptivePrimary({
    required this.seed,
    required this.primary,
    required this.pressed,
    required this.soft,
    required this.border,
    required this.onPrimary,
    required this.focusRing,
  });

  /// Build the primary family from a [seed]. Defaults to ink (#111114).
  factory AdaptivePrimary.fromSeed([Color seed = DsPrimitive.neutralInk]) {
    final onPrimary = _readableOn(seed);
    return AdaptivePrimary(
      seed: seed,
      primary: seed,
      pressed: _adjustLightness(seed, _pressedLightnessDelta),
      soft: seed.withValues(alpha: _softAlpha),
      border: seed.withValues(alpha: _borderAlpha),
      onPrimary: onPrimary,
      focusRing: seed.withValues(alpha: _focusAlpha),
    );
  }

  final Color seed;
  final Color primary;
  final Color pressed;
  final Color soft;
  final Color border;
  final Color onPrimary;
  final Color focusRing;

  // Derive constants — mirror tokens.json `primary.derive` / `state`.
  static const double _pressedLightnessDelta = -0.07;
  static const double _softAlpha = 0.10;
  static const double _borderAlpha = 0.24;
  static const double _focusAlpha = 0.40;
  static const double _onPrimaryMinContrast = 4.5;

  // Pure contrast extremes. Not design tokens — these are the WCAG mathematical
  // endpoints used only as an on-primary escalation when the neutral surfaces
  // (neutral/0, neutral/ink) cannot themselves clear 4.5:1 against a saturated
  // mid-luminance seed. #2E6FF2 and #E5342B are examples of seeds that DO reach
  // this escalation branch (both neutrals fall short; pure black/white is needed).
  // Typical dark/light seeds (ink, white, pastels) resolve at tier 1 or 2.
  static const Color _pureWhite = Color(0xFFFFFFFF);
  static const Color _pureBlack = Color(0xFF000000);

  /// Pick a readable on-primary text color, enforcing the 4.5:1 minimum.
  ///
  /// 1. Token pick: `luminance(seed) < 0.5 ? neutral/0 : neutral/ink`.
  /// 2. If it fails the floor, flip to the alternative token.
  /// 3. If both tokens fail (mid-luminance saturated seeds), escalate to the
  ///    pure WCAG extreme (#FFFFFF / #000000) on the higher-contrast side.
  /// Never returns a pairing below 4.5:1.
  static Color _readableOn(Color seed) {
    const white = DsPrimitive.neutral0;
    const ink = DsPrimitive.neutralInk;
    final initial = seed.computeLuminance() < 0.5 ? white : ink;
    if (contrastRatio(initial, seed) >= _onPrimaryMinContrast) return initial;

    final alternative = initial == white ? ink : white;
    if (contrastRatio(alternative, seed) >= _onPrimaryMinContrast) {
      return alternative;
    }

    // Neither neutral surface clears the floor: escalate to the pure extreme.
    final blackRatio = contrastRatio(_pureBlack, seed);
    final whiteRatio = contrastRatio(_pureWhite, seed);
    return blackRatio >= whiteRatio ? _pureBlack : _pureWhite;
  }

  /// Shift a color's HSL lightness by [delta] (clamped 0..1).
  static Color _adjustLightness(Color color, double delta) {
    final hsl = HSLColor.fromColor(color);
    final next = (hsl.lightness + delta).clamp(0.0, 1.0);
    return hsl.withLightness(next).toColor();
  }

  AdaptivePrimary copyWith({Color? seed}) =>
      seed == null ? this : AdaptivePrimary.fromSeed(seed);

  @override
  bool operator ==(Object other) =>
      other is AdaptivePrimary &&
      other.seed == seed &&
      other.primary == primary &&
      other.pressed == pressed &&
      other.soft == soft &&
      other.border == border &&
      other.onPrimary == onPrimary &&
      other.focusRing == focusRing;

  @override
  int get hashCode =>
      Object.hash(seed, primary, pressed, soft, border, onPrimary, focusRing);
}

/// WCAG 2.x relative-luminance contrast ratio between two opaque colors.
///
/// Exposed for tests (B-2/B-3 gates) and on-primary derivation.
double contrastRatio(Color a, Color b) {
  final la = a.computeLuminance();
  final lb = b.computeLuminance();
  final lighter = math.max(la, lb);
  final darker = math.min(la, lb);
  return (lighter + 0.05) / (darker + 0.05);
}
