import '../data/habit.dart';
import '../data/life_repository.dart';

/// Flexible habits have weekly rather than daily targets; they are listed, but
/// never counted as missed daily opportunities in calendar aggregates.
class ActivityDay {
  const ActivityDay({required this.scheduled, required this.completed, required this.flexible, this.entry});
  final List<Habit> scheduled, completed, flexible;
  final LifeEntry? entry;
  int get pending => scheduled.length - completed.length;
}

ActivityDay activityForDay(DateTime date, List<Habit> habits, List<LifeEntry> entries) {
  final scheduled = habits.where((h) => !h.isFlexible && h.isOpportunity(date)).toList();
  final completed = scheduled.where((h) => h.isComplete(date)).toList();
  final flexible = habits.where((h) => h.isFlexible && h.isOpportunity(date)).toList();
  LifeEntry? entry;
  for (final item in entries) {
    if (item.date.year == date.year && item.date.month == date.month && item.date.day == date.day) {
      entry = item;
      break;
    }
  }
  return ActivityDay(scheduled: scheduled, completed: completed, flexible: flexible, entry: entry);
}
