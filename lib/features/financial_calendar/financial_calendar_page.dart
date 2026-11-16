import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../app/providers.dart';
import '../../app/theme/neo_theme.dart';
import '../../core/utils/civil_date.dart';
import '../../core/utils/currency.dart';
import '../../data/habit.dart';
import '../../data/savings_transaction.dart';
import '../../shared/neo_components.dart';
import '../../shared/transaction_tile.dart';

class FinancialCalendarPage extends ConsumerStatefulWidget {
  const FinancialCalendarPage({super.key});
  @override
  ConsumerState<FinancialCalendarPage> createState() => _FinancialCalendarPageState();
}

class _FinancialCalendarPageState extends ConsumerState<FinancialCalendarPage> {
  late DateTime month, selected;
  @override
  void initState() { super.initState(); final now = DateTime.now(); month = DateTime(now.year, now.month); selected = DateTime(now.year, now.month, now.day); }
  void changeMonth(int delta) => setState(() { month = DateTime(month.year, month.month + delta); selected = month; });
  @override
  Widget build(BuildContext context) {
    final data = ref.watch(financialMonthProvider(month));
    final p = NeoPalette.of(context);
    final hidden = ref.watch(hideBalanceProvider);
    return Scaffold(appBar: AppBar(title: const Text('KALENDER KEUANGAN')),
      body: data.when(loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, __) => NeoErrorCard(onRetry: () => ref.invalidate(financialMonthProvider(month))),
        data: (transactions) {
          final dates = <String, List<SavingsTransaction>>{};
          var income = 0, expense = 0;
          for (final transaction in transactions) {
            dates.putIfAbsent(CivilDate.dateKey(transaction.createdAt), () => []).add(transaction);
            if (transaction.type == TransactionType.income) income += transaction.amount;
            if (transaction.type == TransactionType.expense) expense += transaction.amount;
          }
          final dayItems = dates[CivilDate.dateKey(selected)] ?? [];
          final leading = month.weekday - 1;
          final days = DateTime(month.year, month.month + 1, 0).day;
          final cells = ((leading + days) / 7).ceil() * 7;
          return ListView(padding: const EdgeInsets.fromLTRB(16, 12, 16, 30), children: [
            NeoCard(child: Column(children: [
              Row(children: [
                IconButton(tooltip: 'Bulan sebelumnya', onPressed: () => changeMonth(-1), icon: const Icon(Icons.chevron_left)),
                Expanded(child: Text(DateFormat('MMMM yyyy', 'id_ID').format(month), textAlign: TextAlign.center, style: Theme.of(context).textTheme.titleMedium)),
                IconButton(tooltip: 'Bulan berikutnya', onPressed: () => changeMonth(1), icon: const Icon(Icons.chevron_right)),
              ]),
              Row(children: [for (final day in weekdayLabels) Expanded(child: Text(day, textAlign: TextAlign.center, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800)))]),
              const SizedBox(height: 8),
              GridView.builder(shrinkWrap: true, physics: const NeverScrollableScrollPhysics(), itemCount: cells,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 7),
                itemBuilder: (context, index) {
                  final number = index - leading + 1;
                  if (number < 1 || number > days) { return const SizedBox.shrink(); }
                  final date = DateTime(month.year, month.month, number);
                  final marked = dates.containsKey(CivilDate.dateKey(date));
                  final current = CivilDate.dateKey(date) == CivilDate.dateKey(selected);
                  return Padding(padding: const EdgeInsets.all(2), child: Material(color: marked ? p.accent : p.surface,
                    shape: RoundedRectangleBorder(side: BorderSide(color: p.border, width: current ? 3 : 1), borderRadius: BorderRadius.circular(4)),
                    child: InkWell(onTap: () => setState(() => selected = date), child: Semantics(label: '${DateFormat('d MMMM yyyy', 'id_ID').format(date)}, ${marked ? 'ada transaksi' : 'tanpa transaksi'}', child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Text('$number', style: const TextStyle(fontWeight: FontWeight.w800)), if (marked) const Icon(Icons.circle, size: 5)])))));
                }),
            ])),
            const SizedBox(height: 14),
            NeoCard(color: p.highlight, child: Text('Bulan ini · Pemasukan ${hidden ? '••••' : formatRupiah(income)} · Pengeluaran ${hidden ? '••••' : formatRupiah(expense)}\nSetoran dan penarikan adalah perpindahan internal, bukan pemasukan atau pengeluaran.', style: const TextStyle(fontWeight: FontWeight.w700))),
            const SizedBox(height: 16),
            NeoSectionTitle(DateFormat('d MMMM yyyy', 'id_ID').format(selected)),
            const SizedBox(height: 8),
            if (dayItems.isEmpty) const NeoCard(child: Text('Tidak ada transaksi pada tanggal ini.')),
            for (final item in dayItems) NeoCard(shadow: false, child: TransactionTile(transaction: item, hidden: hidden)),
          ]);
        }));
  }
}
