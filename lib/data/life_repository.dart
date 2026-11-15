import 'package:drift/drift.dart';

import '../core/utils/civil_date.dart';
import 'savings_database.dart';

class LifeEntry {
  const LifeEntry({required this.date, required this.journal, required this.mood, required this.moodNote});
  final CivilDate date;
  final String journal, moodNote;
  final int? mood;
}

/// One local civil day per entry. Journal and mood are independently editable.
class LifeRepository {
  LifeRepository(this.database);
  final SavingsDatabase database;

  Future<List<LifeEntry>> list() async {
    final rows = await database.customSelect('SELECT * FROM life_entries ORDER BY entry_date DESC').get();
    return rows.map((row) => LifeEntry(
      date: CivilDate.parse(row.read<String>('entry_date')),
      journal: row.read<String>('journal'), mood: row.read<int?>('mood'),
      moodNote: row.read<String>('mood_note'),
    )).toList();
  }

  Future<void> save(DateTime date, String journal, int? mood, String moodNote) async {
    if (journal.length > 10000 || moodNote.length > 2000 || (mood != null && (mood < 1 || mood > 5))) {
      throw ArgumentError('Catatan terlalu panjang atau mood tidak valid.');
    }
    final key = CivilDate.from(date).key;
    if (journal.trim().isEmpty && mood == null && moodNote.trim().isEmpty) {
      await delete(date);
      return;
    }
    await database.customInsert('''
      INSERT INTO life_entries (entry_date, journal, mood, mood_note, updated_at)
      VALUES (?, ?, ?, ?, ?)
      ON CONFLICT(entry_date) DO UPDATE SET journal=excluded.journal,
        mood=excluded.mood, mood_note=excluded.mood_note, updated_at=excluded.updated_at
    ''', variables: [Variable.withString(key), Variable.withString(journal.trim()),
      Variable<int>(mood), Variable.withString(moodNote.trim()), Variable.withInt(DateTime.now().millisecondsSinceEpoch)]);
  }

  Future<void> delete(DateTime date) async {
    await database.customUpdate('DELETE FROM life_entries WHERE entry_date = ?',
      variables: [Variable.withString(CivilDate.from(date).key)]);
  }
}
