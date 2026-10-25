import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../app/providers.dart';
import '../../app/theme/neo_theme.dart';
import '../../core/utils/currency.dart';
import '../../data/savings_transaction.dart';
import '../../shared/neo_components.dart';

class GoalsPage extends ConsumerWidget {
  const GoalsPage({required this.onAllocate, super.key});

  final void Function(TransactionType type, int goalId) onAllocate;

  Future<void> _createGoal(BuildContext context) async {
    await showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        builder: (context) => const _CreateGoalSheet());
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final goals = ref.watch(savingGoalsProvider);
    final palette = NeoPalette.of(context);
    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 12, 18, 110),
      children: [
        Row(children: [
          Expanded(
              child: Text('Target tabungan',
                  style: Theme.of(context).textTheme.headlineSmall)),
          IconButton(
              tooltip: 'Buat target',
              onPressed: () => _createGoal(context),
              icon: const Icon(Icons.add_box_outlined))
        ]),
        Text('Alokasi hanyalah catatan virtual, bukan rekening terpisah.',
            style: TextStyle(color: palette.muted)),
        const SizedBox(height: 16),
        goals.when(
          loading: () => const Center(
              child: Padding(
                  padding: EdgeInsets.all(28),
                  child: CircularProgressIndicator())),
          error: (error, stack) => Center(
              child: TextButton(
                  onPressed: () => ref.invalidate(savingGoalsProvider),
                  child: const Text('Target gagal dimuat. Coba lagi.'))),
          data: (items) => items.isEmpty
              ? NeoCard(
                  color: palette.highlight,
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.flag_outlined, size: 30),
                        const SizedBox(height: 10),
                        Text('Mulai dengan satu tujuan.',
                            style: Theme.of(context).textTheme.titleLarge),
                        const SizedBox(height: 6),
                        const Text(
                            'Contohnya dana pendidikan, liburan, atau barang yang ingin dibeli.'),
                        const SizedBox(height: 14),
                        FilledButton.icon(
                            onPressed: () => _createGoal(context),
                            icon: const Icon(Icons.add),
                            label: const Text('Buat target'))
                      ]))
              : Column(children: [
                  for (final goal in items) ...[
                    _GoalTile(
                        goal: goal,
                        onAllocate: () =>
                            onAllocate(TransactionType.deposit, goal.id),
                        onWithdraw: () =>
                            onAllocate(TransactionType.withdrawal, goal.id)),
                    const SizedBox(height: 13),
                  ]
                ]),
        ),
      ],
    );
  }
}

class _GoalTile extends StatelessWidget {
  const _GoalTile(
      {required this.goal, required this.onAllocate, required this.onWithdraw});

  final SavingGoal goal;
  final VoidCallback onAllocate;
  final VoidCallback onWithdraw;

  @override
  Widget build(BuildContext context) {
    final palette = NeoPalette.of(context);
    return NeoCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Icon(Icons.flag_rounded),
          const SizedBox(width: 9),
          Expanded(
              child: Text(goal.name,
                  style: Theme.of(context).textTheme.titleLarge)),
          NeoTag('${(goal.progress * 100).round()}%', color: palette.primary)
        ]),
        const SizedBox(height: 13),
        Text(formatRupiah(goal.allocatedAmount),
            style: Theme.of(context).textTheme.headlineSmall),
        Text(
            'dari ${formatRupiah(goal.targetAmount)} · sisa ${formatRupiah(goal.remaining)}',
            style: TextStyle(color: palette.muted)),
        const SizedBox(height: 10),
        NeoProgressBar(progress: goal.progress),
        if (goal.deadline != null) ...[
          const SizedBox(height: 9),
          Text(
              'Target tanggal ${DateFormat('d MMMM yyyy', 'id_ID').format(goal.deadline!)}',
              style: TextStyle(color: palette.muted, fontSize: 12)),
        ],
        const SizedBox(height: 13),
        Row(children: [
          Expanded(
              child: FilledButton.icon(
                  onPressed: onAllocate,
                  icon: const Icon(Icons.add),
                  label: const Text('Setor'))),
          const SizedBox(width: 9),
          Expanded(
              child: OutlinedButton.icon(
                  onPressed: goal.allocatedAmount > 0 ? onWithdraw : null,
                  icon: const Icon(Icons.remove),
                  label: const Text('Tarik'))),
        ]),
      ]),
    );
  }
}

class _CreateGoalSheet extends ConsumerStatefulWidget {
  const _CreateGoalSheet();

  @override
  ConsumerState<_CreateGoalSheet> createState() => _CreateGoalSheetState();
}

class _CreateGoalSheetState extends ConsumerState<_CreateGoalSheet> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _amountController = TextEditingController();
  DateTime? _deadline;
  bool _saving = false;

  @override
  void dispose() {
    _nameController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  Future<void> _chooseDeadline() async {
    final today = DateTime.now();
    final result = await showDatePicker(
        context: context,
        initialDate: _deadline ?? today,
        firstDate: today,
        lastDate: DateTime(today.year + 20));
    if (result != null) setState(() => _deadline = result);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      await ref.read(goalRepositoryProvider).create(
          name: _nameController.text,
          targetAmount: int.parse(_amountController.text),
          deadline: _deadline);
      ref.invalidate(savingGoalsProvider);
      if (mounted) Navigator.pop(context);
    } on Object {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Target tidak dapat disimpan.')));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => Padding(
        padding: EdgeInsets.fromLTRB(
            20, 18, 20, MediaQuery.viewInsetsOf(context).bottom + 20),
        child: Form(
            key: _formKey,
            child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Buat target',
                      style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 13),
                  TextFormField(
                      controller: _nameController,
                      textCapitalization: TextCapitalization.sentences,
                      decoration:
                          const InputDecoration(labelText: 'Nama target'),
                      validator: (value) =>
                          value == null || value.trim().isEmpty
                              ? 'Nama target wajib diisi.'
                              : null),
                  const SizedBox(height: 11),
                  TextFormField(
                      controller: _amountController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                          labelText: 'Nominal target', prefixText: 'Rp '),
                      validator: (value) {
                        final amount = int.tryParse(value ?? '');
                        return amount == null || amount <= 0
                            ? 'Masukkan nominal lebih dari Rp0.'
                            : null;
                      }),
                  const SizedBox(height: 9),
                  OutlinedButton.icon(
                      onPressed: _chooseDeadline,
                      icon: const Icon(Icons.calendar_month),
                      label: Text(_deadline == null
                          ? 'Pilih deadline (opsional)'
                          : DateFormat('d MMMM yyyy', 'id_ID')
                              .format(_deadline!))),
                  const SizedBox(height: 12),
                  SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                          onPressed: _saving ? null : _save,
                          child: Text(
                              _saving ? 'Menyimpan...' : 'Simpan target'))),
                ])),
      );
}
