import 'package:app_kit/src/router/splash_gate.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('SplashScreen renders a centered progress indicator',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(home: SplashScreen()));
    // No pumpAndSettle: CircularProgressIndicator animates forever.
    await tester.pump();

    expect(find.byType(SplashScreen), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.byType(Center), findsWidgets);
  });
}
