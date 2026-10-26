import 'package:drift/drift.dart';

import 'savings_database.dart';

enum HabitFrequency { daily, weeklyDays, timesPerWeek }

class Habit {
  const Habit(
      {required this.id,
      required this.name,
      required this.description,
      required this.icon,
      required this.color,
      required this.frequency,
      required this.scheduledDays,
      required this.targetPerWeek,
      required this.startDate,
      required this.endDate,
      required this.isActive,
      required this.reminderEnabled,
      required this.reminderMinutes,
      required this.reminderDays,
      required this.reminderTitle,
      required this.reminderBody,
      required this.createdAt,
      required this.completedDates});
  final int id;
  final String name, description, icon, reminderTitle, reminderBody;
  final int color, targetPerWeek, reminderMinutes;
  final HabitFrequency frequency;
  final Set<int> scheduledDays, reminderDays;
  final DateTime startDate;
  final DateTime? endDate;
  final bool isActive, reminderEnabled;
  final DateTime createdAt;
  final Set<String> completedDates;

  bool isScheduled(DateTime date) {
    if (date.isBefore(DateTime(startDate.year, startDate.month, startDate.day)))
      return false;
    if (endDate != null &&
        date.isAfter(DateTime(endDate!.year, endDate!.month, endDate!.day)))
      return false;
    if (frequency == HabitFrequency.daily) return true;
    if (frequency == HabitFrequency.timesPerWeek) return true;
    return scheduledDays.contains(date.weekday);
  }

  int get completionCount => completedDates.length;
  String dateKey(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  bool isComplete(DateTime date) => completedDates.contains(dateKey(date));
}

class HabitRepository {
  HabitRepository(this._db);
  final SavingsDatabase _db;

  Set<int> _days(Object? value) => (value as String? ?? '')
      .split(',')
      .where((e) => e.isNotEmpty)
      .map(int.parse)
      .toSet();
  Habit _fromRow(QueryRow row, Set<String> completed) => Habit(
        id: row.read<int>('id'),
        name: row.read<String>('name'),
        description: row.read<String>('description'),
        icon: row.read<String>('icon'),
        color: row.read<int>('color'),
        frequency: HabitFrequency.values
            .byName(row.read<String>('frequency').replaceAll('-', '')),
        scheduledDays: _days(row.read<String>('scheduled_days')),
        targetPerWeek: row.read<int>('target_per_week'),
        startDate: DateTime.parse(row.read<String>('start_date')),
        endDate: row.read<String?>('end_date') == null
            ? null
            : DateTime.parse(row.read<String>('end_date')),
        isActive: row.read<int>('is_active') == 1,
        reminderEnabled: row.read<int>('reminder_enabled') == 1,
        reminderMinutes: row.read<int>('reminder_minutes'),
        reminderDays: _days(row.read<String>('reminder_days')),
        reminderTitle: row.read<String>('reminder_title'),
        reminderBody: row.read<String>('reminder_body'),
        createdAt:
            DateTime.fromMillisecondsSinceEpoch(row.read<int>('created_at')),
        completedDates: completed,
      );

  Future<List<Habit>> list({bool? active}) async {
    final rows = await _db
        .customSelect(
            'SELECT * FROM habits ${active == null ? '' : 'WHERE is_active = ${active ? 1 : 0}'} ORDER BY is_active DESC, created_at DESC')
        .get();
    final result = <Habit>[];
    for (final row in rows) {
      final logs = await _db.customSelect(
          'SELECT completion_date FROM habit_completions WHERE habit_id = ?',
          variables: [Variable.withInt(row.read<int>('id'))]).get();
      result.add(_fromRow(
          row, logs.map((e) => e.read<String>('completion_date')).toSet()));
    }
    return result;
  }

  Future<int> save(
      {int? id,
      required String name,
      String description = '',
      String icon = 'savings',
      int color = 0xFFB8F56A,
      HabitFrequency frequency = HabitFrequency.daily,
      Set<int> scheduledDays = const {1, 2, 3, 4, 5, 6, 7},
      int targetPerWeek = 1,
      required DateTime startDate,
      DateTime? endDate,
      bool isActive = true,
      bool reminderEnabled = false,
      int reminderMinutes = 1140,
      Set<int> reminderDays = const {1, 2, 3, 4, 5, 6, 7},
      String reminderTitle = 'Waktunya menabung!',
      String reminderBody =
          'Sempatkan mencatat kebiasaanmu hari ini dan lanjutkan progresmu.'}) async {
    if (name.trim().isEmpty) throw ArgumentError('Nama habit wajib diisi.');
    final values = [
      Variable.withString(name.trim()),
      Variable.withString(description.trim()),
      Variable.withString(icon),
      Variable.withInt(color),
      Variable.withString(frequency.name),
      Variable.withString(_csv(scheduledDays)),
      Variable.withInt(targetPerWeek.clamp(1, 7)),
      Variable.withString(_date(startDate)),
      if (endDate == null)
        const Variable<String>(null)
      else
        Variable.withString(_date(endDate)),
      Variable.withInt(isActive ? 1 : 0),
      Variable.withInt(reminderEnabled ? 1 : 0),
      Variable.withInt(reminderMinutes),
      Variable.withString(_csv(reminderDays)),
      Variable.withString(reminderTitle.trim()),
      Variable.withString(reminderBody.trim()),
      Variable.withInt(DateTime.now().millisecondsSinceEpoch)
    ];
    if (id == null)
      return _db.customInsert(
          'INSERT INTO habits (name, description, icon, color, frequency, scheduled_days, target_per_week, start_date, end_date, is_active, reminder_enabled, reminder_minutes, reminder_days, reminder_title, reminder_body, created_at) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)',
          variables: values);
    await _db.customUpdate(
        'UPDATE habits SET name=?, description=?, icon=?, color=?, frequency=?, scheduled_days=?, target_per_week=?, start_date=?, end_date=?, is_active=?, reminder_enabled=?, reminder_minutes=?, reminder_days=?, reminder_title=?, reminder_body=? WHERE id=?',
        variables: [...values.sublist(0, 15), Variable.withInt(id)]);
    return id;
  }

  String _date(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  String _csv(Set<int> values) => (values.toList()..sort()).join(',');
  Future<void> toggleCompletion(int habitId, DateTime date) async {
    final key = _date(date);
    final existing = await _db.customSelect(
        'SELECT id FROM habit_completions WHERE habit_id=? AND completion_date=?',
        variables: [Variable.withInt(habitId), Variable.withString(key)]).get();
    if (existing.isEmpty) {
      await _db.customInsert(
          'INSERT INTO habit_completions (habit_id, completion_date, created_at) VALUES (?, ?, ?)',
          variables: [
            Variable.withInt(habitId),
            Variable.withString(key),
            Variable.withInt(DateTime.now().millisecondsSinceEpoch)
          ]);
    } else {
      await _db.customUpdate(
          'DELETE FROM habit_completions WHERE habit_id=? AND completion_date=?',
          variables: [Variable.withInt(habitId), Variable.withString(key)]);
    }
  }

  Future<void> delete(int id) =>
      _db.customUpdate('DELETE FROM habits WHERE id=?',
          variables: [Variable.withInt(id)]);
  Future<void> setActive(int id, bool value) =>
      _db.customUpdate('UPDATE habits SET is_active=? WHERE id=?',
          variables: [Variable.withInt(value ? 1 : 0), Variable.withInt(id)]);
}
