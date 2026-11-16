import 'package:drift/drift.dart';
import '../core/utils/civil_date.dart';
import 'savings_database.dart';

class MoneyJournalEntry {
  const MoneyJournalEntry({required this.id, required this.date, required this.note});
  final int id;
  final CivilDate date;
  final String note;
}

class MoneyJournalRepository {
  MoneyJournalRepository(this.database);
  final SavingsDatabase database;
  Future<List<MoneyJournalEntry>> list() async {
    final rows = await database.customSelect('SELECT * FROM money_journal ORDER BY entry_date DESC, id DESC').get();
    return rows.map((r) => MoneyJournalEntry(id: r.read<int>('id'), date: CivilDate.parse(r.read<String>('entry_date')), note: r.read<String>('note'))).toList();
  }
  Future<void> save({int? id, required DateTime date, required String note}) async {
    final value = note.trim();
    if (value.isEmpty || value.length > 10000) throw ArgumentError('Catatan wajib diisi, maksimal 10000 karakter.');
    final key = CivilDate.from(date).key;
    if (id == null) {
      await database.customInsert('INSERT INTO money_journal (entry_date, note, updated_at) VALUES (?, ?, ?)', variables: [Variable.withString(key), Variable.withString(value), Variable.withInt(DateTime.now().millisecondsSinceEpoch)]);
    } else {
      final count = await database.customUpdate('UPDATE money_journal SET entry_date=?, note=?, updated_at=? WHERE id=?', variables: [Variable.withString(key), Variable.withString(value), Variable.withInt(DateTime.now().millisecondsSinceEpoch), Variable.withInt(id)]);
      if (count == 0) throw StateError('Catatan tidak ditemukan.');
    }
  }
  Future<void> delete(int id) async {
    final count = await database.customUpdate('DELETE FROM money_journal WHERE id=?', variables: [Variable.withInt(id)]);
    if (count == 0) throw StateError('Catatan tidak ditemukan.');
  }
}
