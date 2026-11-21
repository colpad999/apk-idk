import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../app/providers.dart';
import '../../app/theme/neo_theme.dart';
import '../../core/utils/currency.dart';
import '../../data/savings_transaction.dart';
import '../../shared/neo_components.dart';
import '../../shared/neo_feedback.dart';
import 'goal_cover.dart';
import 'goal_editor_page.dart';

class GoalDetailPage extends ConsumerWidget {
  const GoalDetailPage({required this.goalId, required this.onAllocate, super.key});
  final int goalId;
  final void Function(TransactionType type, int goalId) onAllocate;

  Future<void> _closeGoal(BuildContext context, WidgetRef ref, SavingGoal goal) async {
    final confirmed = await confirmNeoAction(
      context,
      title: 'Tutup target ini?',
      message: goal.allocatedAmount > 0
          ? 'Sisa ${formatRupiah(goal.allocatedAmount)} akan dicatat sebagai penarikan kembali ke kas. Riwayat transaksi tetap disimpan dan total aset tidak berubah.'
          : 'Target akan ditutup dan fotonya dihapus bila tidak dipakai target lain. Riwayat transaksi tetap disimpan.',
      confirmLabel: 'Tutup target',
      destructive: true,
    );
    if (!confirmed || !context.mounted) return;
    final deleted = await guardNeoAction<bool>(context, () async {
      final repository = ref.read(goalRepositoryProvider);
      final oldPhoto = await repository.delete(goal.id);
      if (oldPhoto != null && !await repository.isPhotoReferenced(oldPhoto)) {
        try {
          await ref.read(goalPhotoStorageProvider).delete(oldPhoto);
        } catch (_) {}
      }
      ref.invalidate(savingGoalsProvider);
      ref.invalidate(savingsSummaryProvider);
      ref.invalidate(transactionsProvider);
      ref.invalidate(financialMonthProvider);
      ref.invalidate(weeklyActivityProvider);
      return true;
    }, success: 'Target ditutup; riwayat keuangan tetap aman.');
    if (deleted == true && context.mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(savingGoalProvider(goalId));
    final allocations = ref.watch(goalAllocationsProvider(goalId));
    final palette = NeoPalette.of(context);
    final hidden = ref.watch(hideBalanceProvider);
    String money(int value) => hidden ? '••••••' : formatRupiah(value);
    return Scaffold(
      appBar: AppBar(title: const Text('DETAIL TARGET')),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, __) => Center(child: NeoErrorCard(onRetry: () => ref.invalidate(savingGoalsProvider))),
        data: (goal) {
          if (goal == null) {
            return const Center(child: Padding(padding: EdgeInsets.all(20), child: Text('Target sudah ditutup atau tidak tersedia.')));
          }
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 32),
            children: [
              NeoCard(
                padding: EdgeInsets.zero,
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  GoalCover(path: goal.coverPhotoPath, name: goal.name, height: 245),
                  Padding(
                    padding: const EdgeInsets.all(15),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Row(children: [
                        Expanded(child: Text(goal.name, style: Theme.of(context).textTheme.headlineSmall)),
                        NeoTag('${(goal.progress * 100).round()}%', color: palette.primary),
                      ]),
                      const SizedBox(height: 13),
                      Text(money(goal.allocatedAmount), style: Theme.of(context).textTheme.headlineLarge),
                      const SizedBox(height: 4),
                      Text('dari ${money(goal.targetAmount)} · sisa ${money(goal.remaining)}', style: TextStyle(color: palette.muted)),
                      const SizedBox(height: 11),
                      NeoProgressBar(progress: goal.progress),
                      if (goal.deadline != null) ...[
                        const SizedBox(height: 10),
                        Text('Deadline ${DateFormat('d MMMM yyyy', 'id_ID').format(goal.deadline!)}', style: TextStyle(color: palette.muted, fontSize: 12)),
                      ],
                      const SizedBox(height: 15),
                      Row(children: [
                        Expanded(child: FilledButton.icon(onPressed: () => onAllocate(TransactionType.deposit, goal.id), icon: const Icon(Icons.add), label: const Text('Setor'))),
                        const SizedBox(width: 8),
                        Expanded(child: OutlinedButton.icon(onPressed: goal.allocatedAmount > 0 ? () => onAllocate(TransactionType.withdrawal, goal.id) : null, icon: const Icon(Icons.remove), label: const Text('Tarik'))),
                      ]),
                    ]),
                  ),
                ]),
              ),
              const SizedBox(height: 14),
              Wrap(spacing: 8, runSpacing: 8, children: [
                OutlinedButton.icon(
                  onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => GoalEditorPage(goal: goal))),
                  icon: const Icon(Icons.edit_outlined, size: 18),
                  label: const Text('Edit target / foto'),
                ),
                OutlinedButton.icon(
                  onPressed: () => _closeGoal(context, ref, goal),
                  icon: const Icon(Icons.archive_outlined, size: 18),
                  label: const Text('Tutup target'),
                ),
              ]),
              const SizedBox(height: 18),
              const NeoSectionTitle('RIWAYAT ALOKASI'),
              const SizedBox(height: 9),
              allocations.when(
                loading: () => const LinearProgressIndicator(),
                error: (_, __) => NeoErrorCard(onRetry: () => ref.invalidate(goalAllocationsProvider(goalId))),
                data: (items) => items.isEmpty
                    ? const NeoCard(child: Text('Belum ada setoran atau penarikan untuk target ini.'))
                    : NeoCard(
                        child: Column(children: [
                          for (var index = 0; index < items.length; index++) ...[
                            Row(children: [
                              Icon(items[index].isAllocation ? Icons.south_west : Icons.north_east, size: 19, color: items[index].isAllocation ? palette.primary : palette.secondary),
                              const SizedBox(width: 9),
                              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                Text(items[index].isAllocation ? 'Setoran' : 'Penarikan', style: const TextStyle(fontWeight: FontWeight.w900)),
                                Text('${DateFormat('d MMM yyyy, HH:mm', 'id_ID').format(items[index].createdAt)}${items[index].note.isEmpty ? '' : ' · ${items[index].note}'}', style: TextStyle(color: palette.muted, fontSize: 10)),
                              ])),
                              Text(money(items[index].amount), style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 12)),
                            ]),
                            if (index < items.length - 1) const Divider(height: 20),
                          ],
                        ]),
                      ),
              ),
            ],
          );
        },
      ),
    );
  }
}
