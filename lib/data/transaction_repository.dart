import 'package:drift/drift.dart';

import 'savings_database.dart';
import 'savings_transaction.dart';

class TransactionRepository {
  TransactionRepository(this._database);

  final SavingsDatabase _database;

  Future<List<SavingsTransaction>> listLatest({int limit = 100}) async {
    final rows = await _database.customSelect(
      'SELECT * FROM savings_transactions ORDER BY created_at DESC, id DESC LIMIT ?',
      variables: [Variable.withInt(limit)],
    ).get();
    return rows.map((row) => SavingsTransaction.fromRow(row.data)).toList();
  }

  Future<SavingsSummary> summary() async {
    final row = await _database.customSelect('''
      SELECT
        COALESCE(SUM(CASE WHEN type = 'income' THEN amount WHEN type = 'expense' THEN -amount WHEN type = 'deposit' THEN -amount WHEN type = 'withdrawal' THEN amount ELSE 0 END), 0) AS cash_balance,
        COALESCE(SUM(CASE WHEN type = 'deposit' THEN amount WHEN type = 'withdrawal' THEN -amount ELSE 0 END), 0) AS allocated_balance,
        COALESCE(SUM(CASE WHEN type = 'income' THEN amount ELSE 0 END), 0) AS total_income,
        COALESCE(SUM(CASE WHEN type = 'expense' THEN amount ELSE 0 END), 0) AS total_expense
      FROM savings_transactions
    ''').getSingle();

    return SavingsSummary(
      cashBalance: row.read<int>('cash_balance'),
      allocatedBalance: row.read<int>('allocated_balance'),
      totalIncome: row.read<int>('total_income'),
      totalExpense: row.read<int>('total_expense'),
    );
  }

  Future<WeeklyFinancialActivity> weeklyActivity(DateTime date) async {
    final today = DateTime(date.year, date.month, date.day);
    final mondayOffset = today.weekday - DateTime.monday;
    final weekStart = today.subtract(Duration(days: mondayOffset));
    final previousStart = weekStart.subtract(const Duration(days: 7));
    final nextWeek = weekStart.add(const Duration(days: 7));
    final rows = await _database.customSelect('''
      SELECT date(created_at / 1000, 'unixepoch', 'localtime') AS activity_day,
        SUM(CASE WHEN type = 'deposit' THEN amount ELSE 0 END) AS deposits,
        SUM(CASE WHEN type = 'expense' THEN amount ELSE 0 END) AS expenses
      FROM savings_transactions
      WHERE created_at >= ? AND created_at < ? AND type IN ('deposit', 'expense')
      GROUP BY activity_day
    ''', variables: [
      Variable.withInt(previousStart.millisecondsSinceEpoch),
      Variable.withInt(nextWeek.millisecondsSinceEpoch),
    ]).get();

    final byDay = <String, (int, int)>{};
    for (final row in rows) {
      byDay[row.read<String>('activity_day')] =
          (row.read<int>('deposits'), row.read<int>('expenses'));
    }
    final days = <DailyFinancialActivity>[];
    var previousDeposits = 0;
    var previousExpenses = 0;
    for (var offset = -7; offset < 7; offset++) {
      final day = weekStart.add(Duration(days: offset));
      final key =
          '${day.year.toString().padLeft(4, '0')}-${day.month.toString().padLeft(2, '0')}-${day.day.toString().padLeft(2, '0')}';
      final (deposits, expenses) = byDay[key] ?? (0, 0);
      if (offset < 0) {
        previousDeposits += deposits;
        previousExpenses += expenses;
      } else {
        days.add(DailyFinancialActivity(
            date: day, deposits: deposits, expenses: expenses));
      }
    }
    return WeeklyFinancialActivity(
        days: days,
        previousDeposits: previousDeposits,
        previousExpenses: previousExpenses);
  }

  Future<void> add({
    required TransactionType type,
    required int amount,
    required String category,
    required DateTime createdAt,
    String? note,
    int? goalId,
  }) async {
    if (amount <= 0 || amount > 999999999999) {
      throw ArgumentError.value(
          amount, 'amount', 'Nominal harus lebih dari Rp0.');
    }
    if (category.trim().isEmpty) {
      throw ArgumentError.value(category, 'category', 'Kategori wajib diisi.');
    }
    if (goalId != null &&
        type != TransactionType.deposit &&
        type != TransactionType.withdrawal) {
      throw ArgumentError.value(goalId, 'goalId',
          'Target hanya dapat dipilih untuk setoran atau penarikan.');
    }

    await _database.transaction(() async {
      if (type == TransactionType.income) {
        await _database.customInsert(
          'INSERT OR IGNORE INTO income_sources (name, created_at) VALUES (?, ?)',
          variables: [
            Variable.withString(category.trim()),
            Variable.withInt(createdAt.millisecondsSinceEpoch),
          ],
        );
      }
      final summaryRow = await _database.customSelect('''
        SELECT
          COALESCE(SUM(CASE WHEN type = 'income' THEN amount WHEN type = 'expense' THEN -amount WHEN type = 'deposit' THEN -amount WHEN type = 'withdrawal' THEN amount ELSE 0 END), 0) AS cash_balance,
          COALESCE(SUM(CASE WHEN type = 'deposit' THEN amount WHEN type = 'withdrawal' THEN -amount ELSE 0 END), 0) AS allocated_balance
        FROM savings_transactions
      ''').getSingle();
      final cashBalance = summaryRow.read<int>('cash_balance');
      final allocatedBalance = summaryRow.read<int>('allocated_balance');
      var goalAllocated = 0;
      if (goalId != null) {
        final goalRow = await _database.customSelect(
          'SELECT id FROM saving_goals WHERE id = ?',
          variables: [Variable.withInt(goalId)],
        ).getSingleOrNull();
        if (goalRow == null) {
          throw ArgumentError.value(
              goalId, 'goalId', 'Target tabungan tidak ditemukan.');
        }
        final allocationRow = await _database.customSelect('''
          SELECT COALESCE(SUM(CASE WHEN direction = 'allocate' THEN amount ELSE -amount END), 0) AS allocated
          FROM goal_allocations WHERE goal_id = ?
        ''', variables: [Variable.withInt(goalId)]).getSingle();
        goalAllocated = allocationRow.read<int>('allocated');
      }

      if (type.decreasesCash && amount > cashBalance) {
        throw StateError('Saldo kas tidak mencukupi untuk transaksi ini.');
      }
      if (type == TransactionType.withdrawal) {
        final available = goalId == null
            ? allocatedBalance - await _allocatedToGoals()
            : goalAllocated;
        if (amount > available) {
          throw StateError('Saldo tabungan yang dialokasikan tidak mencukupi.');
        }
      }

      final transactionId = await _database.customInsert(
        'INSERT INTO savings_transactions (type, amount, category, note, created_at) '
        'VALUES (?, ?, ?, ?, ?)',
        variables: [
          Variable.withString(type.databaseValue),
          Variable.withInt(amount),
          Variable.withString(category.trim()),
          Variable.withString(note?.trim() ?? ''),
          Variable.withInt(createdAt.millisecondsSinceEpoch),
        ],
      );
      if (goalId != null &&
          (type == TransactionType.deposit ||
              type == TransactionType.withdrawal)) {
        await _database.customInsert(
          'INSERT INTO goal_allocations (goal_id, transaction_id, amount, direction, created_at) VALUES (?, ?, ?, ?, ?)',
          variables: [
            Variable.withInt(goalId),
            Variable.withInt(transactionId),
            Variable.withInt(amount),
            Variable.withString(
                type == TransactionType.deposit ? 'allocate' : 'release'),
            Variable.withInt(createdAt.millisecondsSinceEpoch),
          ],
        );
      }
    });
  }

  Future<int> _allocatedToGoals() async {
    final row = await _database.customSelect('''
      SELECT COALESCE(SUM(CASE WHEN direction = 'allocate' THEN amount ELSE -amount END), 0) AS allocated
      FROM goal_allocations
    ''').getSingle();
    return row.read<int>('allocated');
  }
}
