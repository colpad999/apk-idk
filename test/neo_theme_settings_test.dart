import 'dart:io';
import 'package:apk_idk/app/theme/neo_theme.dart';
import 'package:apk_idk/data/app_settings_repository.dart';
import 'package:apk_idk/data/savings_database.dart';
import 'package:apk_idk/services/backup_service.dart';
import 'package:apk_idk/services/goal_photo_storage.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
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
