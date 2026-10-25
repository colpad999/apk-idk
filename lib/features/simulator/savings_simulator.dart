enum SavingFrequency { daily, weekly, monthly }

class SavingsProjectionPoint {
  const SavingsProjectionPoint({required this.date, required this.balance});

  final DateTime date;
  final int balance;
}

class SavingsProjection {
  const SavingsProjection(
      {required this.points,
      required this.totalContributions,
      required this.reachedAt,
      required this.target});

  final List<SavingsProjectionPoint> points;
  final int totalContributions;
  final DateTime? reachedAt;
  final int target;

  int get endingBalance => points.last.balance;
  bool get reachesTarget => endingBalance >= target || reachedAt != null;
}

SavingsProjection simulateSavings({
  required int startingBalance,
  required int contribution,
  required SavingFrequency frequency,
  required int target,
  required int months,
  DateTime? startDate,
}) {
  if (startingBalance < 0) {
    throw ArgumentError.value(
        startingBalance, 'startingBalance', 'Saldo awal tidak boleh negatif.');
  }
  if (contribution <= 0) {
    throw ArgumentError.value(
        contribution, 'contribution', 'Setoran harus lebih dari Rp0.');
  }
  if (target <= 0) {
    throw ArgumentError.value(target, 'target', 'Target harus lebih dari Rp0.');
  }
  if (months < 1 || months > 120) {
    throw ArgumentError.value(
        months, 'months', 'Periode harus antara 1 dan 120 bulan.');
  }

  final start = startDate ?? DateTime.now();
  final points = <SavingsProjectionPoint>[
    SavingsProjectionPoint(date: start, balance: startingBalance)
  ];
  var balance = startingBalance;
  var totalContributions = 0;
  DateTime? reachedAt = startingBalance >= target ? start : null;
  var contributionIndex = 1;
  var nextContribution = _contributionAt(start, frequency, contributionIndex);

  for (var month = 1; month <= months; month++) {
    final checkpoint = _addMonthsClamped(start, month);
    while (!nextContribution.isAfter(checkpoint)) {
      balance += contribution;
      totalContributions += contribution;
      if (reachedAt == null && balance >= target) reachedAt = nextContribution;
      contributionIndex++;
      nextContribution = _contributionAt(start, frequency, contributionIndex);
    }
    points.add(SavingsProjectionPoint(date: checkpoint, balance: balance));
  }

  return SavingsProjection(
      points: points,
      totalContributions: totalContributions,
      reachedAt: reachedAt,
      target: target);
}

DateTime _contributionAt(
        DateTime start, SavingFrequency frequency, int index) =>
    switch (frequency) {
      SavingFrequency.daily => start.add(Duration(days: index)),
      SavingFrequency.weekly => start.add(Duration(days: 7 * index)),
      SavingFrequency.monthly => _addMonthsClamped(start, index),
    };

DateTime _addMonthsClamped(DateTime date, int count) {
  final firstOfTargetMonth = DateTime(date.year, date.month + count, 1,
      date.hour, date.minute, date.second, date.millisecond, date.microsecond);
  final lastDay =
      DateTime(firstOfTargetMonth.year, firstOfTargetMonth.month + 1, 0).day;
  return DateTime(
      firstOfTargetMonth.year,
      firstOfTargetMonth.month,
      date.day.clamp(1, lastDay),
      date.hour,
      date.minute,
      date.second,
      date.millisecond,
      date.microsecond);
}
