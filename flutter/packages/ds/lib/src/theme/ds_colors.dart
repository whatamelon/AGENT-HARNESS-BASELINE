import 'package:ds/src/color/adaptive_primary.dart';
import 'package:ds/src/gen/colors.dart';
import 'package:flutter/material.dart';

/// Semantic + adaptive-primary color contract, exposed as a [ThemeExtension]
/// so components read `Theme.of(context).extension<DsColors>()!` (or the
/// `context.c` shortcut) instead of touching primitives directly.
///
/// Semantic values are static (light mode). The primary family is injected via
/// [AdaptivePrimary] so a brand seed flows through one source of truth.
@immutable
class DsColors extends ThemeExtension<DsColors> {
  const DsColors({
    required this.primary,
    required this.bg,
    required this.bgSubtle,
    required this.surface,
    required this.surfaceAlt,
    required this.surfaceInset,
    required this.border,
    required this.borderStrong,
    required this.text,
    required this.textMuted,
    required this.textSubtle,
    required this.overlay,
    required this.info,
    required this.success,
    required this.warning,
    required this.danger,
    required this.infoSoft,
    required this.successSoft,
    required this.warningSoft,
    required this.dangerSoft,
  });

  /// Build the semantic palette around an injected [primary] family.
  factory DsColors.light(AdaptivePrimary primary) {
    const softAlpha = 0.12; // tokens.json semantic *Soft alpha
    return DsColors(
      primary: primary,
      bg: DsPrimitive.neutral0,
      bgSubtle: DsPrimitive.neutral50,
      surface: DsPrimitive.neutral0,
      surfaceAlt: DsPrimitive.neutral100,
      surfaceInset: DsPrimitive.neutral150,
      border: DsPrimitive.neutral200,
      borderStrong: DsPrimitive.neutral300,
      text: DsPrimitive.neutralInk,
      textMuted: DsPrimitive.neutral600,
      textSubtle: DsPrimitive.textSubtle,
      overlay: DsPrimitive.overlay,
      info: DsPrimitive.stateInfo,
      success: DsPrimitive.stateSuccess,
      warning: DsPrimitive.stateWarning,
      danger: DsPrimitive.stateDanger,
      infoSoft: DsPrimitive.stateInfo.withValues(alpha: softAlpha),
      successSoft: DsPrimitive.stateSuccess.withValues(alpha: softAlpha),
      warningSoft: DsPrimitive.stateWarning.withValues(alpha: softAlpha),
      dangerSoft: DsPrimitive.stateDanger.withValues(alpha: softAlpha),
    );
  }

  /// Adaptive primary family (primary/pressed/soft/border/onPrimary/focusRing).
  final AdaptivePrimary primary;

  final Color bg;
  final Color bgSubtle;
  final Color surface;
  final Color surfaceAlt;
  final Color surfaceInset;
  final Color border;
  final Color borderStrong;
  final Color text;
  final Color textMuted;
  final Color textSubtle;
  final Color overlay;
  final Color info;
  final Color success;
  final Color warning;
  final Color danger;
  final Color infoSoft;
  final Color successSoft;
  final Color warningSoft;
  final Color dangerSoft;

  /// Shortcut to the on-primary text color.
  Color get onPrimary => primary.onPrimary;

  @override
  DsColors copyWith({AdaptivePrimary? primary}) =>
      primary == null ? this : DsColors.light(primary);

  @override
  DsColors lerp(covariant DsColors? other, double t) {
    // Light-mode-only system: no cross-theme interpolation needed. Snap at
    // the midpoint to keep [ThemeData.lerp] well-behaved.
    if (other == null) return this;
    return t < 0.5 ? this : other;
  }
}

/// Ergonomic access: `context.c.primary.primary`, `context.c.text`, etc.
extension DsColorsContext on BuildContext {
  DsColors get c => Theme.of(this).extension<DsColors>()!;
}
