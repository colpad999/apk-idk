import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../app/providers.dart';
import '../../app/theme/neo_theme.dart';
import '../../data/money_journal_repository.dart';
import '../../shared/neo_components.dart';
import '../../shared/neo_feedback.dart';

class MoneyJournalPage extends ConsumerStatefulWidget {
  const MoneyJournalPage({super.key});
  @override
  ConsumerState<MoneyJournalPage> createState() => _MoneyJournalPageState();
}
class _MoneyJournalPageState extends ConsumerState<MoneyJournalPage> {
  bool busy = false;
  Future<void> edit([MoneyJournalEntry? entry]) async {
    if (busy) return;
    final text = TextEditingController(text: entry?.note ?? '');
    var date = entry?.date.value ?? DateTime.now();
    final result = await showDialog<(String, DateTime)>(context: context, builder: (context) => StatefulBuilder(builder: (context, update) => AlertDialog(
      title: Text(entry == null ? 'Catatan keuangan' : 'Edit catatan'),
      content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
        OutlinedButton.icon(onPressed: () async {
          final value = await showDatePicker(context: context, initialDate: date, firstDate: DateTime(2000), lastDate: DateTime(2100));
          if (value != null) { update(() => date = value); }
        }, icon: const Icon(Icons.calendar_today), label: Text(DateFormat('d MMM yyyy', 'id_ID').format(date))),
        const SizedBox(height: 10),
        TextField(controller: text, minLines: 4, maxLines: 8, maxLength: 10000, decoration: const InputDecoration(labelText: 'Catatan')),
      ])),
      actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Batal')),
        FilledButton(onPressed: () => Navigator.pop(context, (text.text, date)), child: const Text('Simpan'))],
    )));
    text.dispose();
    if (!mounted || result == null) return;
    await run(() => ref.read(moneyJournalRepositoryProvider).save(id: entry?.id, date: result.$2, note: result.$1));
  }
  Future<void> run(Future<void> Function() action) async {
    if (busy) return;
    setState(() => busy = true);
    try { await action(); ref.invalidate(moneyJournalProvider); }
    catch (error) { if (mounted) { showNeoMessage(context, friendlyError(error)); } }
    finally { if (mounted) { setState(() => busy = false); } }
  }
  @override
  Widget build(BuildContext context) => Scaffold(appBar: AppBar(title: const Text('MONEY JOURNAL')),
    floatingActionButton: FloatingActionButton.extended(onPressed: busy ? null : () => edit(), icon: const Icon(Icons.add), label: const Text('Tulis')),
    body: ref.watch(moneyJournalProvider).when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, __) => NeoErrorCard(onRetry: () => ref.invalidate(moneyJournalProvider)),
      data: (entries) => ListView(padding: const EdgeInsets.fromLTRB(16, 12, 16, 100), children: [
        NeoCard(color: NeoPalette.of(context).highlight, child: const Text('Tulis refleksi dan rencana keuangan. Catatan ini tidak membuat transaksi atau mengubah saldo.')),
        const SizedBox(height: 14),
        if (entries.isEmpty) const NeoCard(child: Text('Belum ada catatan keuangan.')),
        for (final entry in entries) ...[
          NeoCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(DateFormat('d MMMM yyyy', 'id_ID').format(entry.date.value), style: const TextStyle(fontWeight: FontWeight.w900)),
            const SizedBox(height: 6), Text(entry.note),
            Wrap(spacing: 6, children: [
              TextButton.icon(onPressed: busy ? null : () => edit(entry), icon: const Icon(Icons.edit_outlined), label: const Text('Edit')),
              TextButton.icon(onPressed: busy ? null : () async {
                final confirmed = await confirmNeoAction(context, title: 'Hapus catatan?', message: 'Catatan keuangan ini akan dihapus. Transaksi tetap aman.', confirmLabel: 'Hapus', destructive: true);
                if (confirmed && context.mounted) { await run(() => ref.read(moneyJournalRepositoryProvider).delete(entry.id)); }
              }, icon: const Icon(Icons.delete_outline), label: const Text('Hapus')),
            ]),
          ])), const SizedBox(height: 12),
        ],
      ]),
    ));
}
