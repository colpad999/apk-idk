import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/app_settings_repository.dart';
import '../data/goal_repository.dart';
import '../data/habit_repository.dart';
import '../data/planning_repository.dart';
import '../data/savings_database.dart';
import '../data/savings_transaction.dart';
import '../data/transaction_repository.dart';
import '../services/goal_photo_storage.dart';
import '../services/habit_notification_service.dart';

final savingsDatabaseProvider = Provider<SavingsDatabase>((ref) {
  final database = SavingsDatabase();
  ref.onDispose(database.close);
  return database;
});

final transactionRepositoryProvider = Provider<TransactionRepository>(
    (ref) => TransactionRepository(ref.watch(savingsDatabaseProvider)));
final planningRepositoryProvider = Provider<PlanningRepository>(
    (ref) => PlanningRepository(ref.watch(savingsDatabaseProvider)));
final goalRepositoryProvider = Provider<GoalRepository>(
    (ref) => GoalRepository(ref.watch(savingsDatabaseProvider)));
final appSettingsRepositoryProvider = Provider<AppSettingsRepository>(
    (ref) => AppSettingsRepository(ref.watch(savingsDatabaseProvider)));
final habitRepositoryProvider = Provider<HabitRepository>(
    (ref) => HabitRepository(ref.watch(savingsDatabaseProvider)));

final habitsProvider = FutureProvider<List<Habit>>(
    (ref) => ref.watch(habitRepositoryProvider).list());
final habitProvider = FutureProvider.family<Habit?, int>(
    (ref, id) async {
  // Reuse the dashboard query so completions/edits refresh every open page.
  final habits = await ref.watch(habitsProvider.future);
  for (final habit in habits) {
    if (habit.id == id) return habit;
  }
  return null;
});

final habitNotificationGatewayProvider =
    Provider<HabitNotificationGateway>((ref) => AndroidHabitNotificationGateway());
final habitNotificationServiceProvider =
    Provider<HabitNotificationService>((ref) {
  final service = HabitNotificationService(
    repository: ref.watch(habitRepositoryProvider),
    settings: ref.watch(appSettingsRepositoryProvider),
    gateway: ref.watch(habitNotificationGatewayProvider),
  );
  ref.onDispose(() => service.onHabitSelected = null);
  return service;
});
final habitNotificationsEnabledProvider = FutureProvider<bool>((ref) =>
    ref.watch(appSettingsRepositoryProvider).habitNotificationsEnabled());

final goalPhotoStorageProvider = Provider<GoalPhotoStorage>((ref) {
  final storage = GoalPhotoStorage();
  ref.watch(goalRepositoryProvider); // Keep repository lifetime explicit.
  return storage;
});
final savingGoalsProvider = FutureProvider<List<SavingGoal>>(
    (ref) => ref.watch(goalRepositoryProvider).list());
final savingGoalProvider = FutureProvider.family<SavingGoal?, int>((ref, id) async {
  final goals = await ref.watch(savingGoalsProvider.future);
  for (final goal in goals) {
    if (goal.id == id) return goal;
  }
  return null;
});
final goalAllocationsProvider =
    FutureProvider.family<List<GoalAllocationEntry>, int>((ref, id) async {
  await ref.watch(savingGoalsProvider.future);
  return ref.watch(goalRepositoryProvider).allocations(id);
});

final budgetMonthProvider = StateProvider<DateTime>((ref) {
  final now = DateTime.now();
  return DateTime(now.year, now.month);
});
final budgetsProvider = FutureProvider<List<BudgetLine>>((ref) => ref
    .watch(planningRepositoryProvider)
    .budgetsForMonth(ref.watch(budgetMonthProvider)));
final incomeSourcesProvider = FutureProvider<List<IncomeSourceTotal>>((ref) {
  final now = DateTime.now();
  return ref.watch(planningRepositoryProvider).incomeTotals(
      start: DateTime(now.year, now.month),
      end: DateTime(now.year, now.month + 1));
});
final transactionsProvider = FutureProvider<List<SavingsTransaction>>(
    (ref) => ref.watch(transactionRepositoryProvider).listLatest());
final weeklyActivityProvider = FutureProvider<WeeklyFinancialActivity>((ref) =>
    ref.watch(transactionRepositoryProvider).weeklyActivity(DateTime.now()));
final savingsSummaryProvider = FutureProvider<SavingsSummary>(
    (ref) => ref.watch(transactionRepositoryProvider).summary());

final themeModeProvider = StateProvider<ThemeMode>((ref) => ThemeMode.dark);
final hideBalanceProvider = StateProvider<bool>((ref) => false);
