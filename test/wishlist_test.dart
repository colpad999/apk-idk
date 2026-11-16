import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:apk_idk/data/savings_database.dart';
import 'package:apk_idk/data/wishlist_repository.dart';
import 'package:apk_idk/services/backup_service.dart';
import 'package:apk_idk/services/goal_photo_storage.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('wishlist CRUD validates data without creating financial transactions', () async {
    final db = SavingsDatabase.forTesting(NativeDatabase.memory());
    try {
      final repo = WishlistRepository(db);
      await expectLater(repo.save(name: '', price: 3, note: ''), throwsArgumentError);
      await repo.save(name: 'Sepatu', price: 50000, note: 'Sekolah');
      final id = (await repo.list()).single.id;
      await repo.save(id: id, name: 'Sepatu baru', price: 60000, note: '');
      await repo.setPurchased(id, true);
      expect((await repo.list()).single.purchased, isTrue);
      expect(await db.customSelect('SELECT * FROM savings_transactions').get(), isEmpty);
      await repo.delete(id);
      expect(await repo.list(), isEmpty);
    } finally { await db.close(); }
  });
  test('wishlist backup and legacy version 4 restore', () async {
    final dir = await Directory.systemTemp.createTemp('wishlist_');
    final photos = GoalPhotoStorage(rootDirectory: () async => dir);
    final db = SavingsDatabase.forTesting(NativeDatabase.memory());
    final restored = SavingsDatabase.forTesting(NativeDatabase.memory());
    final legacy = SavingsDatabase.forTesting(NativeDatabase.memory());
    try {
      await WishlistRepository(db).save(name: 'Buku', price: 25000, note: 'Favorit');
      final backup = await BackupService(database: db, photos: photos).export();
      await BackupService(database: restored, photos: photos).restore(backup.bytes);
      expect((await WishlistRepository(restored).list()).single.name, 'Buku');
      await expectLater(BackupService(database: restored, photos: photos).restore(backup.bytes), throwsStateError);
      final doc = jsonDecode(utf8.decode(backup.bytes)) as Map<String, dynamic>;
      doc['version'] = 4;
      (doc['data'] as Map<String, dynamic>).remove('wishlist_items');
      await BackupService(database: legacy, photos: photos).restore(Uint8List.fromList(utf8.encode(jsonEncode(doc))));
      expect(await WishlistRepository(legacy).list(), isEmpty);
    } finally { await db.close(); await restored.close(); await legacy.close(); await dir.delete(recursive: true); }
  });
}
