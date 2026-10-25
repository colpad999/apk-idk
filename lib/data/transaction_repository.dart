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

  Future<void> add({
    required TransactionType type,
    required int amount,
    required String category,
    required DateTime createdAt,
    String? note,
  }) async {
    if (amount <= 0 || amount > 999999999999) {
      throw ArgumentError.value(amount, 'amount', 'Nominal harus lebih dari Rp0.');
    }
    if (category.trim().isEmpty) {
      throw ArgumentError.value(category, 'category', 'Kategori wajib diisi.');
    }

    await _database.transaction(() async {
      final summaryRow = await _database.customSelect('''
        SELECT
          COALESCE(SUM(CASE WHEN type = 'income' THEN amount WHEN type = 'expense' THEN -amount WHEN type = 'deposit' THEN -amount WHEN type = 'withdrawal' THEN amount ELSE 0 END), 0) AS cash_balance,
          COALESCE(SUM(CASE WHEN type = 'deposit' THEN amount WHEN type = 'withdrawal' THEN -amount ELSE 0 END), 0) AS allocated_balance
        FROM savings_transactions
      ''').getSingle();
      final cashBalance = summaryRow.read<int>('cash_balance');
      final allocatedBalance = summaryRow.read<int>('allocated_balance');

      if (type.decreasesCash && amount > cashBalance) {
        throw StateError('Saldo kas tidak mencukupi untuk transaksi ini.');
      }
      if (type == TransactionType.withdrawal && amount > allocatedBalance) {
        throw StateError('Saldo tabungan yang dialokasikan tidak mencukupi.');
      }

      await _database.customInsert(
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
    });
  }
}