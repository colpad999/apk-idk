import '../core/utils/civil_date.dart';
import '../data/habit.dart';

class HabitProgress {
  const HabitProgress({required this.completed, required this.target});
  final int completed, target;
  double get ratio => target == 0 ? 0 : (completed / target).clamp(0, 1);
  String get label => '$completed/$target';
}

class HabitStatistics {
  const HabitStatistics({
    required this.streak,
    required this.bestStreak,
    required this.daily,
    required this.weekly,
    required this.monthly,
    required this.completionRate,
    required this.totalOpportunities,
    required this.totalCompleted,
    required this.streakUnit,
  });

  final int streak, bestStreak;
  final HabitProgress daily, weekly, monthly;
  final double completionRate;
  final int totalOpportunities, totalCompleted;
  final String streakUnit;
}

/// Fixed schedules count scheduled days; flexible schedules count fulfilled weeks.
/// The current day/week has grace until it ends. Paused opportunities are skipped.
/// A flexible week touched by a pause is not treated as a failed week.
HabitStatistics calculateHabitStatistics(Habit habit, {DateTime? now}) {
  final referenceToday = CivilDate.from(now ?? DateTime.now());
  final asOf = habit.endDate == null
      ? referenceToday
      : CivilDate.min(referenceToday, habit.endDate!);
  var opportunities = 0;
  var completed = 0;
  var best = 0;
  var current = 0;
  var trailing = 0;

  void record(bool success, bool unfinishedGrace) {
    opportunities++;
    if (success) {
      completed++;
      current++;
      trailing++;
      if (current > best) best = current;
    } else if (!unfinishedGrace) {
      current = 0;
      trailing = 0;
    }
  }

  if (habit.isFlexible) {
    var week = habit.startDate.weekStart;
    while (week.isAtOrBefore(asOf.weekStart)) {
      final end = week.addDays(6);
      if (_activeDays(habit, week, end) > 0) {
        final success = _weekCompletions(habit, week) >= habit.targetPerWeek;
        final grace = !referenceToday.isBefore(week) &&
            !referenceToday.isAfter(end) &&
            asOf.isAtOrAfter(referenceToday);
        final paused = _weekHasPause(habit, week, end);
        if (!paused || success) record(success, grace);
      }
      week = week.addDays(7);
    }
  } else {
    var day = habit.startDate;
    while (day.isAtOrBefore(asOf)) {
      if (habit.isOpportunity(day.value)) {
        record(habit.isComplete(day.value),
            day == referenceToday && asOf == referenceToday);
      }
      day = day.nextDay;
    }
  }

  return HabitStatistics(
    streak: trailing,
    bestStreak: best,
    daily: _dailyProgress(habit, referenceToday),
    weekly: _weeklyProgress(habit, referenceToday.weekStart),
    monthly: _monthlyProgress(habit, referenceToday),
    completionRate: opportunities == 0 ? 0 : completed / opportunities,
    totalOpportunities: opportunities,
    totalCompleted: completed,
    streakUnit: habit.isFlexible ? 'minggu' : 'hari',
  );
}

int calculateHabitStreak(Habit habit, {DateTime? today}) =>
    calculateHabitStatistics(habit, now: today).streak;

int _activeDays(Habit habit, CivilDate start, CivilDate end) {
  var count = 0;
  var day = CivilDate.max(start, habit.startDate);
  final last = habit.endDate == null ? end : CivilDate.min(end, habit.endDate!);
  while (day.isAtOrBefore(last)) {
    if (habit.isOpportunity(day.value)) count++;
    day = day.nextDay;
  }
  return count;
}

bool _weekHasPause(Habit habit, CivilDate start, CivilDate end) {
  var day = CivilDate.max(start, habit.startDate);
  final last = habit.endDate == null ? end : CivilDate.min(end, habit.endDate!);
  while (day.isAtOrBefore(last)) {
    if (habit.isPausedOn(day.value)) return true;
    day = day.nextDay;
  }
  return false;
}

int _weekCompletions(Habit habit, CivilDate weekStart) {
  var count = 0;
  for (var offset = 0; offset < 7; offset++) {
    final day = weekStart.addDays(offset);
    if (habit.isOpportunity(day.value) && habit.isComplete(day.value)) count++;
  }
  return count;
}

HabitProgress _dailyProgress(Habit habit, CivilDate today) => HabitProgress(
      completed:
          habit.isOpportunity(today.value) && habit.isComplete(today.value) ? 1 : 0,
      target: habit.isOpportunity(today.value) ? 1 : 0,
    );

HabitProgress _weeklyProgress(Habit habit, CivilDate weekStart) {
  final end = weekStart.addDays(6);
  if (habit.isFlexible) {
    final active = _activeDays(habit, weekStart, end);
    return HabitProgress(
        completed:
            _weekCompletions(habit, weekStart).clamp(0, habit.targetPerWeek),
        target: active == 0 ? 0 : habit.targetPerWeek);
  }
  return _fixedProgress(habit, weekStart, end);
}

HabitProgress _monthlyProgress(Habit habit, CivilDate today) {
  final start = today.monthStart;
  final end = today.nextMonth.previousDay;
  if (!habit.isFlexible) return _fixedProgress(habit, start, end);
  var target = 0;
  var completed = 0;
  var week = start.weekStart;
  while (week.isAtOrBefore(end)) {
    final progress = _weeklyProgress(habit, week);
    target += progress.target;
    var inMonth = 0;
    for (var offset = 0; offset < 7; offset++) {
      final day = week.addDays(offset);
      if (day.month == today.month &&
          day.year == today.year &&
          habit.isOpportunity(day.value) &&
          habit.isComplete(day.value)) inMonth++;
    }
    completed += inMonth.clamp(0, progress.target);
    week = week.addDays(7);
  }
  return HabitProgress(completed: completed, target: target);
}

HabitProgress _fixedProgress(Habit habit, CivilDate start, CivilDate end) {
  var target = 0;
  var completed = 0;
  var day = CivilDate.max(start, habit.startDate);
  final last = habit.endDate == null ? end : CivilDate.min(end, habit.endDate!);
  while (day.isAtOrBefore(last)) {
    if (habit.isOpportunity(day.value)) {
      target++;
      if (habit.isComplete(day.value)) completed++;
    }
    day = day.nextDay;
  }
  return HabitProgress(completed: completed, target: target);
}
