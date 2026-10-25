import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
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
    return Column(children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
        child: TextField(
          onChanged: (value) => setState(() => _query = value.trim().toLowerCase()),
          decoration: InputDecoration(
            hintText: 'Cari transaksi',
            prefixIcon: const Icon(Icons.search_rounded),
            filled: true,
            fillColor: Theme.of(context).colorScheme.surfaceContainerLow,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
          ),
        ),
      ),
      Expanded(
        child: transactions.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, stack) => Center(child: TextButton(onPressed: () => ref.invalidate(transactionsProvider), child: const Text('Data gagal dimuat. Coba lagi.'))),
          data: (items) {
            final filtered = items.where((item) => item.category.toLowerCase().contains(_query) || item.note?.toLowerCase().contains(_query) == true).toList();
            if (filtered.isEmpty) {
              return Center(child: Text(_query.isEmpty ? 'Belum ada transaksi.' : 'Transaksi tidak ditemukan.', style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)));
            }
            return RefreshIndicator(
              onRefresh: () async { ref.invalidate(transactionsProvider); await ref.read(transactionsProvider.future); },
              child: ListView.separated(
                padding: const EdgeInsets.fromLTRB(17, 0, 17, 100),
                itemCount: filtered.length,
                separatorBuilder: (context, index) => const Divider(height: 1, indent: 72),
                itemBuilder: (context, index) => TransactionTile(transaction: filtered[index], hidden: hidden),
              ),
            );
          },
        ),
      ),
    ]);
  }
}