import 'dart:convert';

import 'package:apk_idk/data/goal_repository.dart';
import 'package:apk_idk/data/savings_database.dart';
import 'package:apk_idk/data/savings_transaction.dart';
import 'package:apk_idk/data/transaction_repository.dart';
import 'package:apk_idk/services/transaction_csv_service.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('exports all transactions, allocation metadata and safe escaped text', () async {
    final database = SavingsDatabase.forTesting(NativeDatabase.memory());
    try {
      final ledger = TransactionRepository(database);
      final goal = await GoalRepository(database).create(name: 'Sepeda', targetAmount: 1000);
      for (var index = 0; index < 101; index++) {
        await ledger.add(type: TransactionType.income, amount: 10,
          category: 'Saku', createdAt: DateTime(2026, 1, 1, 0, index));
      }
      await ledger.add(type: TransactionType.deposit, amount: 50,
        category: 'Tabungan', note: '=CMD("bad"), baris', goalId: goal, createdAt: DateTime(2026, 1, 2));
      final csv = utf8.decode(await TransactionCsvService(database).export());
      expect(csv.split('\r\n'), hasLength(104)); // header, 102 rows, trailing empty line
      expect(csv, contains('"deposit","50","Tabungan"'));
      expect(csv, contains('"\'=CMD(""bad""), baris"'));
      expect(csv, contains('"Sepeda","allocate"'));
      final summary = await ledger.summary();
      expect(summary.totalIncome, 1010);
      expect(summary.totalExpense, 0);
      expect(summary.totalAssets, 1010);
    } finally {
      await database.close();
    }
  });
}
