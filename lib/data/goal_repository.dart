import 'package:drift/drift.dart';

import 'savings_database.dart';
import 'savings_transaction.dart';

class GoalRepository {
  GoalRepository(this._database);

  final SavingsDatabase _database;

  Future<List<SavingGoal>> list() async {
    final rows = await _database.customSelect('''
      SELECT g.id, g.name, g.target_amount, g.deadline, g.created_at, g.cover_photo_path,
        COALESCE(SUM(CASE WHEN a.direction = 'allocate' THEN a.amount ELSE -a.amount END), 0) AS allocated
      FROM saving_goals g
      LEFT JOIN goal_allocations a ON a.goal_id = g.id
      GROUP BY g.id
      ORDER BY g.deadline IS NULL, g.deadline, g.created_at DESC
    ''').get();
    return rows
        .map((row) => SavingGoal(
              id: row.read<int>('id'),
              name: row.read<String>('name'),
              targetAmount: row.read<int>('target_amount'),
              allocatedAmount: row.read<int>('allocated'),
              createdAt: DateTime.fromMillisecondsSinceEpoch(
                  row.read<int>('created_at')),
              deadline: row.read<int?>('deadline') == null
                  ? null
                  : DateTime.fromMillisecondsSinceEpoch(
                      row.read<int>('deadline')),
              coverPhotoPath: row.read<String?>('cover_photo_path'),
            ))
        .toList();
  }

  Future<int> create(
      {required String name,
      required int targetAmount,
      DateTime? deadline,
      String? coverPhotoPath}) async {
    final cleanName = name.trim();
    if (cleanName.isEmpty) {
      throw ArgumentError.value(name, 'name', 'Nama target wajib diisi.');
    }
    if (targetAmount <= 0 || targetAmount > 999999999999) {
      throw ArgumentError.value(
          targetAmount, 'targetAmount', 'Target harus lebih dari Rp0.');
    }
    return _database.customInsert(
      'INSERT INTO saving_goals (name, target_amount, deadline, cover_photo_path, created_at) VALUES (?, ?, ?, ?, ?)',
      variables: [
        Variable.withString(cleanName),
        Variable.withInt(targetAmount),
        if (deadline == null)
          const Variable<int>(null)
        else
          Variable.withInt(deadline.millisecondsSinceEpoch),
        if (coverPhotoPath == null)
          const Variable<String>(null)
        else
          Variable.withString(coverPhotoPath),
        Variable.withInt(DateTime.now().millisecondsSinceEpoch),
      ],
    );
  }
}
