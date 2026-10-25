import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

import 'budget_categories.dart';

class SavingsDatabase extends GeneratedDatabase {
  SavingsDatabase() : super(driftDatabase(name: 'colpad_savings'));
  SavingsDatabase.forTesting(super.executor);

  @override
  int get schemaVersion => 3;

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
        },
        onUpgrade: (migrator, from, to) async {
          if (from < 2) await _createPlanningTables();
          if (from < 3) await _createGoalTables();
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
  }
}
