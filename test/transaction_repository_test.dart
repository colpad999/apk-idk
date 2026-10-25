import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:apk_idk/data/savings_database.dart';
import 'package:apk_idk/data/savings_transaction.dart';
import 'package:apk_idk/data/goal_repository.dart';
import 'package:apk_idk/data/planning_repository.dart';
import 'package:apk_idk/data/transaction_repository.dart';

void main() {
  late SavingsDatabase database;
  late TransactionRepository repository;

  setUp(() {
    database = SavingsDatabase.forTesting(NativeDatabase.memory());
    repository = TransactionRepository(database);
  });

  tearDown(() async => database.close());

  test('cash, allocation, and assets remain consistent', () async {
    await repository.add(
        type: TransactionType.income,
        amount: 100000,
        category: 'Gaji',
        createdAt: DateTime(2026, 1, 1));
    await repository.add(
        type: TransactionType.expense,
        amount: 15000,
        category: 'Makan',
        createdAt: DateTime(2026, 1, 2));
    await repository.add(
        type: TransactionType.deposit,
        amount: 25000,
        category: 'Tabungan',
        createdAt: DateTime(2026, 1, 3));

    var summary = await repository.summary();
    expect(summary.cashBalance, 60000);
    expect(summary.allocatedBalance, 25000);
    expect(summary.totalAssets, 85000);

    await repository.add(
        type: TransactionType.withdrawal,
        amount: 5000,
        category: 'Tarik tabungan',
        createdAt: DateTime(2026, 1, 4));
    summary = await repository.summary();
    expect(summary.cashBalance, 65000);
    expect(summary.allocatedBalance, 20000);
    expect(summary.totalAssets, 85000);
  });

  test('rejects non-positive amount and spending beyond available balance',
      () async {
    await expectLater(
      repository.add(
          type: TransactionType.income,
          amount: 0,
          category: 'Gaji',
          createdAt: DateTime.now()),
      throwsArgumentError,
    );
    await repository.add(
        type: TransactionType.income,
        amount: 10000,
        category: 'Gaji',
        createdAt: DateTime.now());

    await expectLater(
      repository.add(
          type: TransactionType.expense,
          amount: 10001,
          category: 'Belanja',
          createdAt: DateTime.now()),
      throwsStateError,
    );
    await expectLater(
      repository.add(
          type: TransactionType.withdrawal,
          amount: 1,
          category: 'Tarik',
          createdAt: DateTime.now()),
      throwsStateError,
    );
    expect((await repository.listLatest()).length, 1);
  });

  test(
      'goal allocations are tied to transactions and do not change total assets',
      () async {
    final goals = GoalRepository(database);
    await repository.add(
        type: TransactionType.income,
        amount: 50000,
        category: 'Gaji',
        createdAt: DateTime(2026, 2, 1));
    final goalId =
        await goals.create(name: 'Dana darurat', targetAmount: 40000);
    await repository.add(
        type: TransactionType.deposit,
        amount: 15000,
        category: 'Tabungan',
        createdAt: DateTime(2026, 2, 2),
        goalId: goalId);
    await repository.add(
        type: TransactionType.expense,
        amount: 5000,
        category: 'Makanan',
        createdAt: DateTime(2026, 2, 3));

    var summary = await repository.summary();
    expect(summary.totalAssets, 45000);
    expect((await goals.list()).single.allocatedAmount, 15000);
    await expectLater(
      repository.add(
          type: TransactionType.withdrawal,
          amount: 16000,
          category: 'Penarikan',
          createdAt: DateTime(2026, 2, 4),
          goalId: goalId),
      throwsStateError,
    );
    await repository.add(
        type: TransactionType.withdrawal,
        amount: 5000,
        category: 'Penarikan',
        createdAt: DateTime(2026, 2, 4),
        goalId: goalId);
    summary = await repository.summary();
    expect(summary.totalAssets, 45000);
    expect((await goals.list()).single.allocatedAmount, 10000);
  });

  test(
      'monthly budgets count matching expenses and income is grouped by source',
      () async {
    final planning = PlanningRepository(database);
    await repository.add(
        type: TransactionType.income,
        amount: 100000,
        category: 'Proyek',
        createdAt: DateTime(2026, 3, 2));
    await repository.add(
        type: TransactionType.expense,
        amount: 20000,
        category: 'Makanan',
        createdAt: DateTime(2026, 3, 3));
    await repository.add(
        type: TransactionType.expense,
        amount: 10000,
        category: 'Transportasi',
        createdAt: DateTime(2026, 3, 4));
    await planning.setBudget(
        category: 'Makanan', month: DateTime(2026, 3), limit: 30000);

    final budgets = await planning.budgetsForMonth(DateTime(2026, 3));
    final food = budgets.singleWhere((line) => line.category == 'Makanan');
    expect(food.limit, 30000);
    expect(food.spent, 20000);
    expect(food.remaining, 10000);
    expect(food.progress, closeTo(2 / 3, .001));

    final income = await planning.incomeTotals(
        start: DateTime(2026, 3), end: DateTime(2026, 4));
    expect(income.single.name, 'Proyek');
    expect(income.single.amount, 100000);
    expect((await planning.knownIncomeSources()), contains('Proyek'));
  });
}
