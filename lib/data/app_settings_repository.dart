import 'package:drift/drift.dart';

import 'savings_database.dart';
import '../app/theme/neo_theme.dart';

class LocalProfile {
  const LocalProfile({required this.name, required this.note});
  final String name, note;
}

class AppSettingsRepository {
  AppSettingsRepository(this._database);
  final SavingsDatabase _database;
  static const habitNotificationsKey = 'habit_notifications_enabled';

  static const themeKey = 'neo_theme_variant';

  Future<NeoThemeVariant> themeVariant() async {
    final row = await _database.customSelect('SELECT value FROM app_settings WHERE key = ?',
      variables: [Variable.withString(themeKey)]).getSingleOrNull();
    final value = row?.read<String>('value');
    return NeoThemeVariant.values.where((variant) => variant.name == value).firstOrNull ?? NeoThemeVariant.green;
  }

  Future<void> setThemeVariant(NeoThemeVariant variant) async {
    await _database.customInsert('INSERT INTO app_settings (key, value) VALUES (?, ?) ON CONFLICT(key) DO UPDATE SET value = excluded.value',
      variables: [Variable.withString(themeKey), Variable.withString(variant.name)]);
  }

  Future<LocalProfile> profile() async {
    final rows = await _database.customSelect("SELECT key, value FROM app_settings WHERE key IN ('profile_name', 'profile_note')").get();
    final values = {for (final row in rows) row.read<String>('key'): row.read<String>('value')};
    return LocalProfile(name: values['profile_name'] ?? '', note: values['profile_note'] ?? '');
  }

  Future<void> saveProfile({required String name, required String note}) async {
    final cleanName = name.trim(), cleanNote = note.trim();
    if (cleanName.length > 100 || cleanNote.length > 500) {
      throw ArgumentError('Nama maksimal 100 karakter dan catatan maksimal 500 karakter.');
    }
    await _database.transaction(() async {
      for (final entry in {'profile_name': cleanName, 'profile_note': cleanNote}.entries) {
        await _database.customInsert('INSERT INTO app_settings (key, value) VALUES (?, ?) ON CONFLICT(key) DO UPDATE SET value = excluded.value', variables: [Variable.withString(entry.key), Variable.withString(entry.value)]);
      }
    });
  }

  Future<bool> habitNotificationsEnabled() async {
    final row = await _database.customSelect(
      'SELECT value FROM app_settings WHERE key = ?',
      variables: [Variable.withString(habitNotificationsKey)],
    ).getSingleOrNull();
    return row?.read<String>('value') != 'false';
  }

  Future<void> setHabitNotificationsEnabled(bool enabled) =>
      _database.customInsert(
        'INSERT INTO app_settings (key, value) VALUES (?, ?) '
        'ON CONFLICT(key) DO UPDATE SET value = excluded.value',
        variables: [
          Variable.withString(habitNotificationsKey),
          Variable.withString(enabled.toString()),
        ],
      );
}
