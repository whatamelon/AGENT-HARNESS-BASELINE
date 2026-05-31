import 'package:ds/ds.dart';
import 'package:flutter_test/flutter_test.dart';

/// B-3 gate (DESIGN-HARNESS): core semantic text/surface pairs clear 4.5:1
/// in light mode.
void main() {
  final colors = DsColors.light(AdaptivePrimary.fromSeed());

  group('Semantic contrast — B-3', () {
    test('text on bg >= 4.5:1', () {
      expect(contrastRatio(colors.text, colors.bg), greaterThanOrEqualTo(4.5));
    });

    test('textMuted on surface >= 4.5:1', () {
      expect(
        contrastRatio(colors.textMuted, colors.surface),
        greaterThanOrEqualTo(4.5),
      );
    });

    test('onPrimary on primary >= 4.5:1', () {
      expect(
        contrastRatio(colors.onPrimary, colors.primary.primary),
        greaterThanOrEqualTo(4.5),
      );
    });

    test('text on surfaceInset >= 4.5:1', () {
      expect(
        contrastRatio(colors.text, colors.surfaceInset),
        greaterThanOrEqualTo(4.5),
      );
    });
  });
}
