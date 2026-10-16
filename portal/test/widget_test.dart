import 'package:flutter_test/flutter_test.dart';
import 'package:portal/main.dart';

void main() {
  testWidgets('ExamplayerApp smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const ExamplayerApp());
    expect(find.text('Examplayer Admin'), findsOneWidget);
  });
}
