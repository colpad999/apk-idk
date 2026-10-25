import 'package:flutter_test/flutter_test.dart';
import 'package:apk_idk/features/simulator/savings_simulator.dart';

void main() {
  test(
      'daily simulation estimates target date from confirmed contribution plan',
      () {
    final projection = simulateSavings(
      startingBalance: 1000,
      contribution: 1000,
      frequency: SavingFrequency.daily,
      target: 5000,
      months: 1,
      startDate: DateTime(2026, 1, 1),
    );

    expect(projection.reachedAt, DateTime(2026, 1, 5));
    expect(projection.totalContributions, 31000);
    expect(projection.endingBalance, 32000);
  });

  test('monthly contributions stay anchored to original day at month ends', () {
    final projection = simulateSavings(
      startingBalance: 0,
      contribution: 10000,
      frequency: SavingFrequency.monthly,
      target: 30000,
      months: 3,
      startDate: DateTime(2026, 1, 31),
    );

    expect(projection.totalContributions, 30000);
    expect(projection.points.map((point) => point.date), [
      DateTime(2026, 1, 31),
      DateTime(2026, 2, 28),
      DateTime(2026, 3, 31),
      DateTime(2026, 4, 30)
    ]);
    expect(projection.reachedAt, DateTime(2026, 4, 30));
  });

  test('rejects invalid plans and marks already reached targets', () {
    expect(
        () => simulateSavings(
            startingBalance: -1,
            contribution: 1000,
            frequency: SavingFrequency.weekly,
            target: 5000,
            months: 2),
        throwsArgumentError);
    expect(
        () => simulateSavings(
            startingBalance: 0,
            contribution: 0,
            frequency: SavingFrequency.weekly,
            target: 5000,
            months: 2),
        throwsArgumentError);

    final projection = simulateSavings(
        startingBalance: 5000,
        contribution: 1000,
        frequency: SavingFrequency.weekly,
        target: 5000,
        months: 1,
        startDate: DateTime(2026, 1, 1));
    expect(projection.reachedAt, DateTime(2026, 1, 1));
  });
}
