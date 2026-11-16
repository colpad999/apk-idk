import 'package:drift/drift.dart';

import 'savings_database.dart';
import '../app/theme/neo_theme.dart';

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
