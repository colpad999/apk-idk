import 'dart:io';
import 'package:apk_idk/app/theme/neo_theme.dart';
import 'package:apk_idk/data/app_settings_repository.dart';
import 'package:apk_idk/data/savings_database.dart';
import 'package:apk_idk/services/backup_service.dart';
import 'package:apk_idk/services/goal_photo_storage.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('local profile validates, persists and travels with backup safely', () async {
    final dir = await Directory.systemTemp.createTemp('profile_');
    final photos = GoalPhotoStorage(rootDirectory: () async => dir);
    final source = SavingsDatabase.forTesting(NativeDatabase.memory());
    final target = SavingsDatabase.forTesting(NativeDatabase.memory());
    try {
      final settings = AppSettingsRepository(source);
      expect((await settings.profile()).name, '');
      await settings.saveProfile(name: '  Rina  ', note: ' Catatan ');
      expect((await settings.profile()).name, 'Rina');
      expect((await settings.profile()).note, 'Catatan');
      await expectLater(settings.saveProfile(name: 'x' * 101, note: ''), throwsArgumentError);
      expect((await settings.profile()).name, 'Rina');
      final backup = await BackupService(database: source, photos: photos).export();
      await BackupService(database: target, photos: photos).restore(backup.bytes);
      expect((await AppSettingsRepository(target).profile()).name, 'Rina');
      await expectLater(BackupService(database: target, photos: photos).restore(backup.bytes), throwsStateError);
      expect((await AppSettingsRepository(target).profile()).name, 'Rina');
    } finally { await source.close(); await target.close(); await dir.delete(recursive: true); }
  });

  test('theme selection persists and is included in backup', () async {
    final dir = await Directory.systemTemp.createTemp('neo_theme_');
    final photos = GoalPhotoStorage(rootDirectory: () async => dir);
    final db = SavingsDatabase.forTesting(NativeDatabase.memory());
    final target = SavingsDatabase.forTesting(NativeDatabase.memory());
    try {
      final settings = AppSettingsRepository(db);
      expect(await settings.themeVariant(), NeoThemeVariant.green);
      for (final variant in NeoThemeVariant.values) {
        await settings.setThemeVariant(variant);
        expect(await AppSettingsRepository(db).themeVariant(), variant);
      }
      final backup = await BackupService(database: db, photos: photos).export();
      await BackupService(database: target, photos: photos).restore(backup.bytes);
      expect(await AppSettingsRepository(target).themeVariant(), NeoThemeVariant.purple);
    } finally { await db.close(); await target.close(); await dir.delete(recursive: true); }
  });
}
