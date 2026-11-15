import 'package:drift/drift.dart';

import '../core/utils/civil_date.dart';
import 'habit.dart';
import 'savings_database.dart';

export 'habit.dart';

class HabitRepository {
  HabitRepository(this._database, {DateTime Function()? clock})
      : _clock = clock ?? DateTime.now;

  final SavingsDatabase _database;
  final DateTime Function() _clock;

  Future<List<Habit>> list({bool? active}) async {
    final rows = await _database.customSelect(
      'SELECT * FROM habits ${active == null ? '' : 'WHERE is_active = ?'} '
      'ORDER BY is_active DESC, created_at DESC, id DESC',
      variables: [if (active != null) Variable.withInt(active ? 1 : 0)],
    ).get();
    if (rows.isEmpty) return [];
    final logs = await _database
        .customSelect('SELECT * FROM habit_completions ORDER BY completion_date')
        .get();
    final reminderRows = await _database
        .customSelect('SELECT * FROM habit_reminders ORDER BY minutes, id')
        .get();
    final pauseRows = await _database
        .customSelect('SELECT * FROM habit_pauses ORDER BY start_date, id')
        .get();
    final counterRows = await _database.customSelect('SELECT habit_id FROM habit_counters').get();
    final counterLogs = await _database.customSelect('''
      SELECT d.habit_id, d.local_date FROM habit_counter_days d
      JOIN habit_counters c ON c.habit_id = d.habit_id
      WHERE d.amount >= c.target
    ''').get();
    final counterIds = counterRows.map((row) => row.read<int>('habit_id')).toSet();
    final counterCompletions = <int, Set<String>>{};
    for (final row in counterLogs) {
      counterCompletions.putIfAbsent(row.read<int>('habit_id'), () => {}).add(row.read<String>('local_date'));
    }
    final completions = <int, Set<String>>{};
    for (final row in logs) {
      completions
          .putIfAbsent(row.read<int>('habit_id'), () => {})
          .add(row.read<String>('completion_date'));
    }
    for (final entry in counterCompletions.entries) {
      completions.putIfAbsent(entry.key, () => {}).addAll(entry.value);
    }
    final reminders = <int, List<HabitReminder>>{};
    for (final row in reminderRows) {
      reminders
          .putIfAbsent(row.read<int>('habit_id'), () => [])
          .add(_reminderFromRow(row));
    }
    final pauses = <int, List<HabitPause>>{};
    for (final row in pauseRows) {
      pauses.putIfAbsent(row.read<int>('habit_id'), () => []).add(HabitPause(
            startDate: CivilDate.parse(row.read<String>('start_date')),
            endDate: row.read<String?>('end_date') == null
                ? null
                : CivilDate.parse(row.read<String>('end_date')),
          ));
    }
    return rows
        .map((row) => _fromRow(
              row,
              completions[row.read<int>('id')] ?? {},
              reminders[row.read<int>('id')] ?? [],
              pauses[row.read<int>('id')] ?? [],
              counterIds.contains(row.read<int>('id')),
              counterCompletions[row.read<int>('id')] ?? {},
            ))
        .toList();
  }

  Future<Habit?> get(int id) async {
    final habits = await list();
    for (final habit in habits) {
      if (habit.id == id) return habit;
    }
    return null;
  }

  Future<int> save({
    int? id,
    required String name,
    String description = '',
    String icon = 'savings',
    int color = 0xFFB8F56A,
    HabitFrequency frequency = HabitFrequency.daily,
    Set<int> scheduledDays = allWeekdays,
    int targetPerWeek = 1,
    required DateTime startDate,
    DateTime? endDate,
    bool isActive = true,
    List<HabitReminder> reminders = const [],
  }) async {
    final cleanName = name.trim();
    if (cleanName.isEmpty || cleanName.length > 80) {
      throw ArgumentError('Nama habit wajib diisi, maksimal 80 karakter.');
    }
    if (description.length > 500) {
      throw ArgumentError('Deskripsi maksimal 500 karakter.');
    }
    if (targetPerWeek < 1 || targetPerWeek > 7) {
      throw ArgumentError('Target mingguan harus antara 1 dan 7 kali.');
    }
    if (reminders.length > 5) {
      throw ArgumentError('Maksimal lima pengingat per habit.');
    }
    final start = CivilDate.from(startDate);
    final end = endDate == null ? null : CivilDate.from(endDate);
    if (end != null && end.isBefore(start)) {
      throw ArgumentError('Tanggal berakhir tidak boleh sebelum tanggal mulai.');
    }
    final days = frequency == HabitFrequency.weeklyDays
        ? {...scheduledDays}
        : {...allWeekdays};
    validateWeekdays(days);
    for (final reminder in reminders) {
      validateReminder(reminder);
      if (reminder.recurrence == ReminderRecurrence.daily &&
          reminder.days.length != 7) {
        throw ArgumentError('Jadwal harian harus mencakup tujuh hari.');
      }
    }

    return _database.transaction(() async {
      final now = _clock();
      final today = CivilDate.from(now);
      var createdAt = now.millisecondsSinceEpoch;
      if (id != null) {
        final existing = await _database.customSelect(
          'SELECT id, created_at, is_active FROM habits WHERE id = ?',
          variables: [Variable.withInt(id!)],
        ).getSingleOrNull();
        if (existing == null) throw StateError('Habit tidak ditemukan.');
        createdAt = existing.read<int>('created_at');
        await _database.customUpdate(
          'UPDATE habits SET name=?, description=?, icon=?, color=?, frequency=?, '
          'scheduled_days=?, target_per_week=?, start_date=?, end_date=?, is_active=? WHERE id=?',
          variables: [
            Variable.withString(cleanName),
            Variable.withString(description.trim()),
            Variable.withString(icon),
            Variable.withInt(color),
            Variable.withString(_frequencyValue(frequency)),
            Variable.withString(_csv(days)),
            Variable.withInt(targetPerWeek),
            Variable.withString(start.key),
            Variable<String>(end?.key),
            Variable.withInt(isActive ? 1 : 0),
            Variable.withInt(id!),
          ],
        );
        if ((existing.read<int>('is_active') == 1) != isActive) {
          await _recordPauseTransition(id!, isActive, today);
        }
      } else {
        id = await _database.customInsert(
          'INSERT INTO habits (name, description, icon, color, frequency, '
          'scheduled_days, target_per_week, start_date, end_date, is_active, created_at) '
          'VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)',
          variables: [
            Variable.withString(cleanName),
            Variable.withString(description.trim()),
            Variable.withString(icon),
            Variable.withInt(color),
            Variable.withString(_frequencyValue(frequency)),
            Variable.withString(_csv(days)),
            Variable.withInt(targetPerWeek),
            Variable.withString(start.key),
            Variable<String>(end?.key),
            Variable.withInt(isActive ? 1 : 0),
            Variable.withInt(createdAt),
          ],
        );
        if (!isActive) {
          await _insertPause(id!, CivilDate.max(today, start));
        }
      }

      final existingReminders = await _database.customSelect(
        'SELECT id FROM habit_reminders WHERE habit_id = ?',
        variables: [Variable.withInt(id!)],
      ).get();
      final existingIds =
          existingReminders.map((row) => row.read<int>('id')).toSet();
      final keptIds = <int>{};
      for (final reminder in reminders) {
        if (reminder.id != null && !existingIds.contains(reminder.id)) {
          throw ArgumentError('Pengingat bukan milik habit ini.');
        }
        final values = [
          Variable.withInt(id!),
          Variable.withInt(reminder.minutes),
          Variable.withString(_csv(reminder.days)),
          Variable.withString(reminder.startDate.key),
          Variable.withString(reminder.recurrence.name),
          Variable.withInt(reminder.enabled ? 1 : 0),
          Variable.withInt(reminder.sound ? 1 : 0),
          Variable.withInt(reminder.vibration ? 1 : 0),
          Variable.withString(reminder.title.trim()),
          Variable.withString(reminder.body.trim()),
        ];
        if (reminder.id == null) {
          await _database.customInsert(
            'INSERT INTO habit_reminders (habit_id, minutes, days, start_date, '
            'recurrence, enabled, sound, vibration, title, body, created_at) '
            'VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)',
            variables: [...values, Variable.withInt(createdAt)],
          );
        } else {
          keptIds.add(reminder.id!);
          await _database.customUpdate(
            'UPDATE habit_reminders SET habit_id=?, minutes=?, days=?, start_date=?, '
            'recurrence=?, enabled=?, sound=?, vibration=?, title=?, body=? WHERE id=?',
            variables: [...values, Variable.withInt(reminder.id!)],
          );
        }
      }
      for (final removedId in existingIds.difference(keptIds)) {
        await _database.customUpdate(
          'DELETE FROM habit_reminders WHERE id = ?',
          variables: [Variable.withInt(removedId)],
        );
      }
      return id!;
    });
  }

  Future<void> setActive(int id, bool active) => _database.transaction(() async {
        final row = await _database.customSelect(
          'SELECT is_active FROM habits WHERE id = ?',
          variables: [Variable.withInt(id)],
        ).getSingleOrNull();
        if (row == null) throw StateError('Habit tidak ditemukan.');
        if ((row.read<int>('is_active') == 1) == active) return;
        await _database.customUpdate(
          'UPDATE habits SET is_active = ? WHERE id = ?',
          variables: [Variable.withInt(active ? 1 : 0), Variable.withInt(id)],
        );
        await _recordPauseTransition(id, active, CivilDate.from(_clock()));
      });

  Future<void> _recordPauseTransition(
      int id, bool active, CivilDate today) async {
    if (active) {
      await _database.customUpdate(
        'UPDATE habit_pauses SET end_date = ? WHERE habit_id = ? AND end_date IS NULL',
        variables: [Variable.withString(today.key), Variable.withInt(id)],
      );
    } else {
      await _insertPause(id, today);
    }
  }

  Future<void> _insertPause(int id, CivilDate date) => _database.customInsert(
        'INSERT INTO habit_pauses (habit_id, start_date) VALUES (?, ?)',
        variables: [Variable.withInt(id), Variable.withString(date.key)],
      );

  /// Idempotent: repeating a completion never creates a second log or toggles it off.
  Future<bool> complete(int habitId, DateTime date) =>
      setCompletion(habitId, date, true);

  Future<void> removeCompletion(int habitId, DateTime date) =>
      setCompletion(habitId, date, false);

  Future<bool> setCompletion(
          int habitId, DateTime date, bool completed) async =>
      _database.transaction(() async {
        final habit = await get(habitId);
        if (habit == null) throw StateError('Habit tidak ditemukan.');
        final day = CivilDate.from(date);
        if (completed) {
          if (day.isAfter(CivilDate.from(_clock()))) {
            throw ArgumentError('Tanggal mendatang belum bisa diselesaikan.');
          }
          if (!habit.isInRange(day.value)) {
            throw ArgumentError('Tanggal berada di luar rentang habit.');
          }
          if (!habit.isScheduled(day.value)) {
            throw ArgumentError('Tanggal ini bukan jadwal habit.');
          }
          if (habit.isPausedOn(day.value)) {
            throw ArgumentError('Habit sedang dijeda pada tanggal ini.');
          }
        }
        if (completed) {
          final inserted = await _database.customInsert(
            'INSERT OR IGNORE INTO habit_completions '
            '(habit_id, completion_date, created_at) VALUES (?, ?, ?)',
            variables: [
              Variable.withInt(habitId),
              Variable.withString(day.key),
              Variable.withInt(_clock().millisecondsSinceEpoch),
            ],
          );
          // sqlite's last_insert_rowid is unchanged on IGNORE, so inspect changes.
          final changes =
              await _database.customSelect('SELECT changes() AS count').getSingle();
          return changes.read<int>('count') > 0 && inserted >= 0;
        }
        await _database.customUpdate(
          'DELETE FROM habit_completions WHERE habit_id = ? AND completion_date = ?',
          variables: [Variable.withInt(habitId), Variable.withString(day.key)],
        );
        return false;
      });

  Future<void> delete(int id) => _database.transaction(() async {
        final changed = await _database.customUpdate(
          'DELETE FROM habits WHERE id = ?',
          variables: [Variable.withInt(id)],
        );
        if (changed == 0) throw StateError('Habit tidak ditemukan.');
      });

  Habit _fromRow(QueryRow row, Set<String> completions,
      List<HabitReminder> reminders, List<HabitPause> pauses,
      bool hasCounter, Set<String> counterCompletedDates) {
    final frequency = switch (row.read<String>('frequency')) {
      'daily' => HabitFrequency.daily,
      'weekly_days' || 'weeklyDays' => HabitFrequency.weeklyDays,
      'times_per_week' || 'timesPerWeek' => HabitFrequency.timesPerWeek,
      _ => throw StateError('Frekuensi habit tidak dikenal.'),
    };
    return Habit(
      id: row.read<int>('id'),
      name: row.read<String>('name'),
      description: row.read<String>('description'),
      icon: row.read<String>('icon'),
      color: row.read<int>('color'),
      frequency: frequency,
      scheduledDays: _days(row.read<String>('scheduled_days')),
      targetPerWeek: row.read<int>('target_per_week'),
      startDate: CivilDate.parse(row.read<String>('start_date')),
      endDate: row.read<String?>('end_date') == null
          ? null
          : CivilDate.parse(row.read<String>('end_date')),
      isActive: row.read<int>('is_active') == 1,
      createdAt: DateTime.fromMillisecondsSinceEpoch(row.read<int>('created_at')),
      completedDates: completions,
      hasCounter: hasCounter,
      counterCompletedDates: counterCompletedDates,
      reminders: reminders,
      pauses: pauses,
    );
  }

  HabitReminder _reminderFromRow(QueryRow row) => HabitReminder(
        id: row.read<int>('id'),
        minutes: row.read<int>('minutes'),
        days: _days(row.read<String>('days')),
        startDate: CivilDate.parse(row.read<String>('start_date')),
        recurrence: ReminderRecurrence.values.byName(row.read<String>('recurrence')),
        enabled: row.read<int>('enabled') == 1,
        sound: row.read<int>('sound') == 1,
        vibration: row.read<int>('vibration') == 1,
        title: row.read<String>('title'),
        body: row.read<String>('body'),
      );

  Set<int> _days(String value) =>
      value.split(',').where((part) => part.isNotEmpty).map(int.parse).toSet();
  String _csv(Set<int> values) => (values.toList()..sort()).join(',');
  String _frequencyValue(HabitFrequency frequency) => switch (frequency) {
        HabitFrequency.daily => 'daily',
        HabitFrequency.weeklyDays => 'weekly_days',
        HabitFrequency.timesPerWeek => 'times_per_week',
      };
}
