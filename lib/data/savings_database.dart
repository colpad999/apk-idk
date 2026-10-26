import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

import 'budget_categories.dart';

class SavingsDatabase extends GeneratedDatabase {
  SavingsDatabase() : super(driftDatabase(name: 'colpad_savings'));
  SavingsDatabase.forTesting(super.executor);

  @override
  int get schemaVersion => 5;

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
        },
        onUpgrade: (migrator, from, to) async {
          if (from < 2) await _createPlanningTables();
          if (from < 3) await _createGoalTables();
          if (from < 4) await _addGoalCoverPhoto();
          if (from < 5) await _createHabitTables();
        },
        beforeOpen: (details) async {
          await customStatement('PRAGMA foreign_keys = ON');
        },
      );

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
  }

  Future<void> _addGoalCoverPhoto() async {
    final columns = await customSelect('PRAGMA table_info(saving_goals)').get();
    if (!columns.any((row) => row.read<String>('name') == 'cover_photo_path')) {
      await customStatement(
          'ALTER TABLE saving_goals ADD COLUMN cover_photo_path TEXT');
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
}
