import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:apk_idk/data/habit_checkin_repository.dart';
import 'package:apk_idk/data/habit_repository.dart';
import 'package:apk_idk/data/savings_database.dart';
import 'package:apk_idk/services/backup_service.dart';
import 'package:apk_idk/services/goal_photo_storage.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('multiple check-ins preserve timestamps, edit and delete without changing completion', () async {
    final db = SavingsDatabase.forTesting(NativeDatabase.memory());
    try {
      final habit = await HabitRepository(db).save(name: 'Air', startDate: DateTime(2026));
      var time = DateTime(2026, 1, 1, 8);
      final repo = HabitCheckinRepository(db, clock: () => time);
      final first = await repo.add(habit, 'Satu');
      time = DateTime(2026, 1, 1, 10);
      final second = await repo.add(habit, 'Dua');
      expect((await repo.list(habit)).length, 2);
      expect((await repo.list(habit)).first.localDate.key, '2026-01-01');
      await repo.edit(habit, first, 'Diedit');
      expect((await repo.list(habit)).last.note, 'Diedit');
      await repo.delete(habit, second);
      expect((await repo.list(habit)).single.recordedAt.hour, 8);
      expect((await HabitRepository(db).get(habit))!.completedDates, isEmpty);
      await HabitRepository(db).delete(habit);
      expect(await repo.list(habit), isEmpty);
    } finally { await db.close(); }
  });

  test('backup v3 preserves check-ins and v2 loads without them', () async {
    final dir = await Directory.systemTemp.createTemp('checkins_');
    final photos = GoalPhotoStorage(rootDirectory: () async => dir);
    final db = SavingsDatabase.forTesting(NativeDatabase.memory());
    final target = SavingsDatabase.forTesting(NativeDatabase.memory());
    final legacy = SavingsDatabase.forTesting(NativeDatabase.memory());
    try {
      final id = await HabitRepository(db).save(name: 'Baca', startDate: DateTime(2026));
      await HabitCheckinRepository(db, clock: () => DateTime(2026, 1, 2, 9)).add(id, 'Buku');
      final backup = await BackupService(database: db, photos: photos).export();
      await BackupService(database: target, photos: photos).restore(backup.bytes);
      expect((await HabitCheckinRepository(target).list(id)).single.note, 'Buku');
      final document = jsonDecode(utf8.decode(backup.bytes)) as Map<String, dynamic>;
      document['version'] = 2;
      (document['data'] as Map<String, dynamic>).remove('habit_checkins');
      await BackupService(database: legacy, photos: photos).restore(Uint8List.fromList(utf8.encode(jsonEncode(document))));
      expect(await HabitCheckinRepository(legacy).list(id), isEmpty);
      expect(await HabitRepository(legacy).get(id), isNotNull);
    } finally {
      await db.close(); await target.close(); await legacy.close(); await dir.delete(recursive: true);
    }
  });
}
