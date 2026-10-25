import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../data/budget_categories.dart';
import '../../data/savings_transaction.dart';

class AddTransactionSheet extends ConsumerStatefulWidget {
  const AddTransactionSheet(
      {this.initialType = TransactionType.income,
      this.initialGoalId,
      super.key});

  final TransactionType initialType;
  final int? initialGoalId;

  @override
  ConsumerState<AddTransactionSheet> createState() =>
      _AddTransactionSheetState();
}

class _AddTransactionSheetState extends ConsumerState<AddTransactionSheet> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _categoryController = TextEditingController(text: 'Uang saku');
  final _noteController = TextEditingController();
  late TransactionType _type;
  int? _goalId;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _type = widget.initialType;
    _goalId = widget.initialGoalId;
    if (_type == TransactionType.expense) _categoryController.text = 'Lainnya';
    if (_type == TransactionType.deposit ||
        _type == TransactionType.withdrawal) {
      _categoryController.text = 'Tabungan';
    }
  }

  @override
  void dispose() {
    _amountController.dispose();
    _categoryController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      await ref.read(transactionRepositoryProvider).add(
            type: _type,
            amount: int.parse(_amountController.text),
            category: _categoryController.text,
            createdAt: DateTime.now(),
            note: _noteController.text,
            goalId: _goalId,
          );
      ref.invalidate(savingsSummaryProvider);
      ref.invalidate(transactionsProvider);
      ref.invalidate(weeklyActivityProvider);
      ref.invalidate(incomeSourcesProvider);
      if (_type == TransactionType.expense) ref.invalidate(budgetsProvider);
      if (_type == TransactionType.deposit ||
          _type == TransactionType.withdrawal) {
        ref.invalidate(savingGoalsProvider);
      }
      if (!mounted) return;
      Navigator.of(context).pop();
    } on Object catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(_messageFor(error))));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  String _messageFor(Object error) {
    if (error is StateError || error is ArgumentError) {
      return error.toString().replaceFirst('Bad state: ', '');
    }
    return 'Transaksi belum tersimpan. Silakan coba lagi.';
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 12, 20, bottomInset + 20),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Center(
                    child: Container(
                        width: 38,
                        height: 4,
                        decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.outlineVariant,
                            borderRadius: BorderRadius.circular(4)))),
                const SizedBox(height: 20),
                Text('Tambah transaksi',
                    style: Theme.of(context)
                        .textTheme
                        .titleLarge
                        ?.copyWith(fontWeight: FontWeight.w800)),
                const SizedBox(height: 17),
                SegmentedButton<TransactionType>(
                  segments: const [
                    ButtonSegment(
                        value: TransactionType.income,
                        label: Text('Masuk'),
                        icon: Icon(Icons.south_west_rounded)),
                    ButtonSegment(
                        value: TransactionType.expense,
                        label: Text('Keluar'),
                        icon: Icon(Icons.north_east_rounded)),
                    ButtonSegment(
                        value: TransactionType.deposit,
                        label: Text('Setor'),
                        icon: Icon(Icons.savings_outlined)),
                    ButtonSegment(
                        value: TransactionType.withdrawal,
                        label: Text('Tarik'),
                        icon: Icon(Icons.wallet_outlined)),
                  ],
                  selected: {_type},
                  showSelectedIcon: false,
                  onSelectionChanged: (selection) => setState(() {
                    _type = selection.first;
                    if (_type != TransactionType.deposit &&
                        _type != TransactionType.withdrawal) {
                      _goalId = null;
                    }
                    if (_type == TransactionType.expense &&
                        !budgetCategories.contains(_categoryController.text)) {
                      _categoryController.text = 'Lainnya';
                    }
                    if (_type == TransactionType.deposit ||
                        _type == TransactionType.withdrawal) {
                      _categoryController.text = 'Tabungan';
                    }
                    if (_type == TransactionType.income &&
                        _categoryController.text == 'Tabungan') {
                      _categoryController.text = 'Uang saku';
                    }
                  }),
                ),
                const SizedBox(height: 17),
                TextFormField(
                  controller: _amountController,
                  autofocus: true,
                  keyboardType: TextInputType.number,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(12)
                  ],
                  decoration: const InputDecoration(
                      labelText: 'Nominal',
                      prefixText: 'Rp ',
                      border: OutlineInputBorder(),
                      hintText: '0'),
                  validator: (value) {
                    final amount = int.tryParse(value ?? '');
                    if (amount == null || amount <= 0) {
                      return 'Masukkan nominal lebih dari Rp0.';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                if (_type == TransactionType.expense)
                  DropdownButtonFormField<String>(
                    initialValue:
                        budgetCategories.contains(_categoryController.text)
                            ? _categoryController.text
                            : 'Lainnya',
                    decoration: const InputDecoration(
                        labelText: 'Kategori pengeluaran'),
                    items: [
                      for (final category in budgetCategories)
                        DropdownMenuItem(value: category, child: Text(category))
                    ],
                    onChanged: (value) {
                      if (value != null) {
                        setState(() => _categoryController.text = value);
                      }
                    },
                  )
                else
                  TextFormField(
                      controller: _categoryController,
                      textCapitalization: TextCapitalization.sentences,
                      decoration: InputDecoration(
                          labelText: _type == TransactionType.income
                              ? 'Sumber pemasukan'
                              : 'Kategori'),
                      validator: (value) =>
                          value == null || value.trim().isEmpty
                              ? 'Sumber/kategori wajib diisi.'
                              : null),
                if (_type == TransactionType.deposit ||
                    _type == TransactionType.withdrawal) ...[
                  const SizedBox(height: 12),
                  ref.watch(savingGoalsProvider).when(
                        loading: () => const LinearProgressIndicator(),
                        error: (error, stack) =>
                            const Text('Daftar target tidak dapat dimuat.'),
                        data: (goals) => DropdownButtonFormField<int?>(
                          initialValue: _goalId,
                          decoration: const InputDecoration(
                              labelText: 'Target (opsional)'),
                          items: [
                            const DropdownMenuItem<int?>(
                                value: null, child: Text('Tanpa target')),
                            for (final goal in goals)
                              DropdownMenuItem<int?>(
                                  value: goal.id, child: Text(goal.name)),
                          ],
                          onChanged: (value) => setState(() => _goalId = value),
                        ),
                      ),
                ],
                const SizedBox(height: 12),
                TextField(
                    controller: _noteController,
                    textCapitalization: TextCapitalization.sentences,
                    maxLength: 120,
                    decoration: const InputDecoration(
                        labelText: 'Catatan (opsional)',
                        border: OutlineInputBorder())),
                const SizedBox(height: 8),
                SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                        onPressed: _saving ? null : _submit,
                        icon: _saving
                            ? const SizedBox.square(
                                dimension: 18,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2))
                            : const Icon(Icons.check_rounded),
                        label:
                            Text(_saving ? 'Menyimpan...' : 'Simpan transaksi'),
                        style: FilledButton.styleFrom(
                            minimumSize: const Size.fromHeight(50)))),
              ]),
        ),
      ),
    );
  }
}
