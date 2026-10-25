import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../app/theme/neo_theme.dart';
import '../core/utils/currency.dart';
import '../data/savings_transaction.dart';

class TransactionTile extends StatelessWidget {
  const TransactionTile(
      {required this.transaction, required this.hidden, super.key});

  final SavingsTransaction transaction;
  final bool hidden;

  @override
  Widget build(BuildContext context) {
    final positive = transaction.type == TransactionType.income ||
        transaction.type == TransactionType.withdrawal;
    final palette = NeoPalette.of(context);
    final tint = positive ? palette.primary : palette.secondary;
    final signedAmount =
        '${positive ? '+' : '-'}${hidden ? '••••' : formatRupiah(transaction.amount)}';
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 3, vertical: 2),
      leading: Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
              color: tint,
              border: Border.all(color: palette.border, width: 1.5)),
          child: Icon(
              positive ? Icons.south_west_rounded : Icons.north_east_rounded,
              color: palette.text,
              size: 19)),
      title: Text(transaction.category,
          style: const TextStyle(fontWeight: FontWeight.w700)),
      subtitle: Text(
          '${transaction.type.label} · ${DateFormat('d MMM, HH:mm', 'id_ID').format(transaction.createdAt)}'),
      trailing: Text(signedAmount,
          style: TextStyle(
              color: palette.text,
              backgroundColor: tint,
              fontWeight: FontWeight.w900)),
    );
  }
}
