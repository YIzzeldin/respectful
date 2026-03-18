import 'package:flutter_test/flutter_test.dart';
import 'package:respectful/main.dart';

void main() {
  testWidgets('App renders spike screen', (WidgetTester tester) async {
    await tester.pumpWidget(const RespectfulApp());
    expect(find.text('Respectful — Spike'), findsOneWidget);
  });
}
