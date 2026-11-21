import 'package:apk_idk/core/utils/civil_date.dart';
import 'package:apk_idk/data/habit.dart';
import 'package:apk_idk/data/life_repository.dart';
import 'package:apk_idk/domain/activity_calendar.dart';
import 'package:flutter_test/flutter_test.dart';

Habit _habit(int id, HabitFrequency frequency, Set<int> days, Set<String> done, {List<HabitPause> pauses = const []}) => Habit(
  id: id, name: 'Habit $id', description: '', icon: 'school', color: 0xffaabbcc,
  frequency: frequency, scheduledDays: days, targetPerWeek: 2,
  startDate: CivilDate.parse('2026-01-01'), endDate: null, isActive: true,
  createdAt: DateTime(2026), completedDates: done, pauses: pauses);

void main() {
  test('calendar index returns the same results and reuses a day', () {
    final date = DateTime(2026, 1, 5);
    final habit = _habit(1, HabitFrequency.daily, allWeekdays, {'2026-01-05'});
    final entry = LifeEntry(date: CivilDate.from(date), journal: 'Ada', mood: 3, moodNote: '');
    final index = ActivityCalendarIndex([habit], [entry]);
    final day = index.day(date);
    final expected = activityForDay(date, [habit], [entry]);
    expect(day.completed, expected.completed);
    expect(day.entry, expected.entry);
    expect(identical(day, index.day(DateTime(2026, 1, 5, 20))), isTrue);
    expect(index.day(DateTime(2026, 1, 6)).entry, isNull);
  });
  test('fixed, flexible and paused habits have distinct calendar semantics', () {
    final date = DateTime(2026, 1, 5); // Monday
    final fixed = _habit(1, HabitFrequency.weeklyDays, {1, 3}, {'2026-01-05'});
    final flexible = _habit(2, HabitFrequency.timesPerWeek, allWeekdays, {});
    final paused = _habit(3, HabitFrequency.daily, allWeekdays, {}, pauses: [HabitPause(startDate: CivilDate.parse('2026-01-05'))]);
    final entry = LifeEntry(date: CivilDate.from(date), journal: 'Catatan', mood: 4, moodNote: '');
    final day = activityForDay(date, [fixed, flexible, paused], [entry]);
    expect(day.scheduled, [fixed]);
    expect(day.completed, [fixed]);
    expect(day.pending, 0);
    expect(day.flexible, [flexible]);
    expect(day.entry?.journal, 'Catatan');
    expect(activityForDay(DateTime(2026, 1, 6), [fixed], []).scheduled, isEmpty);
  });
}
