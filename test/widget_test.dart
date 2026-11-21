import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:drift/native.dart';
import 'package:apk_idk/data/savings_database.dart';
import 'support/fake_notification_gateway.dart';
import 'package:apk_idk/app/colpad_app.dart';
import 'package:apk_idk/app/theme/neo_theme.dart';
import 'package:apk_idk/shared/neo_components.dart';
import 'package:apk_idk/app/providers.dart';
import 'package:apk_idk/data/planning_repository.dart';
import 'package:apk_idk/data/savings_transaction.dart';

void main() {
  setUpAll(() async => initializeDateFormatting('id_ID'));

  testWidgets('dashboard shows empty database and supports balance privacy',
      (tester) async {
    await tester.pumpWidget(ProviderScope(
      overrides: [
        savingsDatabaseProvider.overrideWith((ref) {
          final db = SavingsDatabase.forTesting(NativeDatabase.memory());
          ref.onDispose(db.close);
          return db;
        }),
        habitNotificationGatewayProvider.overrideWith((ref) => FakeHabitNotificationGateway()),
        savingsSummaryProvider.overrideWith((ref) async => const SavingsSummary(
            cashBalance: 0,
            allocatedBalance: 0,
            totalIncome: 0,
            totalExpense: 0)),
        transactionsProvider
            .overrideWith((ref) async => const <SavingsTransaction>[]),
        budgetsProvider.overrideWith((ref) async => const <BudgetLine>[]),
        savingGoalsProvider.overrideWith((ref) async => const <SavingGoal>[]),
        incomeSourcesProvider
            .overrideWith((ref) async => const <IncomeSourceTotal>[]),
        weeklyActivityProvider
            .overrideWith((ref) async => WeeklyFinancialActivity(
                  days: [
                    for (var day = 0; day < 7; day++)
                      DailyFinancialActivity(
                          date: DateTime(2026, 1, day + 1),
                          deposits: 0,
                          expenses: 0)
                  ],
                  previousDeposits: 0,
                  previousExpenses: 0,
                )),
      ],
      child: const ColpadApp(),
    ));
    await tester.pumpAndSettle();

    expect(find.text('COLPAD SAVINGS'), findsOneWidget);
    expect(find.text('TOTAL ASET TERCATAT'), findsOneWidget);

    await tester.tap(find.byTooltip('Sembunyikan saldo'));
    await tester.pumpAndSettle();
    expect(find.text('••••••••'), findsOneWidget);

    await tester.scrollUntilVisible(
        find.textContaining('Belum ada transaksi'), 300);
    expect(find.textContaining('Belum ada transaksi'), findsOneWidget);
  });

  testWidgets('primary navigation opens budget, goals, and settings',
      (tester) async {
    await tester.pumpWidget(ProviderScope(
      overrides: [
        savingsDatabaseProvider.overrideWith((ref) {
          final db = SavingsDatabase.forTesting(NativeDatabase.memory());
          ref.onDispose(db.close);
          return db;
        }),
        habitNotificationGatewayProvider.overrideWith((ref) => FakeHabitNotificationGateway()),
        savingsSummaryProvider.overrideWith((ref) async => const SavingsSummary(
            cashBalance: 0,
            allocatedBalance: 0,
            totalIncome: 0,
            totalExpense: 0)),
        transactionsProvider
            .overrideWith((ref) async => const <SavingsTransaction>[]),
        budgetsProvider.overrideWith((ref) async => const <BudgetLine>[]),
        savingGoalsProvider.overrideWith((ref) async => const <SavingGoal>[]),
        incomeSourcesProvider
            .overrideWith((ref) async => const <IncomeSourceTotal>[]),
        weeklyActivityProvider.overrideWith((ref) async =>
            const WeeklyFinancialActivity(
                days: [], previousDeposits: 0, previousExpenses: 0)),
      ],
      child: const ColpadApp(),
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Savings'));
    await tester.pumpAndSettle();
    expect(find.text('Target tabungan'), findsOneWidget);
    await tester.tap(find.text('Statistics'));
    await tester.pumpAndSettle();
    expect(find.text('STATISTICS ⚡'), findsOneWidget);
    await tester.tap(find.text('More'));
    await tester.pumpAndSettle();
    expect(find.text('Pengaturan'), findsOneWidget);
    expect(find.text('Mode gelap'), findsNothing);
    expect(Theme.of(tester.element(find.text('Pengaturan'))).brightness, Brightness.light);
    expect(find.text('Sembunyikan nominal'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('Neo Purple'), 200);
    await Scrollable.ensureVisible(tester.element(find.text('Neo Purple')), alignment: 0.4);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Neo Purple'));
    await tester.pumpAndSettle();
    expect(NeoPalette.of(tester.element(find.text('Neo Purple'))).background, NeoPalette.purple.background);
    expect(find.byType(NeoGridBackground), findsOneWidget);
    await tester.scrollUntilVisible(find.text('Cari di pusat fitur'), -200);
    await tester.tap(find.text('Cari di pusat fitur'));
    await tester.pumpAndSettle();
    expect(find.text('PUSAT FITUR'), findsOneWidget);
    await tester.enterText(find.byType(TextField).last, 'alarm manual');
    await tester.pumpAndSettle();
    expect(find.text('Alarm manual stop'), findsOneWidget);
    expect(find.text('Belum tersedia'), findsNothing);
  });
  testWidgets('small screens keep navigation, goal cards and privacy usable', (tester) async {
    tester.view.physicalSize = const Size(320, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(ProviderScope(overrides: [
      savingsDatabaseProvider.overrideWith((ref) {
        final db = SavingsDatabase.forTesting(NativeDatabase.memory());
        ref.onDispose(db.close);
        return db;
      }),
      habitNotificationGatewayProvider.overrideWith((ref) => FakeHabitNotificationGateway()),
      savingsSummaryProvider.overrideWith((ref) async => const SavingsSummary(cashBalance: 100000, allocatedBalance: 50000, totalIncome: 200000, totalExpense: 50000)),
      transactionsProvider.overrideWith((ref) async => const <SavingsTransaction>[]),
      budgetsProvider.overrideWith((ref) async => const <BudgetLine>[]),
      savingGoalsProvider.overrideWith((ref) async => [SavingGoal(id: 1, name: 'Laptop untuk sekolah dan bekerja', targetAmount: 9000000, allocatedAmount: 50000, createdAt: DateTime(2026))]),
      incomeSourcesProvider.overrideWith((ref) async => const <IncomeSourceTotal>[]),
      weeklyActivityProvider.overrideWith((ref) async => const WeeklyFinancialActivity(days: [], previousDeposits: 0, previousExpenses: 0)),
    ], child: const ColpadApp()));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('TARGET PRIORITAS'), 300);
    await tester.pumpAndSettle();
    expect(find.text('Laptop untuk sekolah dan bekerja'), findsWidgets);
    await tester.tap(find.text('Savings'));
    await tester.pumpAndSettle();
    expect(find.text('Target tabungan'), findsOneWidget);
    await tester.tap(find.text('More'));
    await tester.pumpAndSettle();
    expect(find.text('Mode gelap'), findsNothing);
  });

}
