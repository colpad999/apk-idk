import 'package:apk_idk/app/providers.dart';
import 'package:apk_idk/data/savings_database.dart';
import 'package:apk_idk/features/reminders/reminder_history_page.dart';
import 'package:apk_idk/features/settings/profile_page.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('history displays actual Android event records', (tester) async {
    await initializeDateFormatting('id_ID');
    const channel = MethodChannel('colpad/habit_alarm');
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, (call) async {
      if (call.method == 'history') {
        return [{'id': 1, 'time': 1767225600000, 'habit': 5, 'title': 'Minum air', 'event': 'snoozed'}];
      }
      return null;
    });
    addTearDown(() => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, null));
    await tester.pumpWidget(const MaterialApp(home: ReminderHistoryPage()));
    await tester.pumpAndSettle();
    expect(find.text('Minum air'), findsOneWidget);
    expect(find.text('Ditunda 10 menit'), findsOneWidget);
    expect(find.textContaining('belum termasuk backup'), findsOneWidget);
  });
  testWidgets('profile can be edited and saved locally', (tester) async {
    final db = SavingsDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    await tester.pumpWidget(ProviderScope(overrides: [savingsDatabaseProvider.overrideWithValue(db)], child: const MaterialApp(home: ProfilePage())));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, 'Rina');
    await tester.enterText(find.byType(TextField).last, 'Catatan');
    await tester.tap(find.text('Simpan profil'));
    await tester.pumpAndSettle();
    final rows = await db.customSelect("SELECT value FROM app_settings WHERE key='profile_name'").get();
    expect(rows.single.read<String>('value'), 'Rina');
  });
}
