import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../app/providers.dart';
import '../../core/utils/currency.dart';
import '../../data/savings_transaction.dart';
import '../../shared/transaction_tile.dart';
import '../transactions/add_transaction_sheet.dart';
import '../transactions/transactions_page.dart';

class SavingsHomePage extends ConsumerStatefulWidget {
  const SavingsHomePage({super.key});

  @override
  ConsumerState<SavingsHomePage> createState() => _SavingsHomePageState();
}

class _SavingsHomePageState extends ConsumerState<SavingsHomePage> {
  int _selectedIndex = 0;

  Future<void> _addTransaction() async {
    await showModalBottomSheet<void>(context: context, isScrollControlled: true, useSafeArea: true, builder: (context) => const AddTransactionSheet());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        titleSpacing: 20,
        title: Row(children: [const Icon(Icons.bolt_rounded, color: Color(0xFF40D9B2), size: 25), const SizedBox(width: 8), Text('Colpad Savings', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800))]),
        actions: [
          IconButton(tooltip: ref.watch(hideBalanceProvider) ? 'Tampilkan saldo' : 'Sembunyikan saldo', onPressed: () => ref.read(hideBalanceProvider.notifier).state = !ref.read(hideBalanceProvider), icon: Icon(ref.watch(hideBalanceProvider) ? Icons.visibility_off_outlined : Icons.visibility_outlined)),
          IconButton(tooltip: 'Ubah tema', onPressed: () { final current = ref.read(themeModeProvider); ref.read(themeModeProvider.notifier).state = current == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark; }, icon: const Icon(Icons.brightness_6_outlined)),
          const SizedBox(width: 8),
        ],
      ),
      body: IndexedStack(index: _selectedIndex, children: [DashboardPage(onAddTransaction: _addTransaction, onShowTransactions: () => setState(() => _selectedIndex = 1)), const TransactionsPage()]),
      floatingActionButton: FloatingActionButton.extended(onPressed: _addTransaction, icon: const Icon(Icons.add_rounded), label: const Text('Transaksi')),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (index) => setState(() => _selectedIndex = index),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.space_dashboard_outlined), selectedIcon: Icon(Icons.space_dashboard_rounded), label: 'Ringkasan'),
          NavigationDestination(icon: Icon(Icons.receipt_long_outlined), selectedIcon: Icon(Icons.receipt_long_rounded), label: 'Transaksi'),
        ],
      ),
    );
  }
}

class DashboardPage extends ConsumerWidget {
  const DashboardPage({required this.onAddTransaction, required this.onShowTransactions, super.key});

  final VoidCallback onAddTransaction;
  final VoidCallback onShowTransactions;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summary = ref.watch(savingsSummaryProvider);
    final transactions = ref.watch(transactionsProvider);
    final hidden = ref.watch(hideBalanceProvider);
    final colors = Theme.of(context).colorScheme;
    return RefreshIndicator(
      onRefresh: () async { ref.invalidate(savingsSummaryProvider); ref.invalidate(transactionsProvider); await ref.read(savingsSummaryProvider.future); },
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 100),
        children: [
          Text('Keuanganmu, lebih terarah.', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800)),
          const SizedBox(height: 5),
          Text(DateFormat('EEEE, d MMMM yyyy', 'id_ID').format(DateTime.now()), style: TextStyle(color: colors.onSurfaceVariant)),
          const SizedBox(height: 20),
          summary.when(loading: () => const _SummaryLoading(), error: (error, stack) => _ErrorPanel(onRetry: () => ref.invalidate(savingsSummaryProvider)), data: (value) => _BalanceCard(summary: value, hidden: hidden)),
          const SizedBox(height: 14),
          summary.when(
            loading: () => const SizedBox(height: 90),
            error: (error, stack) => const SizedBox.shrink(),
            data: (value) => Row(children: [
              Expanded(child: _MetricTile(label: 'Uang masuk', amount: value.totalIncome, icon: Icons.south_west_rounded, color: const Color(0xFF41D7AE), hidden: hidden)),
              const SizedBox(width: 10),
              Expanded(child: _MetricTile(label: 'Uang keluar', amount: value.totalExpense, icon: Icons.north_east_rounded, color: const Color(0xFFFF8B78), hidden: hidden)),
            ]),
          ),
          const SizedBox(height: 23),
          Row(children: [Expanded(child: Text('Perkembangan aset', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800))), Text('Transaksi terbaru', style: Theme.of(context).textTheme.labelSmall?.copyWith(color: colors.onSurfaceVariant))]),
          const SizedBox(height: 11),
          transactions.when(loading: () => const _ChartCard(child: Center(child: CircularProgressIndicator())), error: (error, stack) => _ErrorPanel(onRetry: () => ref.invalidate(transactionsProvider)), data: (items) => _ChartCard(child: _AssetChart(transactions: items, totalAssets: summary.valueOrNull?.totalAssets ?? 0))),
          const SizedBox(height: 23),
          Row(children: [Expanded(child: Text('Transaksi terakhir', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800))), TextButton(onPressed: onShowTransactions, child: const Text('Lihat semua'))]),
          transactions.when(
            loading: () => const Padding(padding: EdgeInsets.all(20), child: Center(child: CircularProgressIndicator())),
            error: (error, stack) => _ErrorPanel(onRetry: () => ref.invalidate(transactionsProvider)),
            data: (items) => items.isEmpty ? _EmptyTransactions(onAdd: onAddTransaction) : Column(children: items.take(4).map((item) => TransactionTile(transaction: item, hidden: hidden)).toList()),
          ),
          const SizedBox(height: 22),
          _GoalPreview(),
        ],
      ),
    );
  }
}

class _BalanceCard extends StatelessWidget {
  const _BalanceCard({required this.summary, required this.hidden});
  final SavingsSummary summary;
  final bool hidden;

  @override
  Widget build(BuildContext context) {
    final amount = hidden ? '••••••••' : formatRupiah(summary.totalAssets);
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(24), gradient: const LinearGradient(colors: [Color(0xFF0C685E), Color(0xFF123A40)], begin: Alignment.topLeft, end: Alignment.bottomRight), border: Border.all(color: Colors.white.withValues(alpha: .12))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('TOTAL ASET TERCATAT', style: Theme.of(context).textTheme.labelMedium?.copyWith(color: Colors.white.withValues(alpha: .72), letterSpacing: 1.1, fontWeight: FontWeight.w700)),
        const SizedBox(height: 9),
        FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerLeft, child: Text(amount, style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.w800))),
        const SizedBox(height: 20),
        Row(children: [Expanded(child: _BalancePart(label: 'Saldo kas', amount: hidden ? '••••' : formatRupiah(summary.cashBalance))), Container(width: 1, height: 38, color: Colors.white24), Expanded(child: _BalancePart(label: 'Dialokasikan', amount: hidden ? '••••' : formatRupiah(summary.allocatedBalance)))]),
        const SizedBox(height: 13),
        Text('Saldo tercatat di perangkat ini, bukan rekening uang sungguhan.', style: TextStyle(color: Colors.white.withValues(alpha: .72), fontSize: 11)),
      ]),
    );
  }
}

class _BalancePart extends StatelessWidget {
  const _BalancePart({required this.label, required this.amount});
  final String label;
  final String amount;
  @override
  Widget build(BuildContext context) => Padding(padding: const EdgeInsets.symmetric(horizontal: 10), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(label, style: TextStyle(color: Colors.white.withValues(alpha: .68), fontSize: 11)), const SizedBox(height: 3), FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerLeft, child: Text(amount, style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w700)))]));
}

class _MetricTile extends StatelessWidget {
  const _MetricTile({required this.label, required this.amount, required this.icon, required this.color, required this.hidden});
  final String label;
  final int amount;
  final IconData icon;
  final Color color;
  final bool hidden;
  @override
  Widget build(BuildContext context) => Container(padding: const EdgeInsets.all(14), decoration: BoxDecoration(color: Theme.of(context).colorScheme.surfaceContainerLow, borderRadius: BorderRadius.circular(18)), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Icon(icon, color: color, size: 19), const SizedBox(height: 10), Text(label, style: Theme.of(context).textTheme.labelMedium?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant)), const SizedBox(height: 3), FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerLeft, child: Text(hidden ? '••••••' : formatRupiah(amount), style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800)))]));
}

class _ChartCard extends StatelessWidget {
  const _ChartCard({required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) => Container(height: 190, padding: const EdgeInsets.fromLTRB(12, 16, 18, 10), decoration: BoxDecoration(color: Theme.of(context).colorScheme.surfaceContainerLow, borderRadius: BorderRadius.circular(20)), child: child);
}

class _AssetChart extends StatelessWidget {
  const _AssetChart({required this.transactions, required this.totalAssets});
  final List<SavingsTransaction> transactions;
  final int totalAssets;

  @override
  Widget build(BuildContext context) {
    if (transactions.isEmpty) return Center(child: Text('Grafik akan muncul setelah transaksi dicatat.', style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant), textAlign: TextAlign.center));
    final ordered = transactions.reversed.toList();
    final recentNetChange = ordered.fold<int>(0, (sum, item) { if (item.type == TransactionType.income) return sum + item.amount; if (item.type == TransactionType.expense) return sum - item.amount; return sum; });
    var balance = totalAssets - recentNetChange;
    final spots = <FlSpot>[FlSpot(0, balance.toDouble())];
    for (var index = 0; index < ordered.length; index++) {
      final item = ordered[index];
      if (item.type == TransactionType.income) balance += item.amount;
      if (item.type == TransactionType.expense) balance -= item.amount;
      spots.add(FlSpot((index + 1).toDouble(), balance.toDouble()));
    }
    final low = spots.map((spot) => spot.y).reduce((a, b) => math.min(a, b).toDouble());
    final high = spots.map((spot) => spot.y).reduce((a, b) => math.max(a, b).toDouble());
    final padding = math.max((high - low) * .18, 1000).toDouble();
    final accent = Theme.of(context).colorScheme.primary;
    return LineChart(LineChartData(
      minX: 0,
      maxX: math.max(1, spots.length - 1).toDouble(),
      minY: math.max(0.0, low - padding).toDouble(),
      maxY: high + padding,
      gridData: const FlGridData(show: false),
      borderData: FlBorderData(show: false),
      titlesData: const FlTitlesData(show: false),
      lineTouchData: const LineTouchData(enabled: false),
      lineBarsData: [LineChartBarData(spots: spots, isCurved: true, color: accent, barWidth: 3, dotData: const FlDotData(show: false), belowBarData: BarAreaData(show: true, color: accent.withValues(alpha: .13)))],
    ));
  }
}

class _EmptyTransactions extends StatelessWidget {
  const _EmptyTransactions({required this.onAdd});
  final VoidCallback onAdd;
  @override
  Widget build(BuildContext context) => Container(padding: const EdgeInsets.all(20), decoration: BoxDecoration(color: Theme.of(context).colorScheme.surfaceContainerLow, borderRadius: BorderRadius.circular(18)), child: Column(children: [const Icon(Icons.savings_outlined, size: 31, color: Color(0xFF42CFA7)), const SizedBox(height: 8), const Text('Belum ada transaksi', style: TextStyle(fontWeight: FontWeight.w700)), const SizedBox(height: 4), Text('Catat uang masuk atau pengeluaran pertamamu.', style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant), textAlign: TextAlign.center), const SizedBox(height: 10), TextButton.icon(onPressed: onAdd, icon: const Icon(Icons.add), label: const Text('Catat transaksi'))]));
}

class _GoalPreview extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Container(padding: const EdgeInsets.all(18), decoration: BoxDecoration(border: Border.all(color: Theme.of(context).colorScheme.outlineVariant), borderRadius: const BorderRadius.all(Radius.circular(18))), child: const Row(children: [Icon(Icons.flag_outlined, color: Color(0xFF48CFA7)), SizedBox(width: 12), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('Target tabungan', style: TextStyle(fontWeight: FontWeight.w700)), SizedBox(height: 3), Text('Manajemen target menyusul pada tahap berikutnya.', style: TextStyle(fontSize: 12))]))]));
}

class _SummaryLoading extends StatelessWidget {
  const _SummaryLoading();
  @override
  Widget build(BuildContext context) => const _ChartCard(child: Center(child: CircularProgressIndicator()));
}

class _ErrorPanel extends StatelessWidget {
  const _ErrorPanel({required this.onRetry});
  final VoidCallback onRetry;
  @override
  Widget build(BuildContext context) => Container(padding: const EdgeInsets.all(15), decoration: BoxDecoration(color: Theme.of(context).colorScheme.errorContainer, borderRadius: BorderRadius.circular(16)), child: Row(children: [const Expanded(child: Text('Data belum dapat dimuat. Coba lagi.')), TextButton(onPressed: onRetry, child: const Text('Ulangi'))]));
}