import '../core/utils/civil_date.dart';
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

/// Per-render index: avoids scanning the full journal and recomputing the same
/// day for calendar cells, monthly summary, weekly summary and selection.
class ActivityCalendarIndex {
  ActivityCalendarIndex(this.habits, List<LifeEntry> entries) {
    for (final entry in entries) {
      _entries.putIfAbsent(entry.date.key, () => entry);
    }
  }
  final List<Habit> habits;
  final Map<String, LifeEntry> _entries = {};
  final Map<String, ActivityDay> _days = {};

  ActivityDay day(DateTime date) {
    final key = CivilDate.from(date).key;
    return _days.putIfAbsent(key, () {
      final entry = _entries[key];
      return activityForDay(date, habits, entry == null ? const [] : [entry]);
    });
  }
}
