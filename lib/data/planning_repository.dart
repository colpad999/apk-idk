import 'package:drift/drift.dart';

import 'savings_database.dart';

class BudgetLine {
  const BudgetLine(
      {required this.category, required this.limit, required this.spent});

  final String category;
  final int limit;
  final int spent;

  int get remaining => limit > spent ? limit - spent : 0;
  double get progress =>
      limit == 0 ? 0 : (spent / limit).clamp(0, 1).toDouble();
  bool get isNearLimit => limit > 0 && spent >= limit * .8;
}

class IncomeSourceTotal {
  const IncomeSourceTotal(
      {required this.name,
      required this.amount,
      required this.transactionCount});

  final String name;
  final int amount;
  final int transactionCount;
}

class PlanningRepository {
  PlanningRepository(this._database);

  final SavingsDatabase _database;

  static String monthKey(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}';

  Future<List<BudgetLine>> budgetsForMonth(DateTime month) async {
    final start = DateTime(month.year, month.month);
    final end = DateTime(month.year, month.month + 1);
    final rows = await _database.customSelect('''
      SELECT c.name AS category, COALESCE(b.limit_amount, 0) AS budget_limit,
        COALESCE(SUM(t.amount), 0) AS spent
      FROM budget_categories c
      LEFT JOIN budgets b ON b.category_id = c.id AND b.month = ?
      LEFT JOIN savings_transactions t ON t.category = c.name
        AND t.type = 'expense' AND t.created_at >= ? AND t.created_at < ?
      GROUP BY c.id, c.name, c.sort_order, b.limit_amount
      ORDER BY c.sort_order
    ''', variables: [
      Variable.withString(monthKey(month)),
      Variable.withInt(start.millisecondsSinceEpoch),
      Variable.withInt(end.millisecondsSinceEpoch),
    ]).get();

    return rows
        .map((row) => BudgetLine(
              category: row.read<String>('category'),
              limit: row.read<int>('budget_limit'),
              spent: row.read<int>('spent'),
            ))
        .toList();
  }

  Future<void> setBudget(
      {required String category,
      required DateTime month,
      required int limit}) async {
    if (limit <= 0 || limit > 999999999999) {
      throw ArgumentError.value(
          limit, 'limit', 'Anggaran harus lebih dari Rp0.');
    }
    await _database.transaction(() async {
      final row = await _database.customSelect(
        'SELECT id FROM budget_categories WHERE name = ?',
        variables: [Variable.withString(category)],
      ).getSingleOrNull();
      if (row == null) {
        throw ArgumentError.value(
            category, 'category', 'Kategori anggaran tidak ditemukan.');
      }
      await _database.customInsert(
        'INSERT INTO budgets (category_id, month, limit_amount) VALUES (?, ?, ?) '
        'ON CONFLICT(category_id, month) DO UPDATE SET limit_amount = excluded.limit_amount',
        variables: [
          Variable.withInt(row.read<int>('id')),
          Variable.withString(monthKey(month)),
          Variable.withInt(limit),
        ],
      );
    });
  }

  Future<List<IncomeSourceTotal>> incomeTotals(
      {required DateTime start, required DateTime end}) async {
    final rows = await _database.customSelect('''
      SELECT category AS source, SUM(amount) AS total, COUNT(*) AS transaction_count
      FROM savings_transactions
      WHERE type = 'income' AND created_at >= ? AND created_at < ?
      GROUP BY category
      ORDER BY total DESC, source COLLATE NOCASE
    ''', variables: [
      Variable.withInt(start.millisecondsSinceEpoch),
      Variable.withInt(end.millisecondsSinceEpoch),
    ]).get();

    return rows
        .map((row) => IncomeSourceTotal(
              name: row.read<String>('source'),
              amount: row.read<int>('total'),
              transactionCount: row.read<int>('transaction_count'),
            ))
        .toList();
  }

  Future<List<String>> knownIncomeSources() async {
    final rows = await _database
        .customSelect(
            'SELECT name FROM income_sources ORDER BY name COLLATE NOCASE')
        .get();
    return rows.map((row) => row.read<String>('name')).toList();
  }
}
