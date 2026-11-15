import 'package:drift/drift.dart';

import '../core/utils/civil_date.dart';
import 'savings_database.dart';

class HabitCounter {
  const HabitCounter({required this.target, required this.unit});
  final int target;
  final String unit;
}

class CounterDay {
  const CounterDay({required this.date, required this.amount});
  final CivilDate date;
  final int amount;
}

class HabitCounterRepository {
  HabitCounterRepository(this.database, {DateTime Function()? clock}) : clock = clock ?? DateTime.now;
  final SavingsDatabase database;
  final DateTime Function() clock;

  Future<HabitCounter?> get(int habitId) async {
    final row = await database.customSelect('SELECT * FROM habit_counters WHERE habit_id = ?', variables: [Variable.withInt(habitId)]).getSingleOrNull();
    return row == null ? null : HabitCounter(target: row.read<int>('target'), unit: row.read<String>('unit'));
  }

  Future<void> configure(int habitId, int target, String unit) async {
    final cleaned = unit.trim();
    if (target < 1 || target > 1000000 || cleaned.isEmpty || cleaned.length > 30) {
      throw ArgumentError('Target harus 1–1000000 dan satuan 1–30 karakter.');
    }
    await database.customInsert('''INSERT INTO habit_counters (habit_id, target, unit) VALUES (?, ?, ?)
      ON CONFLICT(habit_id) DO UPDATE SET target = excluded.target, unit = excluded.unit''',
      variables: [Variable.withInt(habitId), Variable.withInt(target), Variable.withString(cleaned)]);
  }

  Future<List<CounterDay>> history(int habitId) async {
    final rows = await database.customSelect('SELECT * FROM habit_counter_days WHERE habit_id = ? ORDER BY local_date DESC', variables: [Variable.withInt(habitId)]).get();
    return rows.map((row) => CounterDay(date: CivilDate.parse(row.read<String>('local_date')), amount: row.read<int>('amount'))).toList();
  }

  /// Applies each change atomically; a double tap cannot lose an increment.
  Future<void> change(int habitId, int delta) async {
    if (delta != 1 && delta != -1) throw ArgumentError('Perubahan harus satu.');
    final now = clock();
    final date = CivilDate.from(now).key;
    await database.transaction(() async {
      if (await get(habitId) == null) throw StateError('Atur target dahulu.');
      final row = await database.customSelect('SELECT amount FROM habit_counter_days WHERE habit_id = ? AND local_date = ?', variables: [Variable.withInt(habitId), Variable.withString(date)]).getSingleOrNull();
      final next = (row?.read<int>('amount') ?? 0) + delta;
      if (next < 0 || next > 1000000) throw StateError('Progres di luar batas.');
      await database.customInsert('''INSERT INTO habit_counter_days (habit_id, local_date, amount, updated_at) VALUES (?, ?, ?, ?)
        ON CONFLICT(habit_id, local_date) DO UPDATE SET amount=excluded.amount, updated_at=excluded.updated_at''',
        variables: [Variable.withInt(habitId), Variable.withString(date), Variable.withInt(next), Variable.withInt(now.millisecondsSinceEpoch)]);
    });
  }
}
