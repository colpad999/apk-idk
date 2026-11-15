import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:apk_idk/data/habit_counter_repository.dart';
import 'package:apk_idk/data/habit_repository.dart';
import 'package:apk_idk/data/savings_database.dart';
import 'package:apk_idk/services/backup_service.dart';
import 'package:apk_idk/services/goal_photo_storage.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('counter validates target, changes atomically and keeps separate days', () async {
    final db = SavingsDatabase.forTesting(NativeDatabase.memory());
    try {
      final id = await HabitRepository(db).save(name: 'Air', startDate: DateTime(2026));
      var now = DateTime(2026, 1, 1);
      final counters = HabitCounterRepository(db, clock: () => now);
      await expectLater(counters.configure(id, 0, 'gelas'), throwsArgumentError);
      await counters.configure(id, 8, 'gelas');
      await counters.change(id, 1);
      await counters.change(id, 1);
      await counters.change(id, -1);
      now = DateTime(2026, 1, 2);
      await expectLater(counters.change(id, -1), throwsStateError);
      await counters.change(id, 1);
      final days = await counters.history(id);
      expect(days.map((d) => d.amount).toList(), [1, 1]);
      expect((await counters.get(id))!.unit, 'gelas');
      expect((await HabitRepository(db).get(id))!.completedDates, isEmpty);
    } finally { await db.close(); }
  });

  test('counter targets contribute to completion and preserve manual history', () async {
    final db = SavingsDatabase.forTesting(NativeDatabase.memory());
    try {
      final date = DateTime(2026, 1, 2);
      final habits = HabitRepository(db, clock: () => date);
      final id = await habits.save(name: 'Air', startDate: DateTime(2026, 1, 1));
      await habits.complete(id, DateTime(2026, 1, 1));
      final counters = HabitCounterRepository(db, clock: () => date);
      await counters.configure(id, 2, 'gelas');
      await counters.change(id, 1);
      expect((await habits.get(id))!.isComplete(date), isFalse);
      await counters.change(id, 1);
      var habit = (await habits.get(id))!;
      expect(habit.isComplete(date), isTrue);
      expect(habit.counterCompletedDates, contains('2026-01-02'));
      expect(habit.isComplete(DateTime(2026, 1, 1)), isTrue);
      await counters.change(id, -1);
      habit = (await habits.get(id))!;
      expect(habit.isComplete(date), isFalse);
      expect(habit.isComplete(DateTime(2026, 1, 1)), isTrue);
    } finally { await db.close(); }
  });

  test('backup round-trip and v3 compatibility', () async {
    final dir = await Directory.systemTemp.createTemp('counter_backup_');
    final photos = GoalPhotoStorage(rootDirectory: () async => dir);
    final db = SavingsDatabase.forTesting(NativeDatabase.memory());
    final restored = SavingsDatabase.forTesting(NativeDatabase.memory());
    final legacy = SavingsDatabase.forTesting(NativeDatabase.memory());
    try {
      final id = await HabitRepository(db).save(name: 'Baca', startDate: DateTime(2026));
      final counters = HabitCounterRepository(db, clock: () => DateTime(2026, 1, 2));
      await counters.configure(id, 30, 'menit');
      await counters.change(id, 1);
      final backup = await BackupService(database: db, photos: photos).export();
      await BackupService(database: restored, photos: photos).restore(backup.bytes);
      expect((await HabitCounterRepository(restored).get(id))!.target, 30);
      expect((await HabitCounterRepository(restored).history(id)).single.amount, 1);
      final document = jsonDecode(utf8.decode(backup.bytes)) as Map<String, dynamic>;
      document['version'] = 3;
      final data = document['data'] as Map<String, dynamic>;
      data.remove('habit_counters'); data.remove('habit_counter_days');
      await BackupService(database: legacy, photos: photos).restore(Uint8List.fromList(utf8.encode(jsonEncode(document))));
      expect(await HabitCounterRepository(legacy).get(id), isNull);
      expect(await HabitRepository(legacy).get(id), isNotNull);
    } finally { await db.close(); await restored.close(); await legacy.close(); await dir.delete(recursive: true); }
  });
}
