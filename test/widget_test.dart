import 'package:flutter_test/flutter_test.dart';

import 'package:roamy/app.dart';

void main() {
  testWidgets('Roamy home renders smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const RoamyApp());

    expect(find.text('Hello, Nguyên Giáp 👋'), findsOneWidget);
    expect(find.text('Where do you want to go next?'), findsOneWidget);
    expect(find.text('Saved places'), findsOneWidget);
  });
}
