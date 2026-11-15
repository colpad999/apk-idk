import 'package:apk_idk/app/theme/neo_theme.dart';
import 'package:apk_idk/shared/neo_components.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('NeoButton invokes its action, while disabled and loading do not', (tester) async {
    var count = 0;
    await tester.pumpWidget(MaterialApp(theme: NeoTheme.light(), home: Scaffold(body: Column(children: [
      NeoButton(label: 'Simpan', onPressed: () => count++),
      const NeoButton(label: 'Tidak aktif', onPressed: null),
      NeoButton(label: 'Memuat', onPressed: () => count++, loading: true),
    ]))));
    await tester.tap(find.text('Simpan'));
    await tester.pump(const Duration(milliseconds: 200));
    expect(count, 1);
    await tester.tap(find.text('Tidak aktif'));
    await tester.tap(find.text('Memuat'));
    await tester.pump();
    expect(count, 1);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });
}
