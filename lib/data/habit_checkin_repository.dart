import 'package:drift/drift.dart';

import '../core/utils/civil_date.dart';
import 'savings_database.dart';

class HabitCheckin {
  const HabitCheckin({required this.id, required this.habitId, required this.recordedAt, required this.localDate, required this.note});
  final int id, habitId;
  final DateTime recordedAt;
  final CivilDate localDate;
  final String note;
}

class HabitCheckinRepository {
  HabitCheckinRepository(this.database, {DateTime Function()? clock}) : clock = clock ?? DateTime.now;
  final SavingsDatabase database;
  final DateTime Function() clock;

  Future<List<HabitCheckin>> list(int habitId) async {
    final rows = await database.customSelect(
      'SELECT * FROM habit_checkins WHERE habit_id = ? ORDER BY recorded_at DESC, id DESC',
      variables: [Variable.withInt(habitId)]).get();
    return rows.map((row) => HabitCheckin(id: row.read<int>('id'), habitId: habitId,
      recordedAt: DateTime.fromMillisecondsSinceEpoch(row.read<int>('recorded_at')),
      localDate: CivilDate.parse(row.read<String>('local_date')), note: row.read<String>('note'))).toList();
  }

  Future<int> add(int habitId, String note) async {
    if (note.length > 500) { throw ArgumentError('Catatan maksimal 500 karakter.'); }
    final now = clock();
    return database.customInsert('INSERT INTO habit_checkins (habit_id, recorded_at, local_date, note) VALUES (?, ?, ?, ?)',
      variables: [Variable.withInt(habitId), Variable.withInt(now.millisecondsSinceEpoch),
        Variable.withString(CivilDate.from(now).key), Variable.withString(note.trim())]);
  }

  Future<void> edit(int habitId, int id, String note) async {
    if (note.length > 500) { throw ArgumentError('Catatan maksimal 500 karakter.'); }
    final changed = await database.customUpdate('UPDATE habit_checkins SET note = ? WHERE habit_id = ? AND id = ?',
      variables: [Variable.withString(note.trim()), Variable.withInt(habitId), Variable.withInt(id)]);
    if (changed == 0) { throw StateError('Check-in tidak ditemukan.'); }
  }

  Future<void> delete(int habitId, int id) async {
    final changed = await database.customUpdate('DELETE FROM habit_checkins WHERE habit_id = ? AND id = ?',
      variables: [Variable.withInt(habitId), Variable.withInt(id)]);
    if (changed == 0) { throw StateError('Check-in tidak ditemukan.'); }
  }
}
