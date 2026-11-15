import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

import 'budget_categories.dart';

/// Incremental migrations only. Never recreate or clear an existing database.
class SavingsDatabase extends GeneratedDatabase {
  SavingsDatabase() : super(driftDatabase(name: 'colpad_savings'));
  SavingsDatabase.forTesting(super.executor);

  @override
  int get schemaVersion => 8;

  @override
  Iterable<TableInfo<Table, Object?>> get allTables => const [];

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (migrator) async {
          await customStatement('''
            CREATE TABLE savings_transactions (
              id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
              type TEXT NOT NULL CHECK (type IN ('income', 'expense', 'deposit', 'withdrawal')),
              amount INTEGER NOT NULL CHECK (amount > 0),
              category TEXT NOT NULL,
              note TEXT,
              created_at INTEGER NOT NULL
            )
          ''');
          await customStatement(
            'CREATE INDEX savings_transactions_created_at_idx '
            'ON savings_transactions (created_at DESC)',
          );
          await _createPlanningTables();
          await _createGoalTables();
          await _createHabitTables();
          await _createHabitSchedulingTables();
          await _createSettingsTable();
          await _createLifeEntries();
          await _createHabitCheckins();
        },
        onUpgrade: (migrator, from, to) async {
          // Drift runs this upgrade in a transaction. A failed statement leaves
          // the previous schema/data intact rather than a half-migrated DB.
          if (from < 2) await _createPlanningTables();
          if (from < 3) await _createGoalTables();
          if (from < 4) await _addGoalCoverPhoto();
          if (from < 5) await _createHabitTables();
          if (from < 6) {
            await _addGoalDeletedAt();
            await _createHabitSchedulingTables();
            await _createSettingsTable();
            await _migrateLegacyReminders();
          }
          if (from < 7) await _createLifeEntries();
          if (from < 8) await _createHabitCheckins();
        },
        beforeOpen: (details) async {
          await customStatement('PRAGMA foreign_keys = ON');
        },
      );

  Future<void> _createHabitCheckins() async {
    await customStatement("""
      CREATE TABLE IF NOT EXISTS habit_checkins (
        id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
        habit_id INTEGER NOT NULL REFERENCES habits(id) ON DELETE CASCADE,
        recorded_at INTEGER NOT NULL,
        local_date TEXT NOT NULL,
        note TEXT NOT NULL DEFAULT ''
      )
    """);
    await customStatement('CREATE INDEX IF NOT EXISTS habit_checkins_habit_date_idx ON habit_checkins (habit_id, local_date, recorded_at)');
  }

  Future<void> _createLifeEntries() async {
    await customStatement("""
      CREATE TABLE IF NOT EXISTS life_entries (
        entry_date TEXT NOT NULL PRIMARY KEY,
        journal TEXT NOT NULL DEFAULT '',
        mood INTEGER CHECK (mood BETWEEN 1 AND 5),
        mood_note TEXT NOT NULL DEFAULT '',
        updated_at INTEGER NOT NULL
      )
    """);
  }

  Future<void> _createPlanningTables() async {
    await customStatement('''
      CREATE TABLE budget_categories (
        id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL UNIQUE,
        sort_order INTEGER NOT NULL DEFAULT 0
      )
    ''');
    await customStatement('''
      CREATE TABLE budgets (
        id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
        category_id INTEGER NOT NULL REFERENCES budget_categories(id) ON DELETE CASCADE,
        month TEXT NOT NULL,
        limit_amount INTEGER NOT NULL CHECK (limit_amount > 0),
        UNIQUE(category_id, month)
      )
    ''');
    await customStatement('''
      CREATE TABLE income_sources (
        id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL UNIQUE,
        created_at INTEGER NOT NULL
      )
    ''');
    await customStatement('CREATE INDEX budgets_month_idx ON budgets (month)');
    await customStatement(
        'CREATE INDEX income_sources_name_idx ON income_sources (name)');
    for (var index = 0; index < budgetCategories.length; index++) {
      await customStatement(
        'INSERT INTO budget_categories (name, sort_order) VALUES (?, ?)',
        [budgetCategories[index], index],
      );
    }
    await customStatement('''
      INSERT OR IGNORE INTO income_sources (name, created_at)
      SELECT category, MIN(created_at)
      FROM savings_transactions
      WHERE type = 'income'
      GROUP BY category
    ''');
  }

  Future<void> _createGoalTables() async {
    await customStatement('''
      CREATE TABLE saving_goals (
        id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        target_amount INTEGER NOT NULL CHECK (target_amount > 0),
        deadline INTEGER,
        created_at INTEGER NOT NULL,
        UNIQUE(name)
      )
    ''');
    await customStatement('''
      CREATE TABLE goal_allocations (
        id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
        goal_id INTEGER NOT NULL REFERENCES saving_goals(id) ON DELETE CASCADE,
        transaction_id INTEGER NOT NULL REFERENCES savings_transactions(id) ON DELETE CASCADE,
        amount INTEGER NOT NULL CHECK (amount > 0),
        direction TEXT NOT NULL CHECK (direction IN ('allocate', 'release')),
        created_at INTEGER NOT NULL,
        UNIQUE(transaction_id)
      )
    ''');
    await customStatement(
        'CREATE INDEX goal_allocations_goal_idx ON goal_allocations (goal_id, created_at)');
    await _addGoalCoverPhoto();
    await _addGoalDeletedAt();
  }

  Future<void> _addGoalCoverPhoto() => _addColumnIfMissing(
      'saving_goals', 'cover_photo_path', 'TEXT');

  Future<void> _addGoalDeletedAt() =>
      _addColumnIfMissing('saving_goals', 'deleted_at', 'INTEGER');

  Future<void> _addColumnIfMissing(
      String table, String column, String type) async {
    final columns = await customSelect('PRAGMA table_info($table)').get();
    if (!columns.any((row) => row.read<String>('name') == column)) {
      await customStatement('ALTER TABLE $table ADD COLUMN $column $type');
    }
  }

  Future<void> _createHabitTables() async {
    await customStatement('''
      CREATE TABLE IF NOT EXISTS habits (
        id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        description TEXT NOT NULL DEFAULT '',
        icon TEXT NOT NULL DEFAULT 'savings',
        color INTEGER NOT NULL DEFAULT 0,
        frequency TEXT NOT NULL CHECK (frequency IN ('daily', 'weekly_days', 'times_per_week')),
        scheduled_days TEXT NOT NULL DEFAULT '1,2,3,4,5,6,7',
        target_per_week INTEGER NOT NULL DEFAULT 1,
        start_date TEXT NOT NULL,
        end_date TEXT,
        is_active INTEGER NOT NULL DEFAULT 1,
        reminder_enabled INTEGER NOT NULL DEFAULT 0,
        reminder_minutes INTEGER NOT NULL DEFAULT 1140,
        reminder_days TEXT NOT NULL DEFAULT '1,2,3,4,5,6,7',
        reminder_title TEXT NOT NULL DEFAULT 'Waktunya menabung!',
        reminder_body TEXT NOT NULL DEFAULT 'Sempatkan mencatat kebiasaanmu hari ini dan lanjutkan progresmu.',
        created_at INTEGER NOT NULL
      )
    ''');
    await customStatement('''
      CREATE TABLE IF NOT EXISTS habit_completions (
        id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
        habit_id INTEGER NOT NULL REFERENCES habits(id) ON DELETE CASCADE,
        completion_date TEXT NOT NULL,
        created_at INTEGER NOT NULL,
        UNIQUE(habit_id, completion_date)
      )
    ''');
    await customStatement(
        'CREATE INDEX IF NOT EXISTS habit_completions_date_idx ON habit_completions (habit_id, completion_date)');
  }

  Future<void> _createHabitSchedulingTables() async {
    await customStatement('''
      CREATE TABLE IF NOT EXISTS habit_reminders (
        id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
        habit_id INTEGER NOT NULL REFERENCES habits(id) ON DELETE CASCADE,
        minutes INTEGER NOT NULL CHECK (minutes BETWEEN 0 AND 1439),
        days TEXT NOT NULL,
        start_date TEXT NOT NULL,
        recurrence TEXT NOT NULL DEFAULT 'weekly' CHECK (recurrence IN ('daily', 'weekly')),
        enabled INTEGER NOT NULL DEFAULT 1 CHECK (enabled IN (0, 1)),
        sound INTEGER NOT NULL DEFAULT 1 CHECK (sound IN (0, 1)),
        vibration INTEGER NOT NULL DEFAULT 1 CHECK (vibration IN (0, 1)),
        title TEXT NOT NULL,
        body TEXT NOT NULL,
        created_at INTEGER NOT NULL
      )
    ''');
    await customStatement(
        'CREATE INDEX IF NOT EXISTS habit_reminders_habit_idx ON habit_reminders (habit_id)');
    await customStatement('''
      CREATE TABLE IF NOT EXISTS habit_pauses (
        id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
        habit_id INTEGER NOT NULL REFERENCES habits(id) ON DELETE CASCADE,
        start_date TEXT NOT NULL,
        end_date TEXT,
        CHECK (end_date IS NULL OR end_date >= start_date)
      )
    ''');
    await customStatement(
        'CREATE INDEX IF NOT EXISTS habit_pauses_habit_idx ON habit_pauses (habit_id)');
  }

  Future<void> _createSettingsTable() async {
    await customStatement('''
      CREATE TABLE IF NOT EXISTS app_settings (
        key TEXT NOT NULL PRIMARY KEY,
        value TEXT NOT NULL
      )
    ''');
  }

  Future<void> _migrateLegacyReminders() async {
    // The v5 draft accidentally wrote camelCase enum names for weekly days.
    await customStatement(
        "UPDATE habits SET frequency = 'weekly_days' WHERE frequency = 'weeklyDays'");
    // Preserve the old single reminder as a disabled/enabled configuration in
    // the new table. Legacy columns remain untouched for rollback safety.
    await customStatement('''
      INSERT INTO habit_reminders
        (habit_id, minutes, days, start_date, recurrence, enabled, sound,
         vibration, title, body, created_at)
      SELECT h.id, h.reminder_minutes, h.reminder_days, h.start_date, 'weekly',
        h.reminder_enabled, 1, 1, h.reminder_title, h.reminder_body, h.created_at
      FROM habits h
      WHERE NOT EXISTS (SELECT 1 FROM habit_reminders r WHERE r.habit_id = h.id)
    ''');
    await customStatement('''
      INSERT INTO habit_pauses (habit_id, start_date)
      SELECT id, start_date FROM habits WHERE is_active = 0
    ''');
  }
}
