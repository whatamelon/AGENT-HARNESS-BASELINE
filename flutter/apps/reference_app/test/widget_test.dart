import 'package:core/core.dart';
import 'package:ds/ds.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reference_app/app.dart';

void main() {
  setUp(AppConfig.resetForTest);
  tearDown(AppConfig.resetForTest);

  testWidgets('boots into the shell: home tab shows P0 OK + flavor',
      (tester) async {
    AppConfig.init(Flavor.staging);

    await tester.pumpWidget(const ProviderScope(child: ReferenceApp()));
    await tester.pumpAndSettle();

    // Home tab body diagnostics.
    expect(find.byKey(const Key('p0-ok')), findsOneWidget);
    expect(find.text('P0 OK'), findsOneWidget);
    expect(find.text('Staging'), findsOneWidget);

    // Shell chrome present: app bar + 3-tab bottom nav.
    expect(find.byType(DsBottomNav), findsOneWidget);
    expect(find.text('홈'), findsWidgets);
    expect(find.text('디자인'), findsWidgets);
    expect(find.text('설정'), findsWidgets);
  });

  testWidgets('switching to the 디자인 tab shows the showcase body',
      (tester) async {
    AppConfig.init(Flavor.dev);

    await tester.pumpWidget(const ProviderScope(child: ReferenceApp()));
    await tester.pump();

    await tester.tap(find.text('디자인').last);
    // The showcase has perpetually-loading image placeholders, so settle by
    // pumping a fixed number of frames rather than pumpAndSettle.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));

    // Showcase section header is rendered.
    expect(find.text('색상'), findsOneWidget);
  });
}
