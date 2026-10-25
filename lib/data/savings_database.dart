import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

class SavingsDatabase extends GeneratedDatabase {
  SavingsDatabase() : super(driftDatabase(name: 'colpad_savings'));
  SavingsDatabase.forTesting(super.executor);

  @override
  int get schemaVersion => 1;

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
        },
      );
}