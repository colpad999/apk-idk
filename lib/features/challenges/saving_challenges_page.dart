import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../app/providers.dart';
import '../../app/theme/neo_theme.dart';
import '../../core/utils/currency.dart';
import '../../data/savings_transaction.dart';
import '../../shared/neo_components.dart';
import '../../shared/neo_feedback.dart';

class SavingChallengesPage extends ConsumerStatefulWidget {
  const SavingChallengesPage({super.key});
  @override
  ConsumerState<SavingChallengesPage> createState() => _SavingChallengesPageState();
}

class _SavingChallengesPageState extends ConsumerState<SavingChallengesPage> {
  bool _busy = false;
  Future<void> _create(List<SavingGoal> goals) async {
    if (goals.isEmpty) { showNeoMessage(context, 'Buat target tabungan terlebih dahulu.'); return; }
    final name = TextEditingController();
    final target = TextEditingController();
    var goalId = goals.first.id;
    var end = DateTime.now().add(const Duration(days: 30));
    final values = await showDialog<(String, String, int, DateTime)>(context: context, builder: (context) => StatefulBuilder(builder: (context, update) => AlertDialog(
      title: const Text('Challenge baru'),
      content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
        TextField(controller: name, maxLength: 100, decoration: const InputDecoration(labelText: 'Nama challenge')),
        const SizedBox(height: 8),
        TextField(controller: target, maxLength: 12, keyboardType: TextInputType.number, inputFormatters: [FilteringTextInputFormatter.digitsOnly], decoration: const InputDecoration(labelText: 'Target setoran bersih (Rp)')),
        const SizedBox(height: 8),
        DropdownButtonFormField<int>(initialValue: goalId, isExpanded: true, decoration: const InputDecoration(labelText: 'Tujuan tabungan'), items: [for (final g in goals) DropdownMenuItem(value: g.id, child: Text(g.name, overflow: TextOverflow.ellipsis))], onChanged: (v) { if (v != null) { update(() => goalId = v); } }),
        const SizedBox(height: 8),
        OutlinedButton.icon(onPressed: () async {
          final picked = await showDatePicker(context: context, initialDate: end, firstDate: DateTime.now().subtract(const Duration(days: 1)), lastDate: DateTime(2100));
          if (picked != null) { update(() => end = picked); }
        }, icon: const Icon(Icons.calendar_today), label: Text(DateFormat('d MMM yyyy', 'id_ID').format(end))),
      ])),
      actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Batal')),
        FilledButton(onPressed: () => Navigator.pop(context, (name.text, target.text, goalId, end)), child: const Text('Buat'))],
    )));
    name.dispose(); target.dispose();
    if (!mounted || values == null || _busy) { return; }
    final amount = int.tryParse(values.$2);
    if (amount == null) { showNeoMessage(context, 'Isi target setoran.'); return; }
    setState(() => _busy = true);
    try {
      await ref.read(savingChallengeRepositoryProvider).create(goalId: values.$3, name: values.$1, target: amount, endDate: values.$4);
      ref.invalidate(savingChallengesProvider);
    } catch (error) { if (mounted) { showNeoMessage(context, friendlyError(error)); } }
    finally { if (mounted) { setState(() => _busy = false); } }
  }

  @override
  Widget build(BuildContext context) {
    final challenges = ref.watch(savingChallengesProvider);
    final goals = ref.watch(savingGoalsProvider);
    final p = NeoPalette.of(context);
    return Scaffold(appBar: AppBar(title: const Text('SAVING CHALLENGE')),
      floatingActionButton: FloatingActionButton.extended(onPressed: _busy || !goals.hasValue ? null : () => _create(goals.value!), icon: const Icon(Icons.add), label: const Text('Buat challenge')),
      body: challenges.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, __) => NeoErrorCard(onRetry: () { ref.invalidate(savingGoalsProvider); ref.invalidate(savingChallengesProvider); }),
        data: (items) => ListView(padding: const EdgeInsets.fromLTRB(16, 12, 16, 100), children: [
          NeoCard(color: p.accent, child: const Text('Progres adalah setoran dikurangi penarikan ke tujuan yang dipilih selama periode challenge. Tidak membuat saldo atau transaksi baru. Challenge yang berbagi tujuan dapat menghitung alokasi yang sama.')),
          const SizedBox(height: 16),
          if (items.isEmpty) const NeoCard(child: Text('Belum ada challenge. Buat tujuan tabungan terlebih dahulu.')),
          for (final item in items) ...[
            NeoCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(item.name, style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 4), Text('Tujuan: ${item.goalName}${item.goalClosed ? ' (ditutup)' : ''}'),
              const SizedBox(height: 8), Text('${formatRupiah(item.progress)} / ${formatRupiah(item.target)}', style: const TextStyle(fontWeight: FontWeight.w900)),
              const SizedBox(height: 8), NeoProgressBar(progress: item.progress / item.target),
              const SizedBox(height: 8), Text('Sampai ${DateFormat('d MMM yyyy', 'id_ID').format(item.endAt.subtract(const Duration(seconds: 1)))} · ${item.progress >= item.target ? 'Target tercapai' : DateTime.now().isAfter(item.endAt) ? 'Periode berakhir' : 'Berlangsung'}'),
              Align(alignment: Alignment.centerRight, child: TextButton.icon(onPressed: _busy ? null : () async {
                final confirmed = await confirmNeoAction(context, title: 'Hapus challenge?', message: 'Transaksi dan target tabungan tetap aman.', confirmLabel: 'Hapus', destructive: true);
                if (!confirmed || !context.mounted) { return; }
                setState(() => _busy = true);
                try { await ref.read(savingChallengeRepositoryProvider).delete(item.id); ref.invalidate(savingChallengesProvider); }
                catch (error) { if (context.mounted) { showNeoMessage(context, friendlyError(error)); } }
                finally { if (mounted) { setState(() => _busy = false); } }
              }, icon: const Icon(Icons.delete_outline), label: const Text('Hapus'))),
            ])), const SizedBox(height: 12),
          ],
        ]),
      ));
  }
}
