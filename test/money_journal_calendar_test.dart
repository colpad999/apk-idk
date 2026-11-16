import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:apk_idk/data/money_journal_repository.dart';
import 'package:apk_idk/data/savings_database.dart';
import 'package:apk_idk/data/savings_transaction.dart';
import 'package:apk_idk/data/transaction_repository.dart';
import 'package:apk_idk/services/backup_service.dart';
import 'package:apk_idk/services/goal_photo_storage.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('calendar monthly query returns all transactions and respects boundaries', () async {
    final db = SavingsDatabase.forTesting(NativeDatabase.memory());
    try {
      final repo = TransactionRepository(db);
      for (var i = 0; i < 105; i++) {
        await repo.add(type: TransactionType.income, amount: 1, category: 'Saku', createdAt: DateTime(2026, 1, 5));
      }
      await repo.add(type: TransactionType.income, amount: 2, category: 'Saku', createdAt: DateTime(2026, 2));
      expect(await repo.forMonth(DateTime(2026, 1, 20)), hasLength(105));
      expect(await repo.forMonth(DateTime(2026, 2)), hasLength(1));
    } finally { await db.close(); }
  });
  test('money journal CRUD and backup with old version support', () async {
    final dir = await Directory.systemTemp.createTemp('money_journal_');
    final photos = GoalPhotoStorage(rootDirectory: () async => dir);
    final db = SavingsDatabase.forTesting(NativeDatabase.memory());
    final target = SavingsDatabase.forTesting(NativeDatabase.memory());
    final old = SavingsDatabase.forTesting(NativeDatabase.memory());
    try {
      final repo = MoneyJournalRepository(db);
      await repo.save(date: DateTime(2026, 1, 2), note: 'Rencana');
      final id = (await repo.list()).single.id;
      await repo.save(id: id, date: DateTime(2026, 1, 3), note: 'Refleksi');
      expect((await repo.list()).single.date.key, '2026-01-03');
      final backup = await BackupService(database: db, photos: photos).export();
      await BackupService(database: target, photos: photos).restore(backup.bytes);
      expect((await MoneyJournalRepository(target).list()).single.note, 'Refleksi');
      final doc = jsonDecode(utf8.decode(backup.bytes)) as Map<String, dynamic>;
      doc['version'] = 6;
      (doc['data'] as Map<String, dynamic>).remove('money_journal');
      await BackupService(database: old, photos: photos).restore(Uint8List.fromList(utf8.encode(jsonEncode(doc))));
      expect(await MoneyJournalRepository(old).list(), isEmpty);
      await repo.delete(id);
      expect(await repo.list(), isEmpty);
      expect((await TransactionRepository(db).summary()).totalAssets, 0);
    } finally { await db.close(); await target.close(); await old.close(); await dir.delete(recursive: true); }
  });
}
