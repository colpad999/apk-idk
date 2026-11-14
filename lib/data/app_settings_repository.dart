import 'package:drift/drift.dart';

import 'savings_database.dart';

class AppSettingsRepository {
  AppSettingsRepository(this._database);
  final SavingsDatabase _database;
  static const habitNotificationsKey = 'habit_notifications_enabled';

  Future<bool> habitNotificationsEnabled() async {
    final row = await _database.customSelect(
      'SELECT value FROM app_settings WHERE key = ?',
      variables: [const Variable.withString(habitNotificationsKey)],
    ).getSingleOrNull();
    return row?.read<String>('value') != 'false';
  }

  Future<void> setHabitNotificationsEnabled(bool enabled) =>
      _database.customInsert(
        'INSERT INTO app_settings (key, value) VALUES (?, ?) '
        'ON CONFLICT(key) DO UPDATE SET value = excluded.value',
        variables: [
          const Variable.withString(habitNotificationsKey),
          Variable.withString(enabled.toString()),
        ],
      );
}
