// GENERATED — do not edit by hand.
// Source: packages/ds/tokens/tokens.json
// Regenerate: dart run tool/gen_tokens.dart

/// Spacing scale (4dp base) from tokens.json.
abstract final class Space {
  static const double x1 = 4.0;
  static const double x2 = 8.0;
  static const double x3 = 12.0;
  static const double x4 = 16.0;
  static const double x5 = 20.0;
  static const double x6 = 24.0;
  static const double x8 = 32.0;
  static const double x10 = 40.0;
  static const double x12 = 48.0;
}

/// Corner radii from tokens.json.
abstract final class Radii {
  static const double sm = 8.0;
  static const double md = 12.0;
  static const double lg = 16.0;
  static const double sheet = 20.0;
  static const double full = 999.0;
}

/// Interaction state constants (overlay alphas, press scale).
abstract final class DsState {
  static const double pressedInkOverlay = 0.12;
  static const double pressScale = 0.98;
  static const double softAlpha = 0.1;
  static const double borderAlpha = 0.24;
  static const double focusAlpha = 0.4;
  static const double stateSoftAlpha = 0.12;
}
