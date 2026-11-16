import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:apk_idk/data/goal_repository.dart';
import 'package:apk_idk/data/saving_challenge_repository.dart';
import 'package:apk_idk/data/savings_database.dart';
import 'package:apk_idk/data/savings_transaction.dart';
import 'package:apk_idk/data/transaction_repository.dart';
import 'package:apk_idk/services/backup_service.dart';
import 'package:apk_idk/services/goal_photo_storage.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('challenge follows dated net allocations without creating assets', () async {
    final db = SavingsDatabase.forTesting(NativeDatabase.memory());
    try {
      var now = DateTime(2026, 1, 2, 9);
      final tx = TransactionRepository(db);
      final goal = await GoalRepository(db).create(name: 'Buku', targetAmount: 50000);
      await tx.add(type: TransactionType.income, amount: 100000, category: 'Saku', createdAt: DateTime(2026, 1, 1));
      final challenges = SavingChallengeRepository(db, clock: () => now);
      await challenges.create(goalId: goal, name: 'Misi buku', target: 20000, endDate: DateTime(2026, 1, 10));
      await tx.add(type: TransactionType.deposit, amount: 12000, category: 'Tabungan', goalId: goal, createdAt: DateTime(2026, 1, 3));
      expect((await challenges.list()).single.progress, 0);
      now = DateTime(2026, 1, 4);
      expect((await challenges.list()).single.progress, 12000);
      await tx.add(type: TransactionType.withdrawal, amount: 2000, category: 'Tarik', goalId: goal, createdAt: DateTime(2026, 1, 4));
      expect((await challenges.list()).single.progress, 10000);
      expect((await tx.summary()).totalAssets, 100000);
      await challenges.delete((await challenges.list()).single.id);
      expect((await tx.summary()).totalAssets, 100000);
    } finally { await db.close(); }
  });
  test('backup includes challenges and accepts v5', () async {
    final dir = await Directory.systemTemp.createTemp('challenge_');
    final photos = GoalPhotoStorage(rootDirectory: () async => dir);
    final db = SavingsDatabase.forTesting(NativeDatabase.memory());
    final restored = SavingsDatabase.forTesting(NativeDatabase.memory());
    final legacy = SavingsDatabase.forTesting(NativeDatabase.memory());
    try {
      final goal = await GoalRepository(db).create(name: 'Liburan', targetAmount: 10000);
      await SavingChallengeRepository(db, clock: () => DateTime(2026, 1, 1)).create(goalId: goal, name: 'Tantangan', target: 10000, endDate: DateTime(2026, 2, 1));
      final backup = await BackupService(database: db, photos: photos).export();
      await BackupService(database: restored, photos: photos).restore(backup.bytes);
      expect((await SavingChallengeRepository(restored).list()).single.name, 'Tantangan');
      final doc = jsonDecode(utf8.decode(backup.bytes)) as Map<String, dynamic>;
      doc['version'] = 5;
      (doc['data'] as Map<String, dynamic>).remove('saving_challenges');
      await BackupService(database: legacy, photos: photos).restore(Uint8List.fromList(utf8.encode(jsonEncode(doc))));
      expect(await SavingChallengeRepository(legacy).list(), isEmpty);
      expect((await GoalRepository(legacy).list()).single.name, 'Liburan');
    } finally { await db.close(); await restored.close(); await legacy.close(); await dir.delete(recursive: true); }
  });
}
