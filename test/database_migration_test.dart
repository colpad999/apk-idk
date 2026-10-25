import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:apk_idk/data/savings_database.dart';

void main() {
  test('upgrades v1 without deleting transactions', () async {
    final directory =
        await Directory.systemTemp.createTemp('colpad_migration_');
    final file = File('${directory.path}/savings.sqlite');
    final legacy = _VersionOneDatabase(NativeDatabase(file));
    await legacy.customSelect('SELECT 1').getSingle();
    await legacy.customInsert(
      "INSERT INTO savings_transactions (type, amount, category, note, created_at) VALUES ('income', 125000, 'Pekerjaan', NULL, 1767225600000)",
    );
    await legacy.close();

    final current = SavingsDatabase.forTesting(NativeDatabase(file));
    final original = await current
        .customSelect('SELECT amount, category FROM savings_transactions')
        .getSingle();
    final incomeSources =
        await current.customSelect('SELECT name FROM income_sources').get();
    expect(original.read<int>('amount'), 125000);
    expect(original.read<String>('category'), 'Pekerjaan');
    expect(incomeSources.map((row) => row.read<String>('name')),
        contains('Pekerjaan'));

    await current.close();
    await directory.delete(recursive: true);
  });
}

class _VersionOneDatabase extends GeneratedDatabase {
  _VersionOneDatabase(super.executor);

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
        },
      );
}
