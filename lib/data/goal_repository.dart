import 'package:drift/drift.dart';
import 'package:drift/native.dart' show SqliteException;

import 'savings_database.dart';
import 'savings_transaction.dart';

class GoalAllocationEntry {
  const GoalAllocationEntry({
    required this.id,
    required this.transactionId,
    required this.amount,
    required this.isAllocation,
    required this.createdAt,
    required this.note,
  });
  final int id, transactionId, amount;
  final bool isAllocation;
  final DateTime createdAt;
  final String note;
}

class GoalRepository {
  GoalRepository(this._database);
  final SavingsDatabase _database;

  Future<List<SavingGoal>> list() async {
    final rows = await _database.customSelect('''
      SELECT g.id, g.name, g.target_amount, g.deadline, g.created_at, g.cover_photo_path,
        COALESCE(SUM(CASE WHEN a.direction = 'allocate' THEN a.amount ELSE -a.amount END), 0) AS allocated
      FROM saving_goals g
      LEFT JOIN goal_allocations a ON a.goal_id = g.id
      WHERE g.deleted_at IS NULL
      GROUP BY g.id
      ORDER BY g.deadline IS NULL, g.deadline, g.created_at DESC
    ''').get();
    return rows
        .map((row) => SavingGoal(
              id: row.read<int>('id'),
              name: row.read<String>('name'),
              targetAmount: row.read<int>('target_amount'),
              allocatedAmount: row.read<int>('allocated'),
              createdAt:
                  DateTime.fromMillisecondsSinceEpoch(row.read<int>('created_at')),
              deadline: row.read<int?>('deadline') == null
                  ? null
                  : DateTime.fromMillisecondsSinceEpoch(row.read<int>('deadline')),
              coverPhotoPath: row.read<String?>('cover_photo_path'),
            ))
        .toList();
  }

  Future<SavingGoal?> get(int id) async {
    for (final goal in await list()) {
      if (goal.id == id) return goal;
    }
    return null;
  }

  void _validate(String name, int targetAmount, String? coverPhotoPath) {
    if (name.trim().isEmpty || name.trim().length > 80) {
      throw ArgumentError('Nama target wajib diisi, maksimal 80 karakter.');
    }
    if (targetAmount <= 0 || targetAmount > 999999999999) {
      throw ArgumentError('Target harus lebih dari Rp0 dan maksimal 12 digit.');
    }
    if (coverPhotoPath != null &&
        !RegExp(r'^goal_covers/[A-Za-z0-9_-]+\.jpg$').hasMatch(coverPhotoPath)) {
      throw ArgumentError('Path foto harus berupa salinan persisten aplikasi.');
    }
  }

  Future<int> create({
    required String name,
    required int targetAmount,
    DateTime? deadline,
    String? coverPhotoPath,
  }) async {
    _validate(name, targetAmount, coverPhotoPath);
    try {
      return await _database.customInsert(
        'INSERT INTO saving_goals (name, target_amount, deadline, cover_photo_path, created_at) '
        'VALUES (?, ?, ?, ?, ?)',
        variables: [
          Variable.withString(name.trim()),
          Variable.withInt(targetAmount),
          Variable<int>(deadline?.millisecondsSinceEpoch),
          Variable<String>(coverPhotoPath),
          Variable.withInt(DateTime.now().millisecondsSinceEpoch),
        ],
      );
    } on SqliteException catch (error) {
      if (error.extendedResultCode == 2067) {
        throw StateError('Nama target sudah dipakai. Pilih nama lain.');
      }
      rethrow;
    }
  }

  /// Returns the previous photo path. The caller deletes it only after commit
  /// and only when no other goal references that same file.
  Future<String?> update({
    required int id,
    required String name,
    required int targetAmount,
    required DateTime? deadline,
    required String? coverPhotoPath,
  }) async {
    _validate(name, targetAmount, coverPhotoPath);
    return _database.transaction(() async {
      final row = await _database.customSelect(
        'SELECT cover_photo_path FROM saving_goals WHERE id = ? AND deleted_at IS NULL',
        variables: [Variable.withInt(id)],
      ).getSingleOrNull();
      if (row == null) throw StateError('Target tidak ditemukan.');
      try {
        await _database.customUpdate(
          'UPDATE saving_goals SET name=?, target_amount=?, deadline=?, cover_photo_path=? WHERE id=?',
          variables: [
            Variable.withString(name.trim()),
            Variable.withInt(targetAmount),
            Variable<int>(deadline?.millisecondsSinceEpoch),
            Variable<String>(coverPhotoPath),
            Variable.withInt(id),
          ],
        );
      } on SqliteException catch (error) {
        if (error.extendedResultCode == 2067) {
          throw StateError('Nama target sudah dipakai. Pilih nama lain.');
        }
        rethrow;
      }
      return row.read<String?>('cover_photo_path');
    });
  }

  Future<bool> isPhotoReferenced(String path) async {
    final row = await _database.customSelect(
      'SELECT (SELECT COUNT(*) FROM saving_goals WHERE cover_photo_path = ?) + '
      '(SELECT COUNT(*) FROM wishlist_items WHERE cover_photo_path = ?) AS total',
      variables: [Variable.withString(path), Variable.withString(path)],
    ).getSingle();
    return row.read<int>('total') > 0;
  }

  /// Closing a goal releases its remaining allocation back to cash atomically.
  /// Transactions and allocation history are retained; the goal is soft-deleted.
  Future<String?> delete(int id) => _database.transaction(() async {
        final goal = await get(id);
        if (goal == null) throw StateError('Target tidak ditemukan.');
        final now = DateTime.now().millisecondsSinceEpoch;
        if (goal.allocatedAmount > 0) {
          final transactionId = await _database.customInsert(
            'INSERT INTO savings_transactions (type, amount, category, note, created_at) '
            "VALUES ('withdrawal', ?, 'Tarik tabungan', ?, ?)",
            variables: [
              Variable.withInt(goal.allocatedAmount),
              Variable.withString('Penutupan target: ${goal.name}'),
              Variable.withInt(now),
            ],
          );
          await _database.customInsert(
            'INSERT INTO goal_allocations '
            '(goal_id, transaction_id, amount, direction, created_at) '
            "VALUES (?, ?, ?, 'release', ?)",
            variables: [
              Variable.withInt(id),
              Variable.withInt(transactionId),
              Variable.withInt(goal.allocatedAmount),
              Variable.withInt(now),
            ],
          );
        }
        await _database.customUpdate(
          'UPDATE saving_goals SET deleted_at = ?, cover_photo_path = NULL WHERE id = ?',
          variables: [Variable.withInt(now), Variable.withInt(id)],
        );
        return goal.coverPhotoPath;
      });

  Future<List<GoalAllocationEntry>> allocations(int goalId) async {
    final rows = await _database.customSelect(
      'SELECT a.*, t.note FROM goal_allocations a '
      'JOIN savings_transactions t ON t.id = a.transaction_id '
      'WHERE a.goal_id = ? ORDER BY a.created_at DESC, a.id DESC',
      variables: [Variable.withInt(goalId)],
    ).get();
    return rows
        .map((row) => GoalAllocationEntry(
              id: row.read<int>('id'),
              transactionId: row.read<int>('transaction_id'),
              amount: row.read<int>('amount'),
              isAllocation: row.read<String>('direction') == 'allocate',
              createdAt:
                  DateTime.fromMillisecondsSinceEpoch(row.read<int>('created_at')),
              note: row.read<String?>('note') ?? '',
            ))
        .toList();
  }
}
