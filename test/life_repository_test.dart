import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:apk_idk/data/life_repository.dart';
import 'package:apk_idk/data/savings_database.dart';
import 'package:apk_idk/services/backup_service.dart';
import 'package:apk_idk/services/goal_photo_storage.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('journal and mood can be edited and deleted by civil date', () async {
    final db = SavingsDatabase.forTesting(NativeDatabase.memory());
    try {
      final repo = LifeRepository(db);
      await repo.save(DateTime(2026, 1, 2, 23), 'Belajar', 4, 'Tenang');
      await repo.save(DateTime(2026, 1, 2, 1), 'Olahraga', 3, '');
      final entry = (await repo.list()).single;
      expect(entry.date.key, '2026-01-02');
      expect(entry.journal, 'Olahraga');
      expect(entry.mood, 3);
      await expectLater(repo.save(DateTime(2026), '', 6, ''), throwsArgumentError);
      await repo.delete(DateTime(2026, 1, 2));
      expect(await repo.list(), isEmpty);
    } finally { await db.close(); }
  });

  test('backup v2 restores journal and v1 remains readable', () async {
    final dir = await Directory.systemTemp.createTemp('life_backup_');
    final photos = GoalPhotoStorage(rootDirectory: () async => dir);
    final source = SavingsDatabase.forTesting(NativeDatabase.memory());
    final target = SavingsDatabase.forTesting(NativeDatabase.memory());
    final oldTarget = SavingsDatabase.forTesting(NativeDatabase.memory());
    try {
      await LifeRepository(source).save(DateTime(2026, 1, 2), 'Catatan', 5, 'Senang');
      final exported = await BackupService(database: source, photos: photos).export();
      await BackupService(database: target, photos: photos).restore(exported.bytes);
      final restored = (await LifeRepository(target).list()).single;
      expect(restored.journal, 'Catatan');
      expect(restored.mood, 5);
      await expectLater(BackupService(database: target, photos: photos).restore(exported.bytes), throwsStateError);
      final doc = jsonDecode(utf8.decode(exported.bytes)) as Map<String, dynamic>;
      doc['version'] = 1;
      (doc['data'] as Map<String, dynamic>).remove('life_entries');
      await BackupService(database: oldTarget, photos: photos).restore(Uint8List.fromList(utf8.encode(jsonEncode(doc))));
      expect(await LifeRepository(oldTarget).list(), isEmpty);
    } finally {
      await source.close(); await target.close(); await oldTarget.close(); await dir.delete(recursive: true);
    }
  });
}
