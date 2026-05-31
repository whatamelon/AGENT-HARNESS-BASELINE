import 'package:core/core.dart';
import 'package:ds/ds.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:{{app_name}}/app.dart';

void main() {
  setUp(AppConfig.resetForTest);
  tearDown(AppConfig.resetForTest);

  testWidgets('boots into the shell with the bottom nav + first tab',
      (tester) async {
    AppConfig.init(Flavor.dev);

    await tester.pumpWidget(
      const ProviderScope(child: {{app_name.pascalCase()}}App()),
    );
    await tester.pumpAndSettle();

    // Shell chrome present: a multi-tab bottom nav.
    expect(find.byType(DsBottomNav), findsOneWidget);

    // First tab body + nav label render.
    expect(find.text('{{home_label}}'), findsWidgets);
  });

{{#tabs}}
  testWidgets('switching to the {{label}} tab shows its body', (tester) async {
    AppConfig.init(Flavor.dev);

    await tester.pumpWidget(
      const ProviderScope(child: {{app_name.pascalCase()}}App()),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('{{label}}').last);
    await tester.pumpAndSettle();

    expect(find.text('{{label}} 화면입니다. 여기에 기능을 채워 넣으세요.'), findsOneWidget);
  });

{{/tabs}}
}
