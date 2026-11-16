import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../app/theme/neo_theme.dart';
import '../../core/utils/currency.dart';
import '../../data/wishlist_repository.dart';
import '../../shared/neo_components.dart';
import '../../shared/neo_feedback.dart';

class WishlistPage extends ConsumerStatefulWidget {
  const WishlistPage({super.key});
  @override
  ConsumerState<WishlistPage> createState() => _WishlistPageState();
}

class _WishlistPageState extends ConsumerState<WishlistPage> {
  bool _busy = false;
  Future<void> _edit([WishlistItem? item]) async {
    if (_busy) return;
    final name = TextEditingController(text: item?.name ?? '');
    final price = TextEditingController(text: item?.price.toString() ?? '');
    final note = TextEditingController(text: item?.note ?? '');
    final data = await showDialog<(String, String, String)>(context: context, builder: (context) => AlertDialog(
      title: Text(item == null ? 'Tambah wishlist' : 'Edit wishlist'),
      content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
        TextField(controller: name, maxLength: 100, decoration: const InputDecoration(labelText: 'Nama barang')),
        const SizedBox(height: 8),
        TextField(controller: price, keyboardType: TextInputType.number, inputFormatters: [FilteringTextInputFormatter.digitsOnly], maxLength: 13, decoration: const InputDecoration(labelText: 'Perkiraan harga (Rp)')),
        const SizedBox(height: 8),
        TextField(controller: note, maxLength: 500, minLines: 2, maxLines: 3, decoration: const InputDecoration(labelText: 'Catatan (opsional)')),
      ])),
      actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Batal')),
        FilledButton(onPressed: () => Navigator.pop(context, (name.text, price.text, note.text)), child: const Text('Simpan'))],
    ));
    name.dispose(); price.dispose(); note.dispose();
    if (!mounted || data == null || _busy) return;
    final value = int.tryParse(data.$2);
    if (value == null) { showNeoMessage(context, 'Masukkan harga perkiraan; isi 0 jika belum diketahui.'); return; }
    await _run(() => ref.read(wishlistRepositoryProvider).save(id: item?.id, name: data.$1, price: value, note: data.$3));
  }
  Future<void> _run(Future<void> Function() action) async {
    if (_busy) return;
    setState(() => _busy = true);
    try { await action(); ref.invalidate(wishlistProvider); }
    catch (error) { if (mounted) { showNeoMessage(context, friendlyError(error)); } }
    finally { if (mounted) setState(() => _busy = false); }
  }
  @override
  Widget build(BuildContext context) {
    final items = ref.watch(wishlistProvider);
    return Scaffold(appBar: AppBar(title: const Text('WISHLIST')),
      floatingActionButton: FloatingActionButton.extended(onPressed: _busy ? null : () => _edit(), icon: const Icon(Icons.add), label: const Text('Tambah')),
      body: items.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, __) => NeoErrorCard(onRetry: () => ref.invalidate(wishlistProvider)),
        data: (values) => ListView(padding: const EdgeInsets.fromLTRB(16, 12, 16, 100), children: [
          NeoCard(color: NeoPalette.of(context).primary, child: const Text('Rencanakan keinginan tanpa mengubah saldo. Menandai barang terbeli tidak otomatis membuat transaksi.')),
          const SizedBox(height: 16),
          if (values.isEmpty) const NeoCard(child: Text('Belum ada wishlist.')),
          for (final item in values) ...[
            NeoCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [Expanded(child: Text(item.name, style: Theme.of(context).textTheme.titleMedium)), NeoTag(item.purchased ? 'TERBELI' : 'DIINGINKAN')]),
              const SizedBox(height: 5), Text(item.price == 0 ? 'Harga belum diketahui' : formatRupiah(item.price), style: const TextStyle(fontWeight: FontWeight.w900)),
              if (item.note.isNotEmpty) ...[const SizedBox(height: 6), Text(item.note)],
              Wrap(spacing: 6, children: [
                TextButton.icon(onPressed: _busy ? null : () => _run(() => ref.read(wishlistRepositoryProvider).setPurchased(item.id, !item.purchased)), icon: Icon(item.purchased ? Icons.undo : Icons.check), label: Text(item.purchased ? 'Batalkan' : 'Terbeli')),
                TextButton.icon(onPressed: _busy ? null : () => _edit(item), icon: const Icon(Icons.edit_outlined), label: const Text('Edit')),
                TextButton.icon(onPressed: _busy ? null : () async {
                  final confirmed = await confirmNeoAction(context, title: 'Hapus wishlist?', message: '“${item.name}” akan dihapus. Transaksi tidak terpengaruh.', confirmLabel: 'Hapus', destructive: true);
                  if (confirmed && context.mounted) await _run(() => ref.read(wishlistRepositoryProvider).delete(item.id));
                }, icon: const Icon(Icons.delete_outline), label: const Text('Hapus')),
              ]),
            ])), const SizedBox(height: 12),
          ],
        ]),
      ));
  }
}
