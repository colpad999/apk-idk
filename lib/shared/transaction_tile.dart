import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../app/theme/neo_theme.dart';
import '../core/utils/currency.dart';
import '../data/savings_transaction.dart';

class TransactionTile extends StatelessWidget {
  const TransactionTile({required this.transaction, required this.hidden, this.onTap, super.key});
  final SavingsTransaction transaction;
  final bool hidden;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final positive = transaction.type == TransactionType.income || transaction.type == TransactionType.withdrawal;
    final palette = NeoPalette.of(context);
    final tint = positive ? palette.primary : palette.secondary;
    final signedAmount = '${positive ? '+' : '-'}${hidden ? '••••' : formatRupiah(transaction.amount)}';
    final note = transaction.note?.trim();
    return ListTile(
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 3),
      leading: Container(width: 44, height: 44,
        decoration: BoxDecoration(color: tint, shape: BoxShape.circle),
        child: Icon(positive ? Icons.south_west_rounded : Icons.north_east_rounded, color: palette.text, size: 20)),
      title: Text(transaction.category, maxLines: 1, overflow: TextOverflow.ellipsis,
        style: Theme.of(context).textTheme.titleMedium),
      subtitle: Text('${transaction.type.label} · ${DateFormat('HH:mm', 'id_ID').format(transaction.createdAt)}${note == null || note.isEmpty ? '' : ' · $note'}',
        maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(color: palette.muted, fontSize: 11)),
      trailing: ConstrainedBox(constraints: BoxConstraints(maxWidth: MediaQuery.sizeOf(context).width * .34),
        child: Text(signedAmount, textAlign: TextAlign.right, maxLines: 2,
          style: TextStyle(color: positive ? const Color(0xFF36520C) : palette.text, fontFamily: 'SpaceGrotesk', fontWeight: FontWeight.w700))),
    );
  }
}
