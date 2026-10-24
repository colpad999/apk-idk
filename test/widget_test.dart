import 'package:flutter_test/flutter_test.dart';
import 'package:apk_idk/main.dart';

void main() {
  testWidgets('starter home page renders', (tester) async {
    await tester.pumpWidget(const ColpadApp());
    expect(find.text('Build something\nremarkable.'), findsOneWidget);
    expect(find.text('CRAFTED BY COLPAD ⚡'), findsOneWidget);
  });
}
