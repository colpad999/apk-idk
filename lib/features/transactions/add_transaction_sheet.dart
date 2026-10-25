import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../data/savings_transaction.dart';

class AddTransactionSheet extends ConsumerStatefulWidget {
  const AddTransactionSheet({super.key});

  @override
  ConsumerState<AddTransactionSheet> createState() => _AddTransactionSheetState();
}

class _AddTransactionSheetState extends ConsumerState<AddTransactionSheet> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _categoryController = TextEditingController(text: 'Umum');
  final _noteController = TextEditingController();
  TransactionType _type = TransactionType.income;
  bool _saving = false;

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
          );
      ref.invalidate(savingsSummaryProvider);
      ref.invalidate(transactionsProvider);
      if (!mounted) return;
      Navigator.of(context).pop();
    } on Object catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(_messageFor(error))));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  String _messageFor(Object error) {
    if (error is StateError || error is ArgumentError) return error.toString().replaceFirst('Bad state: ', '');
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
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
            Center(child: Container(width: 38, height: 4, decoration: BoxDecoration(color: Theme.of(context).colorScheme.outlineVariant, borderRadius: BorderRadius.circular(4)))),
            const SizedBox(height: 20),
            Text('Tambah transaksi', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
            const SizedBox(height: 17),
            SegmentedButton<TransactionType>(
              segments: const [
                ButtonSegment(value: TransactionType.income, label: Text('Masuk'), icon: Icon(Icons.south_west_rounded)),
                ButtonSegment(value: TransactionType.expense, label: Text('Keluar'), icon: Icon(Icons.north_east_rounded)),
                ButtonSegment(value: TransactionType.deposit, label: Text('Setor'), icon: Icon(Icons.savings_outlined)),
                ButtonSegment(value: TransactionType.withdrawal, label: Text('Tarik'), icon: Icon(Icons.wallet_outlined)),
              ],
              selected: {_type},
              showSelectedIcon: false,
              onSelectionChanged: (selection) => setState(() => _type = selection.first),
            ),
            const SizedBox(height: 17),
            TextFormField(
              controller: _amountController,
              autofocus: true,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(12)],
              decoration: const InputDecoration(labelText: 'Nominal', prefixText: 'Rp ', border: OutlineInputBorder(), hintText: '0'),
              validator: (value) {
                final amount = int.tryParse(value ?? '');
                if (amount == null || amount <= 0) return 'Masukkan nominal lebih dari Rp0.';
                return null;
              },
            ),
            const SizedBox(height: 12),
            TextFormField(controller: _categoryController, textCapitalization: TextCapitalization.sentences, decoration: const InputDecoration(labelText: 'Kategori', border: OutlineInputBorder()), validator: (value) => value == null || value.trim().isEmpty ? 'Kategori wajib diisi.' : null),
            const SizedBox(height: 12),
            TextField(controller: _noteController, textCapitalization: TextCapitalization.sentences, maxLength: 120, decoration: const InputDecoration(labelText: 'Catatan (opsional)', border: OutlineInputBorder())),
            const SizedBox(height: 8),
            SizedBox(width: double.infinity, child: FilledButton.icon(onPressed: _saving ? null : _submit, icon: _saving ? const SizedBox.square(dimension: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.check_rounded), label: Text(_saving ? 'Menyimpan...' : 'Simpan transaksi'), style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(50)))),
          ]),
        ),
      ),
    );
  }
}