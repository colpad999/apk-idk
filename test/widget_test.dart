import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:apk_idk/app/colpad_app.dart';
import 'package:apk_idk/app/providers.dart';
import 'package:apk_idk/data/planning_repository.dart';
import 'package:apk_idk/data/savings_transaction.dart';

void main() {
  setUpAll(() async => initializeDateFormatting('id_ID'));

  testWidgets('dashboard shows empty database and supports balance privacy',
      (tester) async {
    await tester.pumpWidget(ProviderScope(
      overrides: [
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

    await tester.tap(find.text('Budget'));
    await tester.pumpAndSettle();
    expect(find.text('Anggaran'), findsOneWidget);

    await tester.tap(find.text('Goals'));
    await tester.pumpAndSettle();
    expect(find.text('Target tabungan'), findsOneWidget);

    await tester.tap(find.text('More'));
    await tester.pumpAndSettle();
    expect(find.text('Pengaturan'), findsOneWidget);
  });
}
