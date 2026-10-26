import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../app/providers.dart';
import '../../app/theme/neo_theme.dart';
import '../../core/utils/currency.dart';
import '../../data/savings_transaction.dart';
import '../../shared/neo_components.dart';
import '../../shared/transaction_tile.dart';
import '../budget/budget_page.dart';
import '../goals/goals_page.dart';
import '../simulator/savings_simulator_page.dart';
import '../transactions/add_transaction_sheet.dart';
import '../transactions/transactions_page.dart';
import '../habits/habits_page.dart';

class SavingsHomePage extends ConsumerStatefulWidget {
  const SavingsHomePage({super.key});

  @override
  ConsumerState<SavingsHomePage> createState() => _SavingsHomePageState();
}

class _SavingsHomePageState extends ConsumerState<SavingsHomePage> {
  int _selectedIndex = 0;

  Future<void> _addTransaction(
      {TransactionType type = TransactionType.income, int? goalId}) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) =>
          AddTransactionSheet(initialType: type, initialGoalId: goalId),
    );
  }

  @override
  Widget build(BuildContext context) {
    final palette = NeoPalette.of(context);
    final destinations = [
      const _Destination('Home', Icons.home_outlined, Icons.home_rounded),
      const _Destination(
          'Budget', Icons.pie_chart_outline_rounded, Icons.pie_chart_rounded),
      const _Destination('Goals', Icons.flag_outlined, Icons.flag_rounded),
      const _Destination(
          'Activity', Icons.receipt_long_outlined, Icons.receipt_long_rounded),
      const _Destination('More', Icons.tune_rounded, Icons.tune_rounded),
    ];
    return Scaffold(
      appBar: AppBar(
        titleSpacing: 18,
        title: Row(children: [
          Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                  color: palette.primary,
                  border: Border.all(color: palette.border, width: 2)),
              child: Icon(Icons.bolt_rounded, color: palette.text, size: 21)),
          const SizedBox(width: 9),
          const Text('COLPAD SAVINGS'),
        ]),
        actions: [
          IconButton(
              tooltip: ref.watch(hideBalanceProvider)
                  ? 'Tampilkan saldo'
                  : 'Sembunyikan saldo',
              onPressed: () => ref.read(hideBalanceProvider.notifier).state =
                  !ref.read(hideBalanceProvider),
              icon: Icon(ref.watch(hideBalanceProvider)
                  ? Icons.visibility_off_outlined
                  : Icons.visibility_outlined)),
          IconButton(
              tooltip: 'Ubah tema',
              onPressed: () {
                final current = ref.read(themeModeProvider);
                ref.read(themeModeProvider.notifier).state =
                    current == ThemeMode.dark
                        ? ThemeMode.light
                        : ThemeMode.dark;
              },
              icon: const Icon(Icons.brightness_6_outlined)),
          const SizedBox(width: 5),
        ],
      ),
      body: IndexedStack(index: _selectedIndex, children: [
        DashboardPage(
            onAdd: _addTransaction,
            onOpenTab: (index) => setState(() => _selectedIndex = index)),
        const BudgetPage(),
        GoalsPage(
            onAllocate: (type, goalId) =>
                _addTransaction(type: type, goalId: goalId)),
        const TransactionsPage(),
        _SettingsPage(
            onOpenActivity: () => setState(() => _selectedIndex = 3),
            onOpenHabits: () => Navigator.of(context).push(
                MaterialPageRoute<void>(builder: (_) => const HabitsPage())),
            onOpenSimulator: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                    builder: (context) => const SavingsSimulatorPage()))),
      ]),
      floatingActionButton: _selectedIndex == 0 || _selectedIndex == 3
          ? FloatingActionButton.extended(
              onPressed: () => _addTransaction(),
              icon: const Icon(Icons.add_rounded),
              label: const Text('Catat'),
              backgroundColor: palette.primary,
              foregroundColor: palette.text,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(4),
                  side: BorderSide(color: palette.border, width: 2.5)),
              elevation: 0)
          : null,
      bottomNavigationBar: _NeoNavigationBar(
        destinations: destinations,
        selectedIndex: _selectedIndex,
        onSelect: (index) => setState(() => _selectedIndex = index),
      ),
    );
  }
}

class _Destination {
  const _Destination(this.label, this.icon, this.selectedIcon);
  final String label;
  final IconData icon;
  final IconData selectedIcon;
}

class _NeoNavigationBar extends StatelessWidget {
  const _NeoNavigationBar(
      {required this.destinations,
      required this.selectedIndex,
      required this.onSelect});

  final List<_Destination> destinations;
  final int selectedIndex;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    final palette = NeoPalette.of(context);
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(5, 7, 5, 5),
        decoration: BoxDecoration(
            color: palette.surface,
            border: Border(top: BorderSide(color: palette.border, width: 2.5))),
        child: Row(children: [
          for (var index = 0; index < destinations.length; index++)
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2),
                child: InkWell(
                  onTap: () => onSelect(index),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 120),
                    curve: Curves.easeOut,
                    padding: const EdgeInsets.symmetric(vertical: 7),
                    decoration: BoxDecoration(
                        color: index == selectedIndex
                            ? palette.primary
                            : Colors.transparent,
                        border: Border.all(
                            color: index == selectedIndex
                                ? palette.border
                                : Colors.transparent,
                            width: 2),
                        borderRadius: BorderRadius.circular(3)),
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                      Icon(
                          index == selectedIndex
                              ? destinations[index].selectedIcon
                              : destinations[index].icon,
                          size: 20,
                          color: palette.text),
                      const SizedBox(height: 3),
                      Text(destinations[index].label,
                          maxLines: 1,
                          style: TextStyle(
                              color: palette.text,
                              fontSize: 10,
                              fontWeight: FontWeight.w900)),
                    ]),
                  ),
                ),
              ),
            ),
        ]),
      ),
    );
  }
}

class DashboardPage extends ConsumerWidget {
  const DashboardPage(
      {required this.onAdd, required this.onOpenTab, super.key});

  final Future<void> Function({TransactionType type, int? goalId}) onAdd;
  final ValueChanged<int> onOpenTab;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summary = ref.watch(savingsSummaryProvider);
    final transactions = ref.watch(transactionsProvider);
    final weekly = ref.watch(weeklyActivityProvider);
    final goals = ref.watch(savingGoalsProvider);
    final sources = ref.watch(incomeSourcesProvider);
    final hidden = ref.watch(hideBalanceProvider);
    final palette = NeoPalette.of(context);
    final dateLabel =
        DateFormat('EEEE, d MMMM', 'id_ID').format(DateTime.now());

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(savingsSummaryProvider);
        ref.invalidate(transactionsProvider);
        ref.invalidate(weeklyActivityProvider);
        ref.invalidate(savingGoalsProvider);
        ref.invalidate(incomeSourcesProvider);
        await ref.read(savingsSummaryProvider.future);
      },
      child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
          children: [
            Text('UANGMU, RENCANAMU.',
                style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 3),
            Text(dateLabel, style: TextStyle(color: palette.muted)),
            const SizedBox(height: 14),
            summary.when(
              loading: () => const NeoCard(
                  child: SizedBox(
                      height: 160,
                      child: Center(child: CircularProgressIndicator()))),
              error: (error, stack) => _InlineError(
                  onRetry: () => ref.invalidate(savingsSummaryProvider)),
              data: (value) => _HeroBalance(summary: value, hidden: hidden),
            ),
            const SizedBox(height: 17),
            const NeoSectionTitle('AKSI CEPAT'),
            const SizedBox(height: 9),
            Row(children: [
              Expanded(
                  child: NeoActionButton(
                      icon: Icons.south_west_rounded,
                      label: 'Pemasukan',
                      onPressed: () => onAdd(type: TransactionType.income),
                      color: palette.primary)),
              const SizedBox(width: 7),
              Expanded(
                  child: NeoActionButton(
                      icon: Icons.north_east_rounded,
                      label: 'Pengeluaran',
                      onPressed: () => onAdd(type: TransactionType.expense),
                      color: palette.secondary)),
              const SizedBox(width: 7),
              Expanded(
                  child: NeoActionButton(
                      icon: Icons.flag_outlined,
                      label: 'Target',
                      onPressed: () => onOpenTab(2),
                      color: palette.accent)),
              const SizedBox(width: 7),
              Expanded(
                  child: NeoActionButton(
                      icon: Icons.pie_chart_outline,
                      label: 'Anggaran',
                      onPressed: () => onOpenTab(1),
                      color: palette.highlight)),
            ]),
            const SizedBox(height: 20),
            NeoSectionTitle('RINGKASAN MINGGUAN',
                trailing: NeoTag('7 HARI', color: palette.accent)),
            const SizedBox(height: 9),
            weekly.when(
              loading: () => const NeoCard(
                  child: SizedBox(
                      height: 175,
                      child: Center(child: CircularProgressIndicator()))),
              error: (error, stack) => _InlineError(
                  onRetry: () => ref.invalidate(weeklyActivityProvider)),
              data: (value) => _WeeklyCard(activity: value),
            ),
            const SizedBox(height: 20),
            NeoSectionTitle('TARGET PRIORITAS',
                trailing: TextButton(
                    onPressed: () => onOpenTab(2), child: const Text('Semua'))),
            const SizedBox(height: 8),
            goals.when(
              loading: () => const NeoCard(child: LinearProgressIndicator()),
              error: (error, stack) => _InlineError(
                  onRetry: () => ref.invalidate(savingGoalsProvider)),
              data: (items) => items.isEmpty
                  ? NeoCard(
                      color: palette.accent,
                      child: Row(children: [
                        const Icon(Icons.flag_outlined, size: 27),
                        const SizedBox(width: 12),
                        const Expanded(
                            child: Text(
                                'Belum ada target. Buat tujuan tabungan pertamamu.',
                                style: TextStyle(fontWeight: FontWeight.w800))),
                        TextButton(
                            onPressed: () => onOpenTab(2),
                            child: const Text('Buat'))
                      ]))
                  : _GoalPreview(
                      goal: items.first,
                      onDeposit: () => onAdd(
                          type: TransactionType.deposit,
                          goalId: items.first.id)),
            ),
            const SizedBox(height: 20),
            NeoSectionTitle('SUMBER PEMASUKAN',
                trailing: NeoTag('BULAN INI', color: palette.primary)),
            const SizedBox(height: 8),
            sources.when(
                loading: () => const NeoCard(child: LinearProgressIndicator()),
                error: (error, stack) => _InlineError(
                    onRetry: () => ref.invalidate(incomeSourcesProvider)),
                data: (items) => items.isEmpty
                    ? NeoCard(
                        child: Text(
                            'Belum ada pemasukan yang dicatat bulan ini.',
                            style: TextStyle(color: palette.muted)))
                    : NeoCard(
                        child: Column(children: [
                        for (var index = 0; index < items.length; index++) ...[
                          Row(children: [
                            Expanded(
                                child: Text(items[index].name,
                                    style: const TextStyle(
                                        fontWeight: FontWeight.w800))),
                            Text(
                                hidden
                                    ? '••••••'
                                    : formatRupiah(items[index].amount),
                                style: const TextStyle(
                                    fontWeight: FontWeight.w900))
                          ]),
                          if (index < items.length - 1)
                            const Divider(height: 17),
                        ]
                      ]))),
            const SizedBox(height: 20),
            NeoSectionTitle('TRANSAKSI TERBARU',
                trailing: TextButton(
                    onPressed: () => onOpenTab(3),
                    child: const Text('Lihat semua'))),
            const SizedBox(height: 8),
            transactions.when(
              loading: () => const NeoCard(child: LinearProgressIndicator()),
              error: (error, stack) => _InlineError(
                  onRetry: () => ref.invalidate(transactionsProvider)),
              data: (items) => items.isEmpty
                  ? NeoCard(
                      color: palette.highlight,
                      child: const Text(
                          'Belum ada transaksi. Catat pemasukan atau pengeluaran pertama.',
                          style: TextStyle(fontWeight: FontWeight.w800)))
                  : Column(children: [
                      for (final item in items.take(4))
                        Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: NeoCard(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 9, vertical: 2),
                                child: TransactionTile(
                                    transaction: item, hidden: hidden)))
                    ]),
            ),
            const SizedBox(height: 9),
            Text(
                'Catatan offline di perangkat ini; bukan saldo rekening atau layanan pembayaran.',
                style: TextStyle(color: palette.muted, fontSize: 11)),
          ]),
    );
  }
}

class _HeroBalance extends StatelessWidget {
  const _HeroBalance({required this.summary, required this.hidden});

  final SavingsSummary summary;
  final bool hidden;

  @override
  Widget build(BuildContext context) {
    final palette = NeoPalette.of(context);
    return NeoCard(
      color: palette.primary,
      padding: const EdgeInsets.all(19),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(
              child: Text('TOTAL ASET TERCATAT',
                  style: TextStyle(
                      color: palette.text,
                      fontWeight: FontWeight.w900,
                      fontSize: 12,
                      letterSpacing: .6))),
          const Icon(Icons.bolt_rounded, size: 25)
        ]),
        const SizedBox(height: 7),
        FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(hidden ? '••••••••' : formatRupiah(summary.totalAssets),
                style: Theme.of(context).textTheme.headlineLarge)),
        const SizedBox(height: 14),
        Container(height: 2, color: palette.border),
        const SizedBox(height: 10),
        Row(children: [
          Expanded(
              child: _HeroMetric(
                  label: 'PEMASUKAN',
                  value: hidden ? '••••' : formatRupiah(summary.totalIncome),
                  icon: Icons.south_west_rounded)),
          const SizedBox(width: 12),
          Expanded(
              child: _HeroMetric(
                  label: 'PENGELUARAN',
                  value: hidden ? '••••' : formatRupiah(summary.totalExpense),
                  icon: Icons.north_east_rounded)),
        ]),
        const SizedBox(height: 10),
        Row(children: [
          Expanded(
              child: Text(
                  'Kas ${hidden ? '••••' : formatRupiah(summary.cashBalance)}',
                  style: const TextStyle(
                      fontSize: 11, fontWeight: FontWeight.w800))),
          Text(
              'Dialokasikan ${hidden ? '••••' : formatRupiah(summary.allocatedBalance)}',
              style:
                  const TextStyle(fontSize: 11, fontWeight: FontWeight.w800)),
        ]),
      ]),
    );
  }
}

class _HeroMetric extends StatelessWidget {
  const _HeroMetric(
      {required this.label, required this.value, required this.icon});
  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) => Row(children: [
        Icon(icon, size: 17),
        const SizedBox(width: 6),
        Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label,
              style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w900)),
          FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(value,
                  style: const TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w900)))
        ])),
      ]);
}

class _WeeklyCard extends StatelessWidget {
  const _WeeklyCard({required this.activity});
  final WeeklyFinancialActivity activity;

  @override
  Widget build(BuildContext context) {
    final palette = NeoPalette.of(context);
    final groups = [
      for (var index = 0; index < activity.days.length; index++)
        BarChartGroupData(x: index, barsSpace: 3, barRods: [
          BarChartRodData(
              toY: activity.days[index].deposits.toDouble(),
              color: palette.primary,
              width: 8,
              borderRadius: BorderRadius.zero,
              borderSide: BorderSide(color: palette.border, width: 1)),
          BarChartRodData(
              toY: activity.days[index].expenses.toDouble(),
              color: palette.secondary,
              width: 8,
              borderRadius: BorderRadius.zero,
              borderSide: BorderSide(color: palette.border, width: 1)),
        ])
    ];
    return NeoCard(
        child: Column(children: [
      SizedBox(
          height: 150,
          child: BarChart(BarChartData(
            barGroups: groups,
            gridData: const FlGridData(show: false),
            borderData: FlBorderData(show: false),
            titlesData: FlTitlesData(
              topTitles:
                  const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              rightTitles:
                  const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              leftTitles:
                  const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 25,
                      getTitlesWidget: (value, meta) {
                        final index = value.toInt();
                        if (index < 0 || index >= activity.days.length) {
                          return const SizedBox.shrink();
                        }
                        return Padding(
                            padding: const EdgeInsets.only(top: 5),
                            child: Text(
                                DateFormat('E', 'id_ID')
                                    .format(activity.days[index].date),
                                style: TextStyle(
                                    color: palette.text,
                                    fontSize: 9,
                                    fontWeight: FontWeight.w800)));
                      })),
            ),
          ))),
      const SizedBox(height: 8),
      Row(children: [
        Expanded(
            child: _Legend(
                color: palette.primary,
                label: 'Setoran ${formatRupiah(activity.deposits)}')),
        const SizedBox(width: 8),
        Expanded(
            child: _Legend(
                color: palette.secondary,
                label: 'Keluar ${formatRupiah(activity.expenses)}')),
      ]),
      const SizedBox(height: 6),
      Text(
          'Minggu lalu: setoran ${formatRupiah(activity.previousDeposits)} · keluar ${formatRupiah(activity.previousExpenses)}',
          style: TextStyle(color: palette.muted, fontSize: 10),
          textAlign: TextAlign.center),
    ]));
  }
}

class _Legend extends StatelessWidget {
  const _Legend({required this.color, required this.label});
  final Color color;
  final String label;
  @override
  Widget build(BuildContext context) => Row(children: [
        Container(
            width: 11,
            height: 11,
            decoration: BoxDecoration(
                color: color,
                border: Border.all(
                    color: NeoPalette.of(context).border, width: 1))),
        const SizedBox(width: 5),
        Expanded(
            child: Text(label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style:
                    const TextStyle(fontSize: 10, fontWeight: FontWeight.w800)))
      ]);
}

class _GoalPreview extends StatelessWidget {
  const _GoalPreview({required this.goal, required this.onDeposit});
  final SavingGoal goal;
  final VoidCallback onDeposit;
  @override
  Widget build(BuildContext context) => NeoCard(
      color: NeoPalette.of(context).accent,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(
              child: Text(goal.name,
                  style: Theme.of(context).textTheme.titleMedium)),
          NeoTag('${(goal.progress * 100).round()}%')
        ]),
        const SizedBox(height: 8),
        Text(
            '${formatRupiah(goal.allocatedAmount)} / ${formatRupiah(goal.targetAmount)}',
            style: Theme.of(context).textTheme.bodyLarge),
        const SizedBox(height: 8),
        NeoProgressBar(progress: goal.progress),
        const SizedBox(height: 9),
        Align(
            alignment: Alignment.centerRight,
            child: FilledButton.icon(
                onPressed: onDeposit,
                icon: const Icon(Icons.add),
                label: const Text('Setor'))),
      ]));
}

class _InlineError extends StatelessWidget {
  const _InlineError({required this.onRetry});
  final VoidCallback onRetry;
  @override
  Widget build(BuildContext context) => NeoCard(
      color: NeoPalette.of(context).secondary,
      child: Row(children: [
        const Expanded(
            child: Text('Data gagal dimuat. Coba lagi.',
                style: TextStyle(fontWeight: FontWeight.w800))),
        IconButton(
            tooltip: 'Coba lagi',
            onPressed: onRetry,
            icon: const Icon(Icons.refresh))
      ]));
}

class _SettingsPage extends ConsumerWidget {
  const _SettingsPage(
      {required this.onOpenActivity,
      required this.onOpenSimulator,
      required this.onOpenHabits});
  final VoidCallback onOpenActivity;
  final VoidCallback onOpenSimulator;
  final VoidCallback onOpenHabits;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = NeoPalette.of(context);
    return ListView(
        padding: const EdgeInsets.fromLTRB(18, 12, 18, 100),
        children: [
          Text('Pengaturan', style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 14),
          NeoCard(
              child: Column(children: [
            SwitchListTile(
                title: const Text('Mode gelap',
                    style: TextStyle(fontWeight: FontWeight.w800)),
                value: ref.watch(themeModeProvider) == ThemeMode.dark,
                onChanged: (value) => ref
                    .read(themeModeProvider.notifier)
                    .state = value ? ThemeMode.dark : ThemeMode.light,
                activeThumbColor: palette.primary),
            const Divider(),
            SwitchListTile(
                title: const Text('Sembunyikan nominal',
                    style: TextStyle(fontWeight: FontWeight.w800)),
                value: ref.watch(hideBalanceProvider),
                onChanged: (value) =>
                    ref.read(hideBalanceProvider.notifier).state = value,
                activeThumbColor: palette.primary),
          ])),
          const SizedBox(height: 13),
          NeoCard(
              color: palette.highlight,
              child: const Text(
                  'Colpad Savings adalah pencatat lokal. Aplikasi tidak menyimpan uang dan tidak terhubung ke rekening bank.',
                  style: TextStyle(fontWeight: FontWeight.w800))),
          const SizedBox(height: 13),
          NeoCard(
              child: ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.receipt_long_outlined),
                  title: const Text('Riwayat transaksi'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: onOpenActivity)),
          const SizedBox(height: 13),
          NeoCard(
              child: ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.calculate_outlined),
                  title: const Text('Simulasi tabungan'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: onOpenSimulator)),
          const SizedBox(height: 13),
          NeoCard(
              child: ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.checklist_rounded),
                  title: const Text('Habit tracker'),
                  subtitle: const Text('Kebiasaan dan pengingat menabung'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: onOpenHabits)),
          const SizedBox(height: 13),
          Text('By Colpad ⚡',
              textAlign: TextAlign.center,
              style:
                  TextStyle(color: palette.muted, fontWeight: FontWeight.w900)),
        ]);
  }
}
