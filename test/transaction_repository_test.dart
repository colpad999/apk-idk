import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:apk_idk/data/savings_database.dart';
import 'package:apk_idk/data/savings_transaction.dart';
import 'package:apk_idk/data/transaction_repository.dart';

void main() {
  late SavingsDatabase database;
  late TransactionRepository repository;

  setUp(() {
    database = SavingsDatabase.forTesting(NativeDatabase.memory());
    repository = TransactionRepository(database);
  });

  tearDown(() async => database.close());

  test('cash, allocation, and assets remain consistent', () async {
    await repository.add(type: TransactionType.income, amount: 100000, category: 'Gaji', createdAt: DateTime(2026, 1, 1));
    await repository.add(type: TransactionType.expense, amount: 15000, category: 'Makan', createdAt: DateTime(2026, 1, 2));
    await repository.add(type: TransactionType.deposit, amount: 25000, category: 'Tabungan', createdAt: DateTime(2026, 1, 3));

    var summary = await repository.summary();
    expect(summary.cashBalance, 60000);
    expect(summary.allocatedBalance, 25000);
    expect(summary.totalAssets, 85000);

    await repository.add(type: TransactionType.withdrawal, amount: 5000, category: 'Tarik tabungan', createdAt: DateTime(2026, 1, 4));
    summary = await repository.summary();
    expect(summary.cashBalance, 65000);
    expect(summary.allocatedBalance, 20000);
    expect(summary.totalAssets, 85000);
  });

  test('rejects non-positive amount and spending beyond available balance', () async {
    await expectLater(
      repository.add(type: TransactionType.income, amount: 0, category: 'Gaji', createdAt: DateTime.now()),
      throwsArgumentError,
    );
    await repository.add(type: TransactionType.income, amount: 10000, category: 'Gaji', createdAt: DateTime.now());

    await expectLater(
      repository.add(type: TransactionType.expense, amount: 10001, category: 'Belanja', createdAt: DateTime.now()),
      throwsStateError,
    );
    await expectLater(
      repository.add(type: TransactionType.withdrawal, amount: 1, category: 'Tarik', createdAt: DateTime.now()),
      throwsStateError,
    );
    expect((await repository.listLatest()).length, 1);
  });
}