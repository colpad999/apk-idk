import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../core/utils/currency.dart';
import '../data/savings_transaction.dart';

class TransactionTile extends StatelessWidget {
  const TransactionTile({required this.transaction, required this.hidden, super.key});

  final SavingsTransaction transaction;
  final bool hidden;

  @override
  Widget build(BuildContext context) {
    final positive = transaction.type == TransactionType.income || transaction.type == TransactionType.withdrawal;
    final tint = positive ? const Color(0xFF35C99C) : const Color(0xFFFF8977);
    final signedAmount = '${positive ? '+' : '-'}${hidden ? '••••' : formatRupiah(transaction.amount)}';
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 3, vertical: 2),
      leading: CircleAvatar(backgroundColor: tint.withValues(alpha: .13), child: Icon(positive ? Icons.south_west_rounded : Icons.north_east_rounded, color: tint, size: 19)),
      title: Text(transaction.category, style: const TextStyle(fontWeight: FontWeight.w700)),
      subtitle: Text('${transaction.type.label} · ${DateFormat('d MMM, HH:mm', 'id_ID').format(transaction.createdAt)}'),
      trailing: Text(signedAmount, style: TextStyle(color: tint, fontWeight: FontWeight.w800)),
    );
  }
}