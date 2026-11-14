import 'package:apk_idk/core/utils/civil_date.dart';
import 'package:apk_idk/data/habit_repository.dart';
import 'package:apk_idk/data/savings_database.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late SavingsDatabase database;
  late HabitRepository repository;
  var now = DateTime(2026, 1, 14, 12); // Wednesday

  setUp(() {
    now = DateTime(2026, 1, 14, 12);
    database = SavingsDatabase.forTesting(NativeDatabase.memory());
    repository = HabitRepository(database, clock: () => now);
  });
  tearDown(() => database.close());

  test('creates and edits every habit field without resetting created_at', () async {
    final id = await repository.save(
      name: '  Menabung  ',
      description: 'Sisihkan yang tersedia',
      icon: 'flag',
      color: 0xFFFFD84D,
      frequency: HabitFrequency.weeklyDays,
      scheduledDays: {1, 3, 5},
      startDate: DateTime(2026, 1, 1),
      endDate: DateTime(2026, 3, 1),
      reminders: [
        HabitReminder(
          minutes: 19 * 60,
          days: {1, 3, 5},
          startDate: CivilDate(DateTime(2026, 1, 1)),
          title: 'Waktunya menabung',
          body: 'Tidak perlu memaksakan setoran.',
        ),
      ],
    );
    final original = (await repository.get(id))!;
    expect(original.name, 'Menabung');
    expect(original.frequency, HabitFrequency.weeklyDays);
    expect(original.scheduledDays, {1, 3, 5});
    expect(original.reminders.single.timeLabel, '19.00');

    now = DateTime(2026, 1, 15, 12);
    await repository.save(
      id: id,
      name: 'Tinjau anggaran',
      description: 'Mingguan',
      icon: 'checklist',
      color: 0xFFA7C7FF,
      frequency: HabitFrequency.timesPerWeek,
      targetPerWeek: 2,
      startDate: DateTime(2026, 1, 2),
      endDate: null,
      isActive: false,
      reminders: [],
    );
    final edited = (await repository.get(id))!;
    expect(edited.name, 'Tinjau anggaran');
    expect(edited.frequency, HabitFrequency.timesPerWeek);
    expect(edited.targetPerWeek, 2);
    expect(edited.endDate, isNull);
    expect(edited.isActive, isFalse);
    expect(edited.createdAt, original.createdAt);
    expect(edited.pauses.single.startDate.key, '2026-01-15');
    expect(edited.reminders, isEmpty);
  });

  test('completion is idempotent, date-keyed, and explicitly removable', () async {
    final id = await repository.save(name: 'Catat pengeluaran', startDate: DateTime(2026, 1, 1));
    expect(await repository.complete(id, DateTime(2026, 1, 14, 1)), isTrue);
    expect(await repository.complete(id, DateTime(2026, 1, 14, 23, 59)), isFalse);
    await Future.wait([
      repository.complete(id, DateTime(2026, 1, 14, 8)),
      repository.complete(id, DateTime(2026, 1, 14, 9)),
    ]);
    final logs = await database.customSelect('SELECT * FROM habit_completions').get();
    expect(logs, hasLength(1));
    expect(logs.single.read<String>('completion_date'), '2026-01-14');
    await repository.removeCompletion(id, DateTime(2026, 1, 14));
    expect((await repository.get(id))!.completedDates, isEmpty);
  });

  test('rejects future, unscheduled, out-of-range and paused completions', () async {
    final id = await repository.save(
      name: 'Hari kerja',
      frequency: HabitFrequency.weeklyDays,
      scheduledDays: {1, 2, 3, 4, 5},
      startDate: DateTime(2026, 1, 1),
      endDate: DateTime(2026, 1, 31),
    );
    await expectLater(repository.complete(id, DateTime(2026, 1, 15)), throwsArgumentError);
    await expectLater(repository.complete(id, DateTime(2026, 1, 17)), throwsArgumentError);
    await expectLater(repository.complete(id, DateTime(2025, 12, 31)), throwsArgumentError);
    await repository.setActive(id, false);
    await expectLater(repository.complete(id, DateTime(2026, 1, 14)), throwsArgumentError);
    now = DateTime(2026, 1, 16, 12);
    await repository.setActive(id, true);
    expect(await repository.complete(id, DateTime(2026, 1, 16)), isTrue);
    final habit = (await repository.get(id))!;
    expect(habit.pauses.single.startDate.key, '2026-01-14');
    expect(habit.pauses.single.endDate!.key, '2026-01-16');
  });

  test('editing reminders retains existing identities and removes only dropped ones', () async {
    final start = CivilDate(DateTime(2026, 1, 1));
    final id = await repository.save(name: 'Menabung', startDate: start.value, reminders: [
      HabitReminder(minutes: 600, days: {1, 2}, startDate: start),
      HabitReminder(minutes: 1200, days: {1, 2}, startDate: start),
    ]);
    final before = (await repository.get(id))!.reminders;
    await repository.save(
      id: id,
      name: 'Menabung',
      startDate: start.value,
      reminders: [before.first.copyWith(minutes: 630, days: {3})],
    );
    final after = (await repository.get(id))!.reminders.single;
    expect(after.id, before.first.id);
    expect(after.minutes, 630);
    expect(after.days, {3});
  });

  test('deleting a habit cascades logs, reminders and pauses but not transactions', () async {
    await database.customInsert(
      "INSERT INTO savings_transactions (type, amount, category, created_at) VALUES ('income', 10000, 'Uang saku', 1)",
    );
    final id = await repository.save(name: 'Menabung', startDate: DateTime(2026, 1, 1), reminders: [
      HabitReminder(minutes: 1140, days: {1}, startDate: CivilDate(DateTime(2026, 1, 1))),
    ]);
    await repository.complete(id, DateTime(2026, 1, 14));
    await repository.setActive(id, false);
    await repository.delete(id);
    expect(await repository.get(id), isNull);
    for (final table in ['habit_reminders', 'habit_completions', 'habit_pauses']) {
      expect(await database.customSelect('SELECT * FROM $table').get(), isEmpty);
    }
    expect(await database.customSelect('SELECT * FROM savings_transactions').get(), hasLength(1));
  });

  test('validates names, weekdays, frequency targets and date ranges', () async {
    await expectLater(repository.save(name: ' ', startDate: DateTime(2026, 1, 1)), throwsArgumentError);
    await expectLater(
      repository.save(name: 'X', startDate: DateTime(2026, 1, 1), frequency: HabitFrequency.weeklyDays, scheduledDays: {}),
      throwsArgumentError,
    );
    await expectLater(
      repository.save(name: 'X', startDate: DateTime(2026, 1, 2), endDate: DateTime(2026, 1, 1)),
      throwsArgumentError,
    );
    await expectLater(
      repository.save(name: 'X', startDate: DateTime(2026, 1, 1), frequency: HabitFrequency.timesPerWeek, targetPerWeek: 8),
      throwsArgumentError,
    );
  });
}
