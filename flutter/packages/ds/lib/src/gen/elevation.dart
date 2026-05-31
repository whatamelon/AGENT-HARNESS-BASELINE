// GENERATED — do not edit by hand.
// Source: packages/ds/tokens/tokens.json
// Regenerate: dart run tool/gen_tokens.dart

import 'package:flutter/widgets.dart';

/// Elevation shadow tokens from tokens.json. Each level is a ready-to-use
/// `List<BoxShadow>` for `BoxDecoration.boxShadow`; `e0` is no shadow.
///
/// ANDS keeps shadow use sparing — reserve `e3` for floating layers
/// (dialogs, snackbars) and prefer hairline borders on flat surfaces.
abstract final class Elevation {
  static const List<BoxShadow> e0 = <BoxShadow>[];
  static const List<BoxShadow> e1 = <BoxShadow>[
    BoxShadow(
      color: Color.fromARGB(10, 0, 0, 0),
      offset: Offset(0.0, 1.0),
      blurRadius: 2.0,
    ),
  ];
  static const List<BoxShadow> e2 = <BoxShadow>[
    BoxShadow(
      color: Color.fromARGB(20, 0, 0, 0),
      offset: Offset(0.0, 4.0),
      blurRadius: 16.0,
    ),
  ];
  static const List<BoxShadow> e3 = <BoxShadow>[
    BoxShadow(
      color: Color.fromARGB(31, 0, 0, 0),
      offset: Offset(0.0, 8.0),
      blurRadius: 32.0,
    ),
  ];
}
