import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../app/providers.dart';
import '../../app/theme/neo_theme.dart';
import '../../shared/neo_components.dart';
import '../../shared/transaction_tile.dart';

class TransactionsPage extends ConsumerStatefulWidget {
  const TransactionsPage({super.key});

  @override
  ConsumerState<TransactionsPage> createState() => _TransactionsPageState();
}

class _TransactionsPageState extends ConsumerState<TransactionsPage> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final transactions = ref.watch(transactionsProvider);
    final hidden = ref.watch(hideBalanceProvider);
    final palette = NeoPalette.of(context);
    return Column(children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(20, 10, 20, 14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Jejak uang.', style: Theme.of(context).textTheme.headlineLarge),
          const SizedBox(height: 5),
          Text('Semua cerita keuanganmu, satu per satu.', style: TextStyle(color: palette.muted)),
          const SizedBox(height: 15),
          TextField(onChanged: (value) => setState(() => _query = value.trim().toLowerCase()),
            decoration: const InputDecoration(hintText: 'Cari kategori atau catatan', prefixIcon: Icon(Icons.search_rounded))),
        ]),
      ),
      Expanded(
        child: transactions.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, stack) => Center(
              child: TextButton(
                  onPressed: () => ref.invalidate(transactionsProvider),
                  child: const Text('Data gagal dimuat. Coba lagi.'))),
          data: (items) {
            final filtered = items
                .where((item) =>
                    item.category.toLowerCase().contains(_query) ||
                    item.note?.toLowerCase().contains(_query) == true)
                .toList();
            if (filtered.isEmpty) {
              return Center(
                  child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: NeoCard(
                          color: palette.highlight,
                          child: Text(
                              _query.isEmpty
                                  ? 'Belum ada transaksi.'
                                  : 'Transaksi tidak ditemukan.',
                              style: const TextStyle(
                                  fontWeight: FontWeight.w800)))));
            }
            return RefreshIndicator(
              onRefresh: () async {
                ref.invalidate(transactionsProvider);
                await ref.read(transactionsProvider.future);
              },
              child: ListView.builder(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 110),
                itemCount: filtered.length,
                itemBuilder: (context, index) {
                  final item = filtered[index];
                  final previous = index == 0 ? null : filtered[index - 1].createdAt;
                  final date = item.createdAt;
                  final showDate = previous == null || previous.year != date.year || previous.month != date.month || previous.day != date.day;
                  return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    if (showDate) Padding(padding: const EdgeInsets.only(top: 15, bottom: 8),
                      child: Text(DateFormat('EEEE, d MMMM yyyy', 'id_ID').format(date).toUpperCase(),
                        style: TextStyle(color: palette.muted, fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: .8))),
                    TransactionTile(transaction: item, hidden: hidden),
                    Divider(color: palette.mutedSurface.withValues(alpha: .7), height: 1, indent: 55),
                  ]);
                },
              ),
            );
          },
        ),
      ),
    ]);
  }
}
