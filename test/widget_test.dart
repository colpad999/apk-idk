import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:apk_idk/app/colpad_app.dart';
import 'package:apk_idk/app/providers.dart';
import 'package:apk_idk/data/savings_transaction.dart';

void main() {
  setUpAll(() async => initializeDateFormatting('id_ID'));

  testWidgets('dashboard shows empty database and supports balance privacy', (tester) async {
    await tester.pumpWidget(ProviderScope(
      overrides: [
        savingsSummaryProvider.overrideWith((ref) async => const SavingsSummary(cashBalance: 0, allocatedBalance: 0, totalIncome: 0, totalExpense: 0)),
        transactionsProvider.overrideWith((ref) async => const <SavingsTransaction>[]),
      ],
      child: const ColpadApp(),
    ));
    await tester.pumpAndSettle();

    expect(find.text('Colpad Savings'), findsOneWidget);
    expect(find.text('TOTAL ASET TERCATAT'), findsOneWidget);

    await tester.tap(find.byTooltip('Sembunyikan saldo'));
    await tester.pumpAndSettle();
    expect(find.text('••••••••'), findsOneWidget);

    await tester.scrollUntilVisible(find.text('Belum ada transaksi'), 300);
    expect(find.text('Belum ada transaksi'), findsOneWidget);
  });
}
