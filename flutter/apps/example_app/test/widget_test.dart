import 'package:core/core.dart';
import 'package:ds/ds.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:example_app/app.dart';

void main() {
  setUp(AppConfig.resetForTest);
  tearDown(AppConfig.resetForTest);

  testWidgets('boots into the shell with the bottom nav + first tab',
      (tester) async {
    AppConfig.init(Flavor.dev);

    await tester.pumpWidget(
      const ProviderScope(child: ExampleAppApp()),
    );
    await tester.pumpAndSettle();

    // Shell chrome present: a multi-tab bottom nav.
    expect(find.byType(DsBottomNav), findsOneWidget);

    // First tab body + nav label render.
    expect(find.text('홈'), findsWidgets);
  });


  testWidgets('switching to the 홈 tab shows its body', (tester) async {
    AppConfig.init(Flavor.dev);

    await tester.pumpWidget(
      const ProviderScope(child: ExampleAppApp()),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('홈').last);
    await tester.pumpAndSettle();

    expect(find.text('홈 화면입니다. 여기에 기능을 채워 넣으세요.'), findsOneWidget);
  });


  testWidgets('switching to the 서비스 tab shows its body', (tester) async {
    AppConfig.init(Flavor.dev);

    await tester.pumpWidget(
      const ProviderScope(child: ExampleAppApp()),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('서비스').last);
    await tester.pumpAndSettle();

    expect(find.text('서비스 화면입니다. 여기에 기능을 채워 넣으세요.'), findsOneWidget);
  });


  testWidgets('switching to the 마이 tab shows its body', (tester) async {
    AppConfig.init(Flavor.dev);

    await tester.pumpWidget(
      const ProviderScope(child: ExampleAppApp()),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('마이').last);
    await tester.pumpAndSettle();

    expect(find.text('마이 화면입니다. 여기에 기능을 채워 넣으세요.'), findsOneWidget);
  });


}
