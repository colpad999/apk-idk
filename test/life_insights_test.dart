import 'package:apk_idk/core/utils/civil_date.dart';
import 'package:apk_idk/data/habit.dart';
import 'package:apk_idk/data/life_repository.dart';
import 'package:apk_idk/domain/life_insights.dart';
import 'package:flutter_test/flutter_test.dart';

Habit habit(int id, HabitFrequency frequency, Set<String> completed) => Habit(
  id: id, name: 'Habit', description: '', icon: 'school', color: 0xff000000,
  frequency: frequency, scheduledDays: allWeekdays, targetPerWeek: 1,
  startDate: CivilDate.parse('2026-01-01'), endDate: null, isActive: true,
  createdAt: DateTime(2026), completedDates: completed);

void main() {
  test('mood counts respect local inclusive date boundaries and omit no mood', () {
    final entries = [
      LifeEntry(date: CivilDate.parse('2026-01-04'), journal: '', mood: 5, moodNote: ''),
      LifeEntry(date: CivilDate.parse('2026-01-05'), journal: '', mood: 4, moodNote: ''),
      LifeEntry(date: CivilDate.parse('2026-01-06'), journal: '', mood: null, moodNote: ''),
      LifeEntry(date: CivilDate.parse('2026-01-07'), journal: '', mood: 4, moodNote: ''),
    ];
    expect(moodCounts(entries, CivilDate.parse('2026-01-05'), CivilDate.parse('2026-01-06')), [0, 0, 0, 1, 0]);
  });
  test('achievement days use scheduled daily streaks, not flexible weeks', () {
    final days = <String>{for (var d = 1; d <= 7; d++) '2026-01-${d.toString().padLeft(2, '0')}'};
    final fixed = habit(1, HabitFrequency.daily, days);
    final flexible = habit(2, HabitFrequency.timesPerWeek, days);
    expect(habitAchievements([fixed], DateTime(2026, 1, 7))[1].unlocked, isTrue);
    expect(habitAchievements([flexible], DateTime(2026, 1, 7))[1].unlocked, isFalse);
    expect(habitAchievements([fixed, flexible, habit(3, HabitFrequency.daily, days)], DateTime(2026, 1, 7)).last.unlocked, isTrue);
    expect(habitAchievements([], DateTime(2026, 1, 7)).first.unlocked, isFalse);
  });
}
