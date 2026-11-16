import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:apk_idk/data/savings_database.dart';

void main() {
  test('upgrades legacy v5 habits, reminders and logs without deleting data', () async {
    final directory = await Directory.systemTemp.createTemp('colpad_v5_');
    final file = File('${directory.path}/savings.sqlite');
    final fixture = SavingsDatabase.forTesting(NativeDatabase(file));
    await fixture.customSelect('SELECT 1').getSingle();
    await fixture.customStatement("INSERT INTO habits (name, frequency, scheduled_days, start_date, is_active, reminder_enabled, reminder_minutes, reminder_days, created_at) VALUES ('Tabung', 'weekly_days', '1,3', '2026-01-01', 1, 1, 1140, '1,3', 1)");
    await fixture.customStatement("INSERT INTO habit_completions (habit_id, completion_date, created_at) VALUES (1, '2026-01-05', 1)");
    await fixture.customStatement("INSERT INTO savings_transactions (type, amount, category, created_at) VALUES ('income', 10000, 'Uang saku', 1)");
    await fixture.customStatement('DROP TABLE habit_reminders');
    await fixture.customStatement('DROP TABLE habit_pauses');
    await fixture.customStatement('DROP TABLE app_settings');
    await fixture.customStatement('PRAGMA user_version = 5');
    await fixture.close();
    final migrated = SavingsDatabase.forTesting(NativeDatabase(file));
    try {
      final reminder = await migrated.customSelect('SELECT * FROM habit_reminders').getSingle();
      expect(reminder.read<int>('minutes'), 1140);
      expect(reminder.read<String>('days'), '1,3');
      expect(reminder.read<int>('enabled'), 1);
      expect(await migrated.customSelect('SELECT * FROM habit_completions').get(), hasLength(1));
      expect(await migrated.customSelect('SELECT * FROM savings_transactions').get(), hasLength(1));
    } finally {
      await migrated.close();
      await directory.delete(recursive: true);
    }
  });

  test('v6 migrates additively without losing habit or financial data', () async {
    final directory = await Directory.systemTemp.createTemp('colpad_v6_');
    final file = File('${directory.path}/savings.sqlite');
    final old = SavingsDatabase.forTesting(NativeDatabase(file));
    await old.customSelect('SELECT 1').getSingle();
    await old.customStatement("INSERT INTO habits (name, frequency, start_date, created_at) VALUES ('Belajar', 'daily', '2026-01-01', 1)");
    await old.customStatement("INSERT INTO savings_transactions (type, amount, category, created_at) VALUES ('income', 1000, 'Saku', 1)");
    await old.customStatement('DROP TABLE life_entries');
    await old.customStatement('PRAGMA user_version = 6');
    await old.close();
    final migrated = SavingsDatabase.forTesting(NativeDatabase(file));
    try {
      expect(await migrated.customSelect('SELECT * FROM habits').get(), hasLength(1));
      expect(await migrated.customSelect('SELECT * FROM savings_transactions').get(), hasLength(1));
      expect(await migrated.customSelect('SELECT * FROM life_entries').get(), isEmpty);
    } finally {
      await migrated.close();
      await directory.delete(recursive: true);
    }
  });

  test('v7 check-in migration preserves habit and journal data', () async {
    final directory = await Directory.systemTemp.createTemp('colpad_v7_');
    final file = File('${directory.path}/savings.sqlite');
    final old = SavingsDatabase.forTesting(NativeDatabase(file));
    await old.customSelect('SELECT 1').getSingle();
    await old.customStatement("INSERT INTO habits (name, frequency, start_date, created_at) VALUES ('Belajar', 'daily', '2026-01-01', 1)");
    await old.customStatement("INSERT INTO life_entries (entry_date, journal, updated_at) VALUES ('2026-01-01', 'Catatan', 1)");
    await old.customStatement('DROP TABLE habit_checkins');
    await old.customStatement('PRAGMA user_version = 7');
    await old.close();
    final migrated = SavingsDatabase.forTesting(NativeDatabase(file));
    try {
      expect(await migrated.customSelect('SELECT * FROM habits').get(), hasLength(1));
      expect(await migrated.customSelect('SELECT * FROM life_entries').get(), hasLength(1));
      expect(await migrated.customSelect('SELECT * FROM habit_checkins').get(), isEmpty);
    } finally { await migrated.close(); await directory.delete(recursive: true); }
  });

  test('v8 counter migration preserves existing records', () async {
    final directory = await Directory.systemTemp.createTemp('colpad_v8_');
    final file = File('${directory.path}/savings.sqlite');
    final old = SavingsDatabase.forTesting(NativeDatabase(file));
    await old.customSelect('SELECT 1').getSingle();
    await old.customStatement("INSERT INTO habits (name, frequency, start_date, created_at) VALUES ('Belajar', 'daily', '2026-01-01', 1)");
    await old.customStatement("INSERT INTO habit_checkins (habit_id, recorded_at, local_date, note) VALUES (1, 1, '2026-01-01', 'Ada')");
    await old.customStatement('DROP TABLE habit_counter_days');
    await old.customStatement('DROP TABLE habit_counters');
    await old.customStatement('PRAGMA user_version = 8');
    await old.close();
    final migrated = SavingsDatabase.forTesting(NativeDatabase(file));
    try {
      expect(await migrated.customSelect('SELECT * FROM habit_checkins').get(), hasLength(1));
      expect(await migrated.customSelect('SELECT * FROM habit_counters').get(), isEmpty);
    } finally { await migrated.close(); await directory.delete(recursive: true); }
  });

  test('v9 wishlist migration keeps existing entries', () async {
    final directory = await Directory.systemTemp.createTemp('colpad_v9_');
    final file = File('${directory.path}/savings.sqlite');
    final old = SavingsDatabase.forTesting(NativeDatabase(file));
    await old.customSelect('SELECT 1').getSingle();
    await old.customStatement("INSERT INTO life_entries (entry_date, journal, updated_at) VALUES ('2026-01-01', 'Ada', 1)");
    await old.customStatement('DROP TABLE wishlist_items');
    await old.customStatement('PRAGMA user_version = 9');
    await old.close();
    final migrated = SavingsDatabase.forTesting(NativeDatabase(file));
    try {
      expect(await migrated.customSelect('SELECT * FROM life_entries').get(), hasLength(1));
      expect(await migrated.customSelect('SELECT * FROM wishlist_items').get(), isEmpty);
    } finally { await migrated.close(); await directory.delete(recursive: true); }
  });

  test('v10 challenge migration preserves existing wishlist', () async {
    final directory = await Directory.systemTemp.createTemp('colpad_v10_');
    final file = File('${directory.path}/savings.sqlite');
    final old = SavingsDatabase.forTesting(NativeDatabase(file));
    await old.customSelect('SELECT 1').getSingle();
    await old.customStatement("INSERT INTO wishlist_items (name, price, created_at) VALUES ('Buku', 1000, 1)");
    await old.customStatement('DROP TABLE saving_challenges');
    await old.customStatement('PRAGMA user_version = 10');
    await old.close();
    final migrated = SavingsDatabase.forTesting(NativeDatabase(file));
    try {
      expect(await migrated.customSelect('SELECT * FROM wishlist_items').get(), hasLength(1));
      expect(await migrated.customSelect('SELECT * FROM saving_challenges').get(), isEmpty);
    } finally { await migrated.close(); await directory.delete(recursive: true); }
  });

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
