import '../core/utils/civil_date.dart';
import '../data/habit.dart';
import '../data/life_repository.dart';
import 'habit_statistics.dart';

/// Counts recorded mood labels, not a mental-health assessment or score.
List<int> moodCounts(List<LifeEntry> entries, CivilDate start, CivilDate end) {
  final result = List<int>.filled(5, 0);
  for (final entry in entries) {
    final mood = entry.mood;
    if (mood != null && mood >= 1 && mood <= 5 &&
        entry.date.isAtOrAfter(start) && entry.date.isAtOrBefore(end)) {
      result[mood - 1]++;
    }
  }
  return result;
}

class HabitAchievement {
  const HabitAchievement(this.title, this.description, this.unlocked);
  final String title, description;
  final bool unlocked;
}

/// Computed from existing validated completions; no separate mutable rewards.
/// Seven/30 day achievements are fixed-schedule streaks; flexible streaks are
/// weeks and must not be confused with days.
List<HabitAchievement> habitAchievements(List<Habit> habits, DateTime now) {
  final reference = CivilDate.from(now);
  var any = false, bestDays = 0;
  final perDay = <String, int>{};
  for (final habit in habits) {
    final stats = calculateHabitStatistics(habit, now: now);
    if (!habit.isFlexible && stats.bestStreak > bestDays) { bestDays = stats.bestStreak; }
    for (final key in habit.completedDates) {
      final date = CivilDate.parse(key);
      if (date.isAfter(reference) || !habit.isOpportunity(date.value)) { continue; }
      any = true;
      perDay[key] = (perDay[key] ?? 0) + 1;
    }
  }
  return [
    HabitAchievement('First Step', 'Selesaikan satu habit.', any),
    HabitAchievement('7 Days', 'Streak 7 hari terjadwal pada satu habit.', bestDays >= 7),
    HabitAchievement('Consistent', 'Streak 30 hari terjadwal pada satu habit.', bestDays >= 30),
    HabitAchievement('Productive', 'Selesaikan 3 habit dalam satu hari.', perDay.values.any((count) => count >= 3)),
  ];
}
