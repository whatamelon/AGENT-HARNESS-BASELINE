// ignore_for_file: avoid_print
//
// Token code generator: tokens.json (SSOT) -> lib/src/gen/*.dart.
//
// Usage:
//   dart run tool/gen_tokens.dart           # write generated files
//   dart run tool/gen_tokens.dart --check    # drift gate: nonzero exit if stale
//
// The generated files are committed. `--check` regenerates in-memory and
// compares against disk; any difference exits 1 so CI fails on token drift.
//
// IMPORTANT: Adaptive Primary tokens are NOT emitted here. colors.dart carries
// only static neutral/state/semantic values. The 6 primary tokens
// (primary/pressed/soft/border/onPrimary/focusRing) are computed at runtime by
// AdaptivePrimary.fromSeed — keeping a single source of truth for seed derivation.

import 'dart:convert';
import 'dart:io';

void main(List<String> args) {
  final check = args.contains('--check');
  final root = _packageRoot();
  final tokensFile = File('$root/tokens/tokens.json');
  if (!tokensFile.existsSync()) {
    stderr.writeln('tokens.json not found at ${tokensFile.path}');
    exit(2);
  }

  final tokens = jsonDecode(tokensFile.readAsStringSync()) as Map<String, dynamic>;
  final outputs = <String, String>{
    'lib/src/gen/colors.dart': _genColors(tokens),
    'lib/src/gen/typography.dart': _genTypography(tokens),
    'lib/src/gen/dimens.dart': _genDimens(tokens),
    'lib/src/gen/elevation.dart': _genElevation(tokens),
    'lib/src/gen/motion.dart': _genMotion(tokens),
  };

  if (check) {
    final stale = <String>[];
    for (final entry in outputs.entries) {
      final file = File('$root/${entry.key}');
      final onDisk = file.existsSync() ? file.readAsStringSync() : '';
      if (onDisk != entry.value) stale.add(entry.key);
    }
    if (stale.isNotEmpty) {
      stderr.writeln('Token drift detected. Stale generated files:');
      for (final f in stale) {
        stderr.writeln('  - $f');
      }
      stderr.writeln('Run: dart run tool/gen_tokens.dart');
      exit(1);
    }
    print('Tokens up to date (0 drift).');
    return;
  }

  for (final entry in outputs.entries) {
    File('$root/${entry.key}')
      ..createSync(recursive: true)
      ..writeAsStringSync(entry.value);
    print('wrote ${entry.key}');
  }
}

/// Resolve the package root regardless of invocation cwd (repo root or package).
String _packageRoot() {
  final script = Platform.script.toFilePath();
  // .../packages/ds/tool/gen_tokens.dart -> .../packages/ds
  final idx = script.lastIndexOf('/tool/');
  if (idx != -1) return script.substring(0, idx);
  // Fallback: assume invoked from repo root.
  final fromRoot = Directory('packages/ds');
  if (fromRoot.existsSync()) return fromRoot.path;
  return Directory.current.path;
}

const _header =
    '// GENERATED — do not edit by hand.\n'
    '// Source: packages/ds/tokens/tokens.json\n'
    '// Regenerate: dart run tool/gen_tokens.dart\n';

/// Convert "#RRGGBB" to a Flutter `Color(0xFFRRGGBB)` literal argument.
String _hexToArgb(String hex) {
  final clean = hex.replaceFirst('#', '');
  return '0xFF${clean.toUpperCase()}';
}

String _genColors(Map<String, dynamic> tokens) {
  final primitive = tokens['primitive'] as Map<String, dynamic>;
  final neutral = primitive['neutral'] as Map<String, dynamic>;
  final state = primitive['state'] as Map<String, dynamic>;

  final b = StringBuffer()
    ..writeln(_header)
    ..writeln("import 'dart:ui';")
    ..writeln()
    ..writeln('/// Static neutral ramp (light mode). Names mirror tokens.json keys.')
    ..writeln('///')
    ..writeln('/// Adaptive Primary tokens are intentionally absent — they are computed')
    ..writeln('/// at runtime by [AdaptivePrimary.fromSeed].')
    ..writeln('abstract final class DsPrimitive {');

  // Neutral ramp.
  neutral.forEach((key, value) {
    final v = value as Map<String, dynamic>;
    final light = _hexToArgb(v['light'] as String);
    b.writeln('  static const Color neutral${_neutralName(key)} = Color($light);');
  });

  final textSubtle = primitive['textSubtle'] as Map<String, dynamic>;
  b
    ..writeln('  static const Color textSubtle = Color(${_hexToArgb(textSubtle['light'] as String)});')
    ..writeln();

  // State colors (light).
  state.forEach((key, value) {
    final v = value as Map<String, dynamic>;
    b.writeln('  static const Color state${_cap(key)} = Color(${_hexToArgb(v['light'] as String)});');
  });

  // Overlay (light) — parse rgba().
  final overlay = primitive['overlay'] as Map<String, dynamic>;
  b
    ..writeln('  static const Color overlay = ${_rgbaToColor(overlay['light'] as String)};')
    ..writeln('}');

  return b.toString();
}

String _genTypography(Map<String, dynamic> tokens) {
  final typo = tokens['typography'] as Map<String, dynamic>;
  final family = typo['fontFamily'] as String;
  final scale = typo['scale'] as Map<String, dynamic>;
  final weights = typo['weights'] as Map<String, dynamic>;

  final b = StringBuffer()
    ..writeln(_header)
    ..writeln("import 'package:flutter/widgets.dart';")
    ..writeln()
    ..writeln('/// Pretendard type scale from tokens.json. lineHeight is the multiplier')
    ..writeln('/// captured as Flutter `height` (already a multiple of font size).')
    ..writeln('abstract final class DsType {')
    ..writeln("  static const String fontFamily = '$family';")
    ..writeln();

  // FontWeight constants.
  weights.forEach((name, value) {
    final w = value as int;
    b.writeln('  static const FontWeight ${name} = FontWeight.w$w;');
  });
  b.writeln();

  scale.forEach((name, value) {
    final v = value as Map<String, dynamic>;
    final size = (v['size'] as num).toDouble();
    final height = (v['lineHeight'] as num).toDouble();
    final weight = v['weight'] as int;
    final ls = (v['letterSpacing'] as num).toDouble();
    b
      ..writeln('  static const TextStyle $name = TextStyle(')
      ..writeln('    fontFamily: fontFamily,')
      ..writeln('    fontSize: ${_d(size)},')
      ..writeln('    height: ${_d(height)},')
      ..writeln('    fontWeight: FontWeight.w$weight,')
      ..writeln('    letterSpacing: ${_d(ls)},')
      ..writeln('  );');
  });

  b.writeln('}');
  return b.toString();
}

String _genDimens(Map<String, dynamic> tokens) {
  final space = tokens['space'] as Map<String, dynamic>;
  final radii = tokens['radii'] as Map<String, dynamic>;
  final stateTok = tokens['state'] as Map<String, dynamic>;

  final b = StringBuffer()
    ..writeln(_header)
    ..writeln('/// Spacing scale (4dp base) from tokens.json.')
    ..writeln('abstract final class Space {');
  space.forEach((key, value) {
    b.writeln('  static const double $key = ${_d((value as num).toDouble())};');
  });
  b
    ..writeln('}')
    ..writeln()
    ..writeln('/// Corner radii from tokens.json.')
    ..writeln('abstract final class Radii {');
  radii.forEach((key, value) {
    b.writeln('  static const double $key = ${_d((value as num).toDouble())};');
  });
  b
    ..writeln('}')
    ..writeln()
    ..writeln('/// Interaction state constants (overlay alphas, press scale).')
    ..writeln('abstract final class DsState {');
  stateTok.forEach((key, value) {
    b.writeln('  static const double $key = ${_d((value as num).toDouble())};');
  });
  b.writeln('}');
  return b.toString();
}

String _genElevation(Map<String, dynamic> tokens) {
  final elevation = tokens['elevation'] as Map<String, dynamic>;

  final b = StringBuffer()
    ..writeln(_header)
    ..writeln("import 'package:flutter/widgets.dart';")
    ..writeln()
    ..writeln('/// Elevation shadow tokens from tokens.json. Each level is a ready-to-use')
    ..writeln('/// `List<BoxShadow>` for `BoxDecoration.boxShadow`; `e0` is no shadow.')
    ..writeln('///')
    ..writeln('/// ANDS keeps shadow use sparing — reserve `e3` for floating layers')
    ..writeln('/// (dialogs, snackbars) and prefer hairline borders on flat surfaces.')
    ..writeln('abstract final class Elevation {');
  elevation.forEach((key, value) {
    final name = 'e$key';
    if (value == null) {
      b.writeln('  static const List<BoxShadow> $name = <BoxShadow>[];');
      return;
    }
    final v = value as Map<String, dynamic>;
    final x = (v['x'] as num).toDouble();
    final y = (v['y'] as num).toDouble();
    final blur = (v['blur'] as num).toDouble();
    final color = _rgbaToColor(v['color'] as String);
    b
      ..writeln('  static const List<BoxShadow> $name = <BoxShadow>[')
      ..writeln('    BoxShadow(')
      ..writeln('      color: $color,')
      ..writeln('      offset: Offset(${_d(x)}, ${_d(y)}),')
      ..writeln('      blurRadius: ${_d(blur)},')
      ..writeln('    ),')
      ..writeln('  ];');
  });
  b.writeln('}');
  return b.toString();
}

String _genMotion(Map<String, dynamic> tokens) {
  final motion = tokens['motion'] as Map<String, dynamic>;

  final b = StringBuffer()
    ..writeln(_header)
    ..writeln("import 'package:flutter/animation.dart';")
    ..writeln()
    ..writeln('/// Motion durations and curves from tokens.json.')
    ..writeln('abstract final class Motion {');
  motion.forEach((name, value) {
    final v = value as Map<String, dynamic>;
    final ms = v['ms'] as int;
    final curve = _curve(v['curve'] as String);
    b
      ..writeln('  static const Duration ${name}Duration = Duration(milliseconds: $ms);')
      ..writeln('  static const Curve ${name}Curve = $curve;');
  });
  b.writeln('}');
  return b.toString();
}

// ---- helpers ----------------------------------------------------------------

/// Format a double so 8.0 -> "8.0" (Dart double literal, never bare int).
String _d(double v) {
  if (v == v.roundToDouble()) return '${v.toInt()}.0';
  return v.toString();
}

String _cap(String s) => s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);

/// Neutral key -> Dart-safe identifier suffix ("0" -> "0", "ink" -> "Ink").
String _neutralName(String key) {
  final asInt = int.tryParse(key);
  if (asInt != null) return key;
  return _cap(key);
}

String _curve(String token) {
  switch (token) {
    case 'easeOutCubic':
      return 'Curves.easeOutCubic';
    case 'easeOutQuart':
      return 'Curves.easeOutQuart';
    default:
      return 'Curves.easeOut';
  }
}

/// "rgba(17,17,20,0.45)" -> Color.fromARGB(...) literal.
String _rgbaToColor(String rgba) {
  final inner = rgba.substring(rgba.indexOf('(') + 1, rgba.indexOf(')'));
  final parts = inner.split(',').map((s) => s.trim()).toList();
  final r = int.parse(parts[0]);
  final g = int.parse(parts[1]);
  final b = int.parse(parts[2]);
  final a = (double.parse(parts[3]) * 255).round();
  return 'Color.fromARGB($a, $r, $g, $b)';
}
