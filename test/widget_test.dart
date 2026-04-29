import 'package:flutter_test/flutter_test.dart';

import 'package:roamy/app.dart';

void main() {
  testWidgets('Roamy home renders smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const RoamyApp());
    await tester.pump();

    expect(find.text('RoaMy Place'), findsOneWidget);
    expect(find.textContaining('L'), findsOneWidget);
    await tester.pump(const Duration(seconds: 2));
  });
}
