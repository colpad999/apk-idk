import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/savings_database.dart';
import '../data/planning_repository.dart';
import '../data/goal_repository.dart';
import '../data/savings_transaction.dart';
import '../data/transaction_repository.dart';
import '../data/habit_repository.dart';

final savingsDatabaseProvider = Provider<SavingsDatabase>((ref) {
  final database = SavingsDatabase();
  ref.onDispose(database.close);
  return database;
});

final transactionRepositoryProvider = Provider<TransactionRepository>((ref) {
  return TransactionRepository(ref.watch(savingsDatabaseProvider));
});

final planningRepositoryProvider = Provider<PlanningRepository>((ref) {
  return PlanningRepository(ref.watch(savingsDatabaseProvider));
});

final goalRepositoryProvider = Provider<GoalRepository>((ref) {
  return GoalRepository(ref.watch(savingsDatabaseProvider));
});
final habitRepositoryProvider = Provider<HabitRepository>(
    (ref) => HabitRepository(ref.watch(savingsDatabaseProvider)));
final habitsProvider = FutureProvider<List<Habit>>(
    (ref) => ref.watch(habitRepositoryProvider).list());

final savingGoalsProvider = FutureProvider((ref) {
  return ref.watch(goalRepositoryProvider).list();
});

final budgetMonthProvider = StateProvider<DateTime>((ref) {
  final now = DateTime.now();
  return DateTime(now.year, now.month);
});

final budgetsProvider = FutureProvider((ref) {
  return ref
      .watch(planningRepositoryProvider)
      .budgetsForMonth(ref.watch(budgetMonthProvider));
});

final incomeSourcesProvider = FutureProvider((ref) {
  final now = DateTime.now();
  return ref.watch(planningRepositoryProvider).incomeTotals(
      start: DateTime(now.year, now.month),
      end: DateTime(now.year, now.month + 1));
});

final transactionsProvider = FutureProvider<List<SavingsTransaction>>((ref) {
  return ref.watch(transactionRepositoryProvider).listLatest();
});

final weeklyActivityProvider = FutureProvider<WeeklyFinancialActivity>((ref) {
  return ref
      .watch(transactionRepositoryProvider)
      .weeklyActivity(DateTime.now());
});

final savingsSummaryProvider = FutureProvider<SavingsSummary>((ref) {
  return ref.watch(transactionRepositoryProvider).summary();
});

final themeModeProvider = StateProvider<ThemeMode>((ref) => ThemeMode.dark);
final hideBalanceProvider = StateProvider<bool>((ref) => false);
