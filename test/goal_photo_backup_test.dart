import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:apk_idk/data/goal_repository.dart';
import 'package:apk_idk/data/habit_repository.dart';
import 'package:apk_idk/data/savings_database.dart';
import 'package:apk_idk/services/backup_service.dart';
import 'package:apk_idk/services/goal_photo_storage.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as image;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory directory;
  late SavingsDatabase db;
  late GoalPhotoStorage photos;
  late GoalRepository goals;

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('colpad_photos_');
    db = SavingsDatabase.forTesting(NativeDatabase.memory());
    photos = GoalPhotoStorage(rootDirectory: () async => directory);
    goals = GoalRepository(db);
  });
  tearDown(() async {
    await db.close();
    await directory.delete(recursive: true);
  });

  Future<String> photo() async {
    final source = image.Image(width: 120, height: 60);
    final prepared = await processGoalPhoto(Uint8List.fromList(image.encodePng(source)));
    expect(prepared.width, 120);
    expect(prepared.height, 60);
    return photos.savePrepared(prepared.bytes);
  }

  test('persistent photo can be shared, replaced and removed safely', () async {
    final first = await photo();
    final second = await photo();
    final a = await goals.create(name: 'HP', targetAmount: 500000, coverPhotoPath: first);
    final b = await goals.create(name: 'Sepeda', targetAmount: 700000, coverPhotoPath: first);
    expect(await (await photos.fileFor(first))!.exists(), isTrue);
    final old = await goals.update(id: a, name: 'HP baru', targetAmount: 600000, deadline: null, coverPhotoPath: second);
    expect(old, first);
    expect(await goals.isPhotoReferenced(first), isTrue);
    final removed = await goals.update(id: b, name: 'Sepeda', targetAmount: 700000, deadline: null, coverPhotoPath: null);
    expect(removed, first);
    expect(await goals.isPhotoReferenced(first), isFalse);
    await photos.delete(first);
    expect(await (await photos.fileFor(first))!.exists(), isFalse);
    expect((await goals.get(b))!.coverPhotoPath, isNull);
    final deletePath = await goals.delete(a);
    expect(deletePath, second);
    expect(await goals.isPhotoReferenced(second), isFalse);
    await photos.delete(deletePath);
    expect(await goals.get(a), isNull);
    expect(await goals.get(b), isNotNull);
  });

  test('invalid and missing image sources fail gracefully', () async {
    await expectLater(processGoalPhoto(Uint8List.fromList([1, 2, 3])), throwsFormatException);
    await expectLater(photos.importFile(File('${directory.path}/missing.png')), throwsFormatException);
    expect(await photos.fileFor('../outside.jpg'), isNull);
    final id = await goals.create(name: 'Liburan', targetAmount: 1000000, coverPhotoPath: 'goal_covers/missing.jpg');
    expect(await (await photos.fileFor((await goals.get(id))!.coverPhotoPath))!.exists(), isFalse);
    expect(await goals.get(id), isNotNull);
  });

  test('backup restores photo, habit and goal into empty database', () async {
    final path = await photo();
    await goals.create(name: 'Laptop', targetAmount: 9000000, coverPhotoPath: path);
    final repository = HabitRepository(db, clock: () => DateTime(2026, 1, 14));
    final id = await repository.save(name: 'Catat', startDate: DateTime(2026, 1, 1));
    await repository.complete(id, DateTime(2026, 1, 14));
    final exported = await BackupService(database: db, photos: photos).export();
    expect(exported.missingPhotoPaths, isEmpty);
    final destination = SavingsDatabase.forTesting(NativeDatabase.memory());
    try {
      final result = await BackupService(database: destination, photos: photos).restore(exported.bytes);
      expect(result.photos, 1);
      final restored = (await GoalRepository(destination).list()).single;
      expect(restored.name, 'Laptop');
      expect(await (await photos.fileFor(restored.coverPhotoPath))!.exists(), isTrue);
      expect((await HabitRepository(destination).get(id))!.completedDates, contains('2026-01-14'));
      await expectLater(BackupService(database: destination, photos: photos).restore(exported.bytes), throwsStateError);
    } finally {
      await destination.close();
    }
  });

  test('missing photo is reported and restored without losing goal', () async {
    await goals.create(name: 'Sekolah', targetAmount: 100000, coverPhotoPath: 'goal_covers/lost.jpg');
    final exported = await BackupService(database: db, photos: photos).export();
    expect(exported.missingPhotoPaths, ['Sekolah']);
    final destination = SavingsDatabase.forTesting(NativeDatabase.memory());
    try {
      final result = await BackupService(database: destination, photos: photos).restore(exported.bytes);
      expect(result.missingPhotos, 1);
      expect((await GoalRepository(destination).list()).single.coverPhotoPath, isNull);
    } finally {
      await destination.close();
    }
  });

  test('invalid relationships leave existing records unchanged', () async {
    final source = SavingsDatabase.forTesting(NativeDatabase.memory());
    try {
      final repository = HabitRepository(source, clock: () => DateTime(2026, 1, 14));
      final id = await repository.save(name: 'Belajar', startDate: DateTime(2026, 1, 1));
      await repository.complete(id, DateTime(2026, 1, 14));
      final exported = await BackupService(database: source, photos: photos).export();
      final document = jsonDecode(utf8.decode(exported.bytes)) as Map<String, dynamic>;
      final data = document['data'] as Map<String, dynamic>;
      final completions = data['habit_completions'] as List<dynamic>;
      (completions.single as Map<String, dynamic>)['habit_id'] = 999999;
      await goals.create(name: 'Data lama', targetAmount: 1000);
      await expectLater(
        BackupService(database: db, photos: photos).restore(
          Uint8List.fromList(utf8.encode(jsonEncode(document)))),
        throwsFormatException,
      );
      expect((await goals.list()).single.name, 'Data lama');
      expect(await HabitRepository(db).list(), isEmpty);
    } finally {
      await source.close();
    }
  });

  test('corrupt backup is rejected without modifying the database', () async {
    final service = BackupService(database: db, photos: photos);
    await expectLater(service.restore(Uint8List.fromList(utf8.encode('{"format":"wrong","version":1}'))), throwsFormatException);
    expect(await goals.list(), isEmpty);
  });
}
