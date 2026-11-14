import 'package:apk_idk/core/utils/civil_date.dart';
import 'package:apk_idk/data/habit.dart';
import 'package:apk_idk/domain/habit_statistics.dart';
import 'package:flutter_test/flutter_test.dart';

Habit habit({
  HabitFrequency frequency = HabitFrequency.daily,
  Set<int> days = allWeekdays,
  Set<String> completed = const {},
  List<HabitPause> pauses = const [],
  int target = 2,
  DateTime? start,
  DateTime? end,
}) =>
    Habit(
      id: 1,
      name: 'Test',
      description: '',
      icon: 'savings',
      color: 0xFFB8F56A,
      frequency: frequency,
      scheduledDays: days,
      targetPerWeek: target,
      startDate: CivilDate.from(start ?? DateTime(2026, 1, 1)),
      endDate: end == null ? null : CivilDate.from(end),
      isActive: true,
      createdAt: DateTime(2026, 1, 1),
      completedDates: completed,
      pauses: pauses,
    );

void main() {
  test('daily streak gives today grace and skips paused days', () {
    final value = habit(completed: {'2026-01-12', '2026-01-13', '2026-01-15'}, pauses: [
      HabitPause(startDate: CivilDate(DateTime(2026, 1, 14)), endDate: CivilDate(DateTime(2026, 1, 15))),
    ]);
    final stats = calculateHabitStatistics(value, now: DateTime(2026, 1, 15, 20));
    expect(stats.streak, 3);
    expect(stats.daily.label, '1/1');
  });

  test('unscheduled days do not fail a fixed weekday streak', () {
    final value = habit(
      frequency: HabitFrequency.weeklyDays,
      days: {1, 3, 5},
      completed: {'2026-01-05', '2026-01-07', '2026-01-09'},
    );
    final stats = calculateHabitStatistics(value, now: DateTime(2026, 1, 10));
    expect(stats.streak, 3);
    expect(stats.weekly.label, '3/3');
  });

  test('a missed scheduled day ends the streak without shame labels', () {
    final value = habit(frequency: HabitFrequency.weeklyDays, days: {1, 3, 5}, completed: {
      '2026-01-05', '2026-01-09', '2026-01-12', '2026-01-14',
    });
    final stats = calculateHabitStatistics(value, now: DateTime(2026, 1, 14, 18));
    expect(stats.streak, 3);
    expect(stats.bestStreak, 3);
  });

  test('flexible habits count fulfilled weeks and allow current week in progress', () {
    final value = habit(frequency: HabitFrequency.timesPerWeek, target: 2, completed: {
      '2026-01-05', '2026-01-06', '2026-01-12',
    });
    final stats = calculateHabitStatistics(value, now: DateTime(2026, 1, 14));
    expect(stats.streak, 1);
    expect(stats.streakUnit, 'minggu');
    expect(stats.weekly.label, '1/2');
  });

  test('a pause touching an unfulfilled flexible week does not break streak', () {
    final value = habit(frequency: HabitFrequency.timesPerWeek, target: 3, completed: {
      '2026-01-05', '2026-01-06', '2026-01-07', '2026-01-19', '2026-01-20', '2026-01-21',
    }, pauses: [
      HabitPause(startDate: CivilDate(DateTime(2026, 1, 14)), endDate: CivilDate(DateTime(2026, 1, 16))),
    ]);
    final stats = calculateHabitStatistics(value, now: DateTime(2026, 1, 21));
    expect(stats.streak, 2);
  });

  test('monthly progress uses the actual schedule and pause history', () {
    final value = habit(frequency: HabitFrequency.weeklyDays, days: {1, 3}, start: DateTime(2026, 1, 1), end: DateTime(2026, 1, 31), completed: {
      '2026-01-05', '2026-01-07',
    }, pauses: [
      HabitPause(startDate: CivilDate(DateTime(2026, 1, 12)), endDate: CivilDate(DateTime(2026, 1, 15))),
    ]);
    final stats = calculateHabitStatistics(value, now: DateTime(2026, 1, 31));
    // Jan has 8 Mon/Wed opportunities; paused Jan 12 and 14 remove two.
    expect(stats.monthly.label, '2/6');
  });

  test('civil dates normalize time-of-day and reject non-canonical keys', () {
    expect(CivilDate.from(DateTime(2026, 1, 14, 23, 59)).key, '2026-01-14');
    expect(CivilDate.from(DateTime(2026, 1, 14)).nextDay.key, '2026-01-15');
    expect(() => CivilDate.parse('2026-02-30'), throwsFormatException);
    expect(() => CivilDate.parse('2026-1-14'), throwsFormatException);
  });
}
