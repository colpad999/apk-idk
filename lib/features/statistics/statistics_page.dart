import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../app/theme/neo_theme.dart';
import '../../core/utils/currency.dart';
import '../../shared/neo_components.dart';

/// Displays existing aggregates only; no estimates or invented insights.
class StatisticsPage extends ConsumerWidget {
  const StatisticsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = NeoPalette.of(context);
    final hidden = ref.watch(hideBalanceProvider);
    String money(int value) => hidden ? '••••••' : formatRupiah(value);
    return ListView(padding: const EdgeInsets.fromLTRB(18, 12, 18, 115), children: [
      Text('STATISTICS ⚡', style: Theme.of(context).textTheme.headlineLarge),
      const SizedBox(height: 6),
      Text('Ringkasan dari catatan yang tersimpan.', style: TextStyle(color: p.muted)),
      const SizedBox(height: 18),
      const NeoSectionTitle('PEMASUKAN VS PENGELUARAN'),
      const SizedBox(height: 10),
      ref.watch(savingsSummaryProvider).when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, __) => NeoErrorCard(onRetry: () => ref.invalidate(savingsSummaryProvider)),
        data: (summary) => NeoCard(color: p.primary, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('SELURUH RIWAYAT', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 11)),
          const SizedBox(height: 10),
          Text('Masuk  ${money(summary.totalIncome)}', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 6),
          Text('Keluar  ${money(summary.totalExpense)}', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 10),
          NeoProgressBar(progress: summary.totalIncome == 0 ? 0 : summary.totalExpense / summary.totalIncome, color: p.secondary),
          const SizedBox(height: 6),
          const Text('Pengeluaran dibanding pemasukan tercatat.', style: TextStyle(fontSize: 11)),
        ])),
      ),
      const SizedBox(height: 22),
      const NeoSectionTitle('PERBANDINGAN MINGGUAN'),
      const SizedBox(height: 10),
      ref.watch(weeklyActivityProvider).when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, __) => NeoErrorCard(onRetry: () => ref.invalidate(weeklyActivityProvider)),
        data: (week) => NeoCard(color: p.accent, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Minggu ini', style: Theme.of(context).textTheme.titleMedium),
          Text('Setoran ${money(week.deposits)} · Keluar ${money(week.expenses)}'),
          const Divider(height: 22),
          Text('Minggu lalu', style: Theme.of(context).textTheme.titleMedium),
          Text('Setoran ${money(week.previousDeposits)} · Keluar ${money(week.previousExpenses)}'),
          const SizedBox(height: 8),
          const Text('Setoran adalah alokasi tujuan, bukan pemasukan.', style: TextStyle(fontSize: 11)),
        ])),
      ),
      const SizedBox(height: 22),
      const NeoSectionTitle('ANGGARAN PERIODE TERPILIH'),
      const SizedBox(height: 10),
      ref.watch(budgetsProvider).when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, __) => NeoErrorCard(onRetry: () => ref.invalidate(budgetsProvider)),
        data: (items) {
          final configured = items.where((item) => item.limit > 0).toList();
          if (configured.isEmpty) { return const NeoCard(child: Text('Atur anggaran untuk melihat progres per kategori.')); }
          return NeoCard(child: Column(children: [for (final item in configured) ...[
            Row(children: [Expanded(child: Text(item.category, style: const TextStyle(fontWeight: FontWeight.w800))), Text('${money(item.spent)} / ${money(item.limit)}', style: const TextStyle(fontSize: 11))]),
            const SizedBox(height: 6), NeoProgressBar(progress: item.progress, color: p.highlight), const SizedBox(height: 14),
          ]]));
        },
      ),
    ]);
  }
}
