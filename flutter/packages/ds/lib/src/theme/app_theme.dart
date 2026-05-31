import 'package:ds/src/color/adaptive_primary.dart';
import 'package:ds/src/gen/colors.dart';
import 'package:ds/src/gen/typography.dart';
import 'package:ds/src/theme/ds_colors.dart';
import 'package:flutter/material.dart';

/// Builds the ANDS v2.0 light [ThemeData].
///
/// - ColorScheme derived from the adaptive primary + neutral surfaces.
/// - TextTheme mapped from the Pretendard scale ([DsType]) onto Material slots.
/// - [DsColors] ThemeExtension attached for semantic/adaptive-primary access.
///
/// The system is light-mode-only ([ThemeMode.light]); no dark theme is built.
ThemeData buildTheme({Color seed = DsPrimitive.neutralInk}) {
  final primary = AdaptivePrimary.fromSeed(seed);
  final dsColors = DsColors.light(primary);

  final colorScheme = ColorScheme.light(
    primary: primary.primary,
    onPrimary: primary.onPrimary,
    secondary: dsColors.surfaceAlt,
    onSecondary: dsColors.text,
    surface: dsColors.surface,
    onSurface: dsColors.text,
    error: dsColors.danger,
    outline: dsColors.border,
  );

  return ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    fontFamily: DsType.fontFamily,
    scaffoldBackgroundColor: dsColors.bg,
    colorScheme: colorScheme,
    textTheme: _textTheme(dsColors.text),
    dividerTheme: DividerThemeData(
      color: dsColors.border,
      thickness: 1,
      space: 1,
    ),
    extensions: <ThemeExtension<dynamic>>[dsColors],
  );
}

/// Map the Pretendard scale onto Material text slots. Colors default to [ink];
/// components override per-use via token reads.
TextTheme _textTheme(Color ink) {
  TextStyle s(TextStyle base) => base.copyWith(color: ink);
  return TextTheme(
    displayLarge: s(DsType.display),
    displayMedium: s(DsType.title1),
    displaySmall: s(DsType.title2),
    headlineMedium: s(DsType.title2),
    headlineSmall: s(DsType.title3),
    titleLarge: s(DsType.title3),
    titleMedium: s(DsType.label),
    bodyLarge: s(DsType.bodyLg),
    bodyMedium: s(DsType.body),
    bodySmall: s(DsType.bodySm),
    labelLarge: s(DsType.label),
    labelMedium: s(DsType.caption),
    labelSmall: s(DsType.micro),
  );
}
