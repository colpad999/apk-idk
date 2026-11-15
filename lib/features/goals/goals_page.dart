import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../app/providers.dart';
import '../../app/theme/neo_theme.dart';
import '../../core/utils/currency.dart';
import '../../data/savings_transaction.dart';
import '../../shared/neo_components.dart';
import 'goal_cover.dart';
import 'goal_detail_page.dart';
import 'goal_editor_page.dart';

class GoalsPage extends ConsumerWidget {
  const GoalsPage({required this.onAllocate, super.key});
  final void Function(TransactionType type, int goalId) onAllocate;

  void _createGoal(BuildContext context) => Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const GoalEditorPage()));

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final goals = ref.watch(savingGoalsProvider);
    final palette = NeoPalette.of(context);
    final hidden = ref.watch(hideBalanceProvider);
    return RefreshIndicator(
      onRefresh: () async => ref.invalidate(savingGoalsProvider),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 110),
        children: [
          Row(children: [
            Expanded(child: Text('Target tabungan', style: Theme.of(context).textTheme.headlineSmall)),
            IconButton(
                tooltip: 'Buat target',
                onPressed: () => _createGoal(context),
                icon: const Icon(Icons.add_box_outlined)),
          ]),
          Text('Alokasi hanyalah catatan virtual, bukan rekening terpisah.',
              style: TextStyle(color: palette.muted)),
          const SizedBox(height: 16),
          goals.when(
            loading: () => const NeoCard(child: SizedBox(height: 150, child: Center(child: CircularProgressIndicator()))),
            error: (_, __) => NeoErrorCard(onRetry: () => ref.invalidate(savingGoalsProvider)),
            data: (items) {
              if (items.isEmpty) { return NeoEmptyGoals(onCreate: () => _createGoal(context)); }
              final current = items.fold<int>(0, (sum, goal) => sum + goal.allocatedAmount);
              final target = items.fold<int>(0, (sum, goal) => sum + goal.targetAmount);
              final active = items.where((goal) => goal.progress < 1).toList();
              final completed = items.where((goal) => goal.progress >= 1).toList();
              String money(int value) => hidden ? '••••••' : formatRupiah(value);
              Widget goalTile(SavingGoal goal, {bool featured = false}) => Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: _GoalTile(goal: goal, featured: featured, hidden: hidden,
                  onAllocate: () => onAllocate(TransactionType.deposit, goal.id),
                  onWithdraw: () => onAllocate(TransactionType.withdrawal, goal.id)));
              return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                NeoCard(color: palette.primary, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('TOTAL TABUNGAN TUJUAN', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 11)),
                  const SizedBox(height: 6),
                  Text(money(current), style: Theme.of(context).textTheme.headlineLarge),
                  Text('dari target ${money(target)}'),
                  const SizedBox(height: 10), NeoProgressBar(progress: target == 0 ? 0 : current / target, color: palette.accent),
                ])),
                const SizedBox(height: 24),
                if (active.isNotEmpty) ...[
                  const NeoSectionTitle('TARGET AKTIF'), const SizedBox(height: 12),
                  for (var index = 0; index < active.length; index++) goalTile(active[index], featured: index == 0),
                ],
                if (completed.isNotEmpty) ...[
                  const NeoSectionTitle('TARGET TERCAPAI'), const SizedBox(height: 12),
                  for (final goal in completed) goalTile(goal),
                ],
              ]);
            },
          ),
        ],
      ),
    );
  }
}

class NeoEmptyGoals extends StatelessWidget {
  const NeoEmptyGoals({required this.onCreate, super.key});
  final VoidCallback onCreate;
  @override
  Widget build(BuildContext context) {
    final palette = NeoPalette.of(context);
    return NeoCard(
      color: palette.highlight,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Icon(Icons.flag_outlined, size: 32, color: Color(0xFF171717)),
        const SizedBox(height: 10),
        Text('Mulai dengan satu tujuan.',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(color: const Color(0xFF171717))),
        const SizedBox(height: 7),
        const Text('HP, laptop, sepeda, perlengkapan sekolah, atau liburan. Foto boleh ditambahkan nanti.',
            style: TextStyle(color: Color(0xFF171717))),
        const SizedBox(height: 14),
        FilledButton.icon(onPressed: onCreate, icon: const Icon(Icons.add), label: const Text('Buat target')),
      ]),
    );
  }
}

class _GoalTile extends StatelessWidget {
  const _GoalTile({required this.goal, required this.featured, required this.hidden, required this.onAllocate, required this.onWithdraw});
  final SavingGoal goal;
  final bool hidden, featured;
  final VoidCallback onAllocate, onWithdraw;

  @override
  Widget build(BuildContext context) {
    final palette = NeoPalette.of(context);
    String money(int value) => hidden ? '••••••' : formatRupiah(value);
    return NeoCard(
      padding: EdgeInsets.zero,
      child: InkWell(
        onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(
            builder: (_) => GoalDetailPage(goalId: goal.id, onAllocate: (type, _) {
              if (type == TransactionType.deposit) { onAllocate(); } else { onWithdraw(); }
            }))),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          GoalCover(path: goal.coverPhotoPath, name: goal.name, height: featured ? 210 : 120),
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Expanded(child: Text(goal.name, style: Theme.of(context).textTheme.titleLarge, maxLines: 2, overflow: TextOverflow.ellipsis)),
                const SizedBox(width: 7),
                NeoProgressRing(progress: goal.progress, size: 54),
              ]),
              const SizedBox(height: 10),
              Text(money(goal.allocatedAmount), style: Theme.of(context).textTheme.headlineSmall),
              const SizedBox(height: 3),
              Text('dari ${money(goal.targetAmount)} · sisa ${money(goal.remaining)}', style: TextStyle(color: palette.muted, fontSize: 12)),
              const SizedBox(height: 10),
              NeoProgressBar(progress: goal.progress),
              if (goal.deadline != null) ...[
                const SizedBox(height: 8),
                Text('Deadline ${DateFormat('d MMM yyyy', 'id_ID').format(goal.deadline!)}', style: TextStyle(color: palette.muted, fontSize: 11)),
              ],
              const SizedBox(height: 8),
              Text('Lihat detail  ↗', style: TextStyle(color: palette.muted, fontWeight: FontWeight.w700, fontSize: 11)),
              const SizedBox(height: 13),
              Row(children: [
                Expanded(child: FilledButton.icon(onPressed: onAllocate, icon: const Icon(Icons.add, size: 18), label: const Text('Setor'))),
                const SizedBox(width: 8),
                Expanded(child: OutlinedButton.icon(onPressed: goal.allocatedAmount > 0 ? onWithdraw : null, icon: const Icon(Icons.remove, size: 18), label: const Text('Tarik'))),
              ]),
            ]),
          ),
        ]),
      ),
    );
  }
}
