import 'package:flutter/material.dart';
import '../../data/savings_transaction.dart';
import '../goals/goals_page.dart';
import '../transactions/add_transaction_sheet.dart';

/// The existing goal allocations are the virtual jars; no second ledger.
class VirtualJarsPage extends StatelessWidget {
  const VirtualJarsPage({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('VIRTUAL MONEY JAR')),
    body: GoalsPage(onAllocate: (TransactionType type, int goalId) {
      showModalBottomSheet<void>(context: context, isScrollControlled: true, useSafeArea: true,
        builder: (_) => AddTransactionSheet(initialType: type, initialGoalId: goalId));
    }),
  );
}
