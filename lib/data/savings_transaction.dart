enum TransactionType {
  income,
  expense,
  deposit,
  withdrawal,
}

extension TransactionTypeLabel on TransactionType {
  String get label => switch (this) {
        TransactionType.income => 'Uang masuk',
        TransactionType.expense => 'Pengeluaran',
        TransactionType.deposit => 'Setoran tabungan',
        TransactionType.withdrawal => 'Penarikan tabungan',
      };

  String get databaseValue => name;

  bool get increasesCash =>
      this == TransactionType.income || this == TransactionType.withdrawal;

  bool get decreasesCash =>
      this == TransactionType.expense || this == TransactionType.deposit;
}

class SavingsTransaction {
  const SavingsTransaction({
    required this.id,
    required this.type,
    required this.amount,
    required this.category,
    required this.createdAt,
    this.note,
  });

  final int id;
  final TransactionType type;
  final int amount;
  final String category;
  final DateTime createdAt;
  final String? note;

  factory SavingsTransaction.fromRow(Map<String, Object?> row) {
    return SavingsTransaction(
      id: row['id']! as int,
      type: TransactionType.values.byName(row['type']! as String),
      amount: row['amount']! as int,
      category: row['category']! as String,
      createdAt: DateTime.fromMillisecondsSinceEpoch(row['created_at']! as int),
      note: row['note'] as String?,
    );
  }
}

class SavingsSummary {
  const SavingsSummary({
    required this.cashBalance,
    required this.allocatedBalance,
    required this.totalIncome,
    required this.totalExpense,
  });

  final int cashBalance;
  final int allocatedBalance;
  final int totalIncome;
  final int totalExpense;

  int get totalAssets => cashBalance + allocatedBalance;
}

class SavingGoal {
  const SavingGoal({
    required this.id,
    required this.name,
    required this.targetAmount,
    required this.allocatedAmount,
    required this.createdAt,
    this.deadline,
    this.coverPhotoPath,
  });

  final int id;
  final String name;
  final int targetAmount;
  final int allocatedAmount;
  final DateTime createdAt;
  final DateTime? deadline;
  final String? coverPhotoPath;

  double get progress => targetAmount <= 0
      ? 0
      : (allocatedAmount / targetAmount).clamp(0, 1).toDouble();
  int get remaining =>
      targetAmount > allocatedAmount ? targetAmount - allocatedAmount : 0;
}

class DailyFinancialActivity {
  const DailyFinancialActivity(
      {required this.date, required this.deposits, required this.expenses});

  final DateTime date;
  final int deposits;
  final int expenses;
}

class WeeklyFinancialActivity {
  const WeeklyFinancialActivity(
      {required this.days,
      required this.previousDeposits,
      required this.previousExpenses});

  final List<DailyFinancialActivity> days;
  final int previousDeposits;
  final int previousExpenses;

  int get deposits => days.fold(0, (sum, day) => sum + day.deposits);
  int get expenses => days.fold(0, (sum, day) => sum + day.expenses);
}
