import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../app/providers.dart';
import '../../app/theme/neo_theme.dart';
import '../../core/utils/currency.dart';
import '../../data/planning_repository.dart';
import '../../shared/neo_components.dart';

class BudgetPage extends ConsumerWidget {
  const BudgetPage({super.key});

  Future<void> _editBudget(BuildContext context, WidgetRef ref, BudgetLine line,
      DateTime month) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) => _SetBudgetSheet(line: line, month: month),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final month = ref.watch(budgetMonthProvider);
    final budgets = ref.watch(budgetsProvider);
    final palette = NeoPalette.of(context);
    final monthLabel = DateFormat('MMMM yyyy', 'id_ID').format(month);
    return budgets.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stack) => Center(
          child: TextButton(
              onPressed: () => ref.invalidate(budgetsProvider),
              child: const Text('Anggaran gagal dimuat. Coba lagi.'))),
      data: (lines) {
        final configured = lines.where((line) => line.limit > 0).toList();
        final totalLimit =
            configured.fold<int>(0, (sum, line) => sum + line.limit);
        final totalSpent =
            configured.fold<int>(0, (sum, line) => sum + line.spent);
        return ListView(
          padding: const EdgeInsets.fromLTRB(18, 12, 18, 110),
          children: [
            Text('Anggaran', style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 4),
            Text('Pantau batas bulanan berdasarkan transaksi pengeluaran.',
                style: TextStyle(color: palette.muted)),
            const SizedBox(height: 16),
            NeoCard(
              color: palette.accent,
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      IconButton(
                          tooltip: 'Bulan sebelumnya',
                          onPressed: () => ref
                              .read(budgetMonthProvider.notifier)
                              .state = DateTime(month.year, month.month - 1),
                          icon: const Icon(Icons.chevron_left)),
                      Expanded(
                          child: Center(
                              child: Text(monthLabel,
                                  style: Theme.of(context)
                                      .textTheme
                                      .titleMedium))),
                      IconButton(
                          tooltip: 'Bulan berikutnya',
                          onPressed: () => ref
                              .read(budgetMonthProvider.notifier)
                              .state = DateTime(month.year, month.month + 1),
                          icon: const Icon(Icons.chevron_right)),
                    ]),
                    const SizedBox(height: 8),
                    Text(formatRupiah(totalSpent),
                        style: Theme.of(context).textTheme.headlineSmall),
                    Text(
                        'dari ${formatRupiah(totalLimit)} anggaran yang diatur',
                        style: TextStyle(color: palette.text)),
                    const SizedBox(height: 10),
                    NeoProgressBar(
                        progress: totalLimit == 0 ? 0 : totalSpent / totalLimit,
                        color: totalSpent > totalLimit
                            ? palette.secondary
                            : palette.primary),
                  ]),
            ),
            const SizedBox(height: 20),
            NeoSectionTitle('Kategori',
                trailing:
                    NeoTag('${configured.length}/${lines.length} diatur')),
            const SizedBox(height: 11),
            for (final line in lines) ...[
              _BudgetCategoryTile(
                  line: line,
                  onTap: () => _editBudget(context, ref, line, month)),
              const SizedBox(height: 11),
            ],
            Text(
                'Anggaran hanya membandingkan batas dengan pengeluaran tercatat; saldo tidak dikurangi lagi.',
                style: TextStyle(color: palette.muted, fontSize: 12)),
          ],
        );
      },
    );
  }
}

class _BudgetCategoryTile extends StatelessWidget {
  const _BudgetCategoryTile({required this.line, required this.onTap});

  final BudgetLine line;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = NeoPalette.of(context);
    return NeoCard(
      padding: const EdgeInsets.all(14),
      child: InkWell(
        onTap: onTap,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(
                child: Text(line.category,
                    style: Theme.of(context).textTheme.titleMedium)),
            IconButton(
                tooltip: 'Atur anggaran ${line.category}',
                onPressed: onTap,
                icon: const Icon(Icons.edit_outlined, size: 20)),
          ]),
          Text(
              line.limit == 0
                  ? 'Belum diatur'
                  : '${formatRupiah(line.spent)} / ${formatRupiah(line.limit)}',
              style: Theme.of(context).textTheme.bodyMedium),
          if (line.limit > 0) ...[
            const SizedBox(height: 8),
            NeoProgressBar(
                progress: line.progress,
                color: line.spent > line.limit
                    ? palette.secondary
                    : palette.primary),
            const SizedBox(height: 7),
            Row(children: [
              Expanded(
                  child: Text(
                      line.spent > line.limit
                          ? 'Melebihi batas ${formatRupiah(line.spent - line.limit)}'
                          : 'Sisa ${formatRupiah(line.remaining)}',
                      style: TextStyle(
                          color: line.isNearLimit
                              ? palette.secondary
                              : palette.muted,
                          fontWeight: FontWeight.w800,
                          fontSize: 12))),
              if (line.isNearLimit)
                NeoTag(line.spent > line.limit ? 'LEWAT BATAS' : 'MENDEKATI',
                    color: palette.highlight),
            ]),
          ],
        ]),
      ),
    );
  }
}

class _SetBudgetSheet extends ConsumerStatefulWidget {
  const _SetBudgetSheet({required this.line, required this.month});

  final BudgetLine line;
  final DateTime month;

  @override
  ConsumerState<_SetBudgetSheet> createState() => _SetBudgetSheetState();
}

class _SetBudgetSheetState extends ConsumerState<_SetBudgetSheet> {
  late final TextEditingController _limitController;
  final _formKey = GlobalKey<FormState>();
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _limitController = TextEditingController(
        text: widget.line.limit == 0 ? '' : widget.line.limit.toString());
  }

  @override
  void dispose() {
    _limitController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      await ref.read(planningRepositoryProvider).setBudget(
          category: widget.line.category,
          month: widget.month,
          limit: int.parse(_limitController.text));
      ref.invalidate(budgetsProvider);
      if (mounted) Navigator.pop(context);
    } on Object {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Anggaran tidak dapat disimpan.')));
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
                Text('Anggaran ${widget.line.category}',
                    style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _limitController,
                  autofocus: true,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                      labelText: 'Batas bulanan',
                      prefixText: 'Rp ',
                      border: OutlineInputBorder()),
                  validator: (value) {
                    final parsed = int.tryParse(value ?? '');
                    return parsed == null || parsed <= 0
                        ? 'Masukkan nominal lebih dari Rp0.'
                        : null;
                  },
                ),
                const SizedBox(height: 14),
                SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                        onPressed: _saving ? null : _save,
                        child: Text(
                            _saving ? 'Menyimpan...' : 'Simpan anggaran'))),
              ]),
        ),
      );
}
