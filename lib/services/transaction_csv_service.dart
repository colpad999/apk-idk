import 'dart:convert';
import 'dart:typed_data';

import '../data/savings_database.dart';

/// Exports the entire ledger, not the limited dashboard/history query.
/// Text beginning with spreadsheet formula characters is prefixed with an
/// apostrophe for safe opening in spreadsheet software.
class TransactionCsvService {
  TransactionCsvService(this.database);
  final SavingsDatabase database;

  Future<Uint8List> export() async {
    final rows = await database.customSelect('''
      SELECT t.id, t.type, t.amount, t.category, t.note, t.created_at,
             a.goal_id, g.name AS goal_name, a.direction
      FROM savings_transactions t
      LEFT JOIN goal_allocations a ON a.transaction_id = t.id
      LEFT JOIN saving_goals g ON g.id = a.goal_id
      ORDER BY t.created_at ASC, t.id ASC
    ''').get();
    final output = StringBuffer('id,type,amount,category,note,created_at_local,goal_id,goal_name,allocation_direction\r\n');
    for (final row in rows) {
      final values = [
        row.read<int>('id').toString(), row.read<String>('type'),
        row.read<int>('amount').toString(), _safe(row.read<String>('category')),
        _safe(row.read<String?>('note') ?? ''),
        DateTime.fromMillisecondsSinceEpoch(row.read<int>('created_at')).toIso8601String(),
        row.read<int?>('goal_id')?.toString() ?? '',
        _safe(row.read<String?>('goal_name') ?? ''), row.read<String?>('direction') ?? '',
      ];
      output.write('${values.map(_quote).join(',')}\r\n');
    }
    return Uint8List.fromList(utf8.encode(output.toString()));
  }

  static String _safe(String value) {
    final trimmed = value.trimLeft();
    if (trimmed.isNotEmpty && '=+-@\t\r'.contains(trimmed[0])) return "'$value";
    return value;
  }

  static String _quote(String value) => '"${value.replaceAll('"', '""')}"';
}
