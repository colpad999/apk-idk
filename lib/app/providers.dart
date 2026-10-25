import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/savings_database.dart';
import '../data/savings_transaction.dart';
import '../data/transaction_repository.dart';

final savingsDatabaseProvider = Provider<SavingsDatabase>((ref) {
  final database = SavingsDatabase();
  ref.onDispose(database.close);
  return database;
});

final transactionRepositoryProvider = Provider<TransactionRepository>((ref) {
  return TransactionRepository(ref.watch(savingsDatabaseProvider));
});

final transactionsProvider = FutureProvider<List<SavingsTransaction>>((ref) {
  return ref.watch(transactionRepositoryProvider).listLatest();
});

final savingsSummaryProvider = FutureProvider<SavingsSummary>((ref) {
  return ref.watch(transactionRepositoryProvider).summary();
});

final themeModeProvider = StateProvider<ThemeMode>((ref) => ThemeMode.dark);
final hideBalanceProvider = StateProvider<bool>((ref) => false);