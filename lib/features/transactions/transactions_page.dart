import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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
          padding: const EdgeInsets.fromLTRB(16, 6, 16, 10),
          child: NeoCard(
              padding: const EdgeInsets.all(8),
              child: TextField(
                  onChanged: (value) =>
                      setState(() => _query = value.trim().toLowerCase()),
                  decoration: const InputDecoration(
                      hintText: 'Cari kategori atau catatan',
                      prefixIcon: Icon(Icons.search_rounded))))),
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
              child: ListView.separated(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 110),
                itemCount: filtered.length,
                separatorBuilder: (context, index) => const SizedBox(height: 8),
                itemBuilder: (context, index) => NeoCard(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 9, vertical: 2),
                    child: TransactionTile(
                        transaction: filtered[index], hidden: hidden)),
              ),
            );
          },
        ),
      ),
    ]);
  }
}
