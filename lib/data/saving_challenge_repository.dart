import 'package:drift/drift.dart';
import 'savings_database.dart';

class SavingChallenge {
  const SavingChallenge({required this.id, required this.goalId, required this.name, required this.goalName,
    required this.target, required this.progress, required this.endAt, required this.goalClosed});
  final int id, goalId, target, progress;
  final String name, goalName;
  final DateTime endAt;
  final bool goalClosed;
}

class SavingChallengeRepository {
  SavingChallengeRepository(this.db, {DateTime Function()? clock}) : clock = clock ?? DateTime.now;
  final SavingsDatabase db;
  final DateTime Function() clock;

  Future<List<SavingChallenge>> list() async {
    final rows = await db.customSelect('''
      SELECT c.*, g.name AS goal_name, g.deleted_at,
        COALESCE(SUM(CASE WHEN a.direction='allocate' THEN a.amount ELSE -a.amount END), 0) AS progress
      FROM saving_challenges c JOIN saving_goals g ON g.id=c.goal_id
      LEFT JOIN goal_allocations a ON a.goal_id=c.goal_id AND a.created_at >= c.start_at AND a.created_at < c.end_at AND a.created_at <= ?
      GROUP BY c.id ORDER BY c.start_at DESC, c.id DESC
    ''', variables: [Variable.withInt(clock().millisecondsSinceEpoch)]).get();
    return rows.map((r) => SavingChallenge(id: r.read<int>('id'), goalId: r.read<int>('goal_id'),
      name: r.read<String>('name'), goalName: r.read<String>('goal_name'), target: r.read<int>('target_amount'),
      progress: r.read<int>('progress'), endAt: DateTime.fromMillisecondsSinceEpoch(r.read<int>('end_at')),
      goalClosed: r.read<int?>('deleted_at') != null)).toList();
  }

  Future<void> create({required int goalId, required String name, required int target, required DateTime endDate}) async {
    final now = clock();
    final end = DateTime(endDate.year, endDate.month, endDate.day + 1);
    if (name.trim().isEmpty || name.trim().length > 100 || target < 1 || target > 999999999999 || !end.isAfter(now)) {
      throw ArgumentError('Isi nama, target positif, dan tanggal akhir yang belum lewat.');
    }
    await db.transaction(() async {
      final goal = await db.customSelect('SELECT id FROM saving_goals WHERE id=? AND deleted_at IS NULL', variables: [Variable.withInt(goalId)]).getSingleOrNull();
      if (goal == null) throw StateError('Target tabungan tidak tersedia.');
      await db.customInsert('INSERT INTO saving_challenges (goal_id, name, target_amount, start_at, end_at) VALUES (?, ?, ?, ?, ?)', variables: [
        Variable.withInt(goalId), Variable.withString(name.trim()), Variable.withInt(target), Variable.withInt(now.millisecondsSinceEpoch), Variable.withInt(end.millisecondsSinceEpoch)]);
    });
  }

  Future<void> delete(int id) async {
    final changed = await db.customUpdate('DELETE FROM saving_challenges WHERE id=?', variables: [Variable.withInt(id)]);
    if (changed == 0) throw StateError('Challenge tidak ditemukan.');
  }
}
