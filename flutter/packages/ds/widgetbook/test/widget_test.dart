import 'package:ds_widgetbook/main.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('widgetbook catalog builds', (tester) async {
    await tester.pumpWidget(const DsWidgetbook());
    expect(find.byType(DsWidgetbook), findsOneWidget);
  });
}
