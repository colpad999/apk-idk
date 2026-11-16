import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart';

import '../core/utils/civil_date.dart';
import '../data/habit.dart';
import '../data/savings_database.dart';
import 'goal_photo_storage.dart';

const backupFormat = 'colpad_savings_backup';
const backupVersion = 7;
const maxBackupBytes = 50 * 1024 * 1024;

class BackupExport {
  const BackupExport({required this.bytes, required this.missingPhotoPaths});
  final Uint8List bytes;
  final List<String> missingPhotoPaths;
}

class BackupRestoreResult {
  const BackupRestoreResult({required this.photos, required this.missingPhotos});
  final int photos, missingPhotos;
}

/// Versioned, validated JSON backup. Photos are embedded as bounded JPEG/base64
/// entries, never as arbitrary filesystem paths or executable archive entries.
/// Restore is intentionally limited to an empty database to avoid overwriting
/// financial history or silently merging incompatible ledgers.
class BackupService {
  BackupService({
    required SavingsDatabase database,
    required GoalPhotoStorage photos,
    DateTime Function()? clock,
  })  : _database = database,
        _photos = photos,
        _clock = clock ?? DateTime.now;

  final SavingsDatabase _database;
  final GoalPhotoStorage _photos;
  final DateTime Function() _clock;

  static const _tables = [
    'savings_transactions',
    'budget_categories',
    'budgets',
    'income_sources',
    'saving_goals',
    'goal_allocations',
    'habits',
    'habit_reminders',
    'habit_completions',
    'habit_pauses',
    'app_settings',
    'life_entries',
    'habit_checkins',
    'habit_counters',
    'habit_counter_days',
    'wishlist_items',
    'saving_challenges',
    'money_journal',
  ];

  Future<BackupExport> export() async {
    // Read all related tables in one SQLite snapshot. Otherwise a concurrent
    // transaction can leave an export with dangling or missing relationships.
    final data = await _database.transaction(() async {
      final snapshot = <String, Object?>{};
      for (final table in _tables) {
        final rows = await _database.customSelect('SELECT * FROM $table').get();
        snapshot[table] = rows.map((row) => Map<String, Object?>.from(row.data)).toList();
      }
      return snapshot;
    });
    final goals = (data['saving_goals']! as List).cast<Map<String, Object?>>();
    final photoEntries = <Map<String, Object?>>[];
    final missing = <String>[];
    final pathMap = <String, String>{};
    for (final goal in goals) {
      final original = goal['cover_photo_path'] as String?;
      if (original == null) continue;
      var key = pathMap[original];
      if (key == null) {
        key = GoalPhotoStorage.isManagedRelativePath(original)
            ? original
            : 'goal_covers/legacy_${pathMap.length + 1}.jpg';
        pathMap[original] = key;
        final file = await _photos.fileFor(original);
        try {
          if (file == null || !await file.exists() ||
              await file.length() > maxPhotoOutputBytes) {
            throw const FileSystemException('Foto tidak tersedia');
          }
          final bytes = await file.readAsBytes();
          photoEntries.add({'path': key, 'data': base64Encode(bytes)});
        } on Object {
          missing.add(goal['name'] as String? ?? original);
          photoEntries.add({'path': key, 'missing': true});
        }
      }
      goal['cover_photo_path'] = key;
    }
    final document = {
      'format': backupFormat,
      'version': backupVersion,
      'exported_at': _clock().toUtc().toIso8601String(),
      'data': data,
      'photos': photoEntries,
    };
    final bytes = Uint8List.fromList(utf8.encode(jsonEncode(document)));
    if (bytes.length > maxBackupBytes) {
      throw StateError('Backup melebihi 50 MB. Kurangi ukuran foto terlebih dahulu.');
    }
    return BackupExport(bytes: bytes, missingPhotoPaths: missing);
  }

  Future<BackupRestoreResult> restore(Uint8List bytes) async {
    if (bytes.isEmpty || bytes.length > maxBackupBytes) {
      throw const FormatException('Backup kosong atau melebihi 50 MB.');
    }
    final Object? decoded;
    try {
      decoded = jsonDecode(utf8.decode(bytes));
    } on Object {
      throw const FormatException('Backup bukan JSON yang valid.');
    }
    final document = _map(decoded, 'backup');
    if (document['format'] != backupFormat ||
        ![1, 2, 3, 4, 5, 6, backupVersion].contains(document['version'])) {
      throw const FormatException('Format atau versi backup tidak didukung.');
    }
    final data = _map(document['data'], 'data');
    if (document['version'] == 1) data['life_entries'] = <Object?>[];
    if (document['version'] == 1 || document['version'] == 2) {
      data['habit_checkins'] = <Object?>[];
    }
    if ([1, 2, 3].contains(document['version'])) {
      data['habit_counters'] = <Object?>[];
      data['habit_counter_days'] = <Object?>[];
    }
    if ([1, 2, 3, 4].contains(document['version'])) {
      data['wishlist_items'] = <Object?>[];
    }
    if ([1, 2, 3, 4, 5].contains(document['version'])) {
      data['saving_challenges'] = <Object?>[];
    }
    if ([1, 2, 3, 4, 5, 6].contains(document['version'])) {
      data['money_journal'] = <Object?>[];
    }
    final rows = _validateData(data);
    final photos = _validatePhotos(document['photos'], rows['saving_goals']!);

    await _ensureRestoreTargetEmpty();

    final written = <String>[];
    final restoredPaths = <String, String?>{};
    var missingCount = 0;
    try {
      for (final entry in photos.entries) {
        if (entry.value == null) {
          restoredPaths[entry.key] = null;
          missingCount++;
          continue;
        }
        final prepared = await processGoalPhoto(entry.value!);
        final path = await _photos.savePrepared(prepared.bytes);
        written.add(path);
        restoredPaths[entry.key] = path;
      }
      await _database.transaction(() async {
        // Recheck under the write transaction: the target may have changed
        // while photos were processed after the initial validation.
        await _ensureRestoreTargetEmpty();
        await _insertRows('savings_transactions', rows['savings_transactions']!,
            ['id', 'type', 'amount', 'category', 'note', 'created_at']);
        final categoryMap = await _restoreCategories(rows['budget_categories']!);
        for (final budget in rows['budgets']!) {
          await _insert('budgets', {
            ...budget,
            'category_id': categoryMap[budget['category_id']],
          }, ['id', 'category_id', 'month', 'limit_amount']);
        }
        await _insertRows('income_sources', rows['income_sources']!,
            ['id', 'name', 'created_at']);
        for (final goal in rows['saving_goals']!) {
          final photoKey = goal['cover_photo_path'] as String?;
          await _insert('saving_goals', {
            ...goal,
            'cover_photo_path': photoKey == null ? null : restoredPaths[photoKey],
          }, [
            'id', 'name', 'target_amount', 'deadline', 'created_at',
            'cover_photo_path', 'deleted_at'
          ]);
        }
        await _insertRows('goal_allocations', rows['goal_allocations']!,
            ['id', 'goal_id', 'transaction_id', 'amount', 'direction', 'created_at']);
        for (final habit in rows['habits']!) {
          await _insert('habits', {
            ...habit,
            'frequency': _frequency(habit['frequency'] as String),
          }, [
            'id', 'name', 'description', 'icon', 'color', 'frequency',
            'scheduled_days', 'target_per_week', 'start_date', 'end_date',
            'is_active', 'created_at'
          ]);
        }
        await _insertRows('habit_reminders', rows['habit_reminders']!, [
          'id', 'habit_id', 'minutes', 'days', 'start_date', 'recurrence',
          'enabled', 'sound', 'vibration', 'title', 'body', 'created_at'
        ]);
        await _insertRows('habit_completions', rows['habit_completions']!,
            ['id', 'habit_id', 'completion_date', 'created_at']);
        await _insertRows('habit_pauses', rows['habit_pauses']!,
            ['id', 'habit_id', 'start_date', 'end_date']);
        await _insertRows('money_journal', rows['money_journal']!, ['id', 'entry_date', 'note', 'updated_at']);
        await _insertRows('saving_challenges', rows['saving_challenges']!, ['id', 'goal_id', 'name', 'target_amount', 'start_at', 'end_at']);
        await _insertRows('wishlist_items', rows['wishlist_items']!, ['id', 'name', 'price', 'note', 'purchased', 'created_at']);
        await _insertRows('habit_counters', rows['habit_counters']!, ['habit_id', 'target', 'unit']);
        await _insertRows('habit_counter_days', rows['habit_counter_days']!, ['habit_id', 'local_date', 'amount', 'updated_at']);
        await _insertRows('habit_checkins', rows['habit_checkins']!,
            ['id', 'habit_id', 'recorded_at', 'local_date', 'note']);
        await _insertRows('life_entries', rows['life_entries']!,
            ['entry_date', 'journal', 'mood', 'mood_note', 'updated_at']);
        for (final setting in rows['app_settings']!) {
          await _database.customInsert(
            'INSERT INTO app_settings (key, value) VALUES (?, ?) '
            'ON CONFLICT(key) DO UPDATE SET value = excluded.value',
            variables: [
              Variable.withString(setting['key'] as String),
              Variable.withString(setting['value'] as String),
            ],
          );
        }
      });
      return BackupRestoreResult(
          photos: written.length, missingPhotos: missingCount);
    } catch (_) {
      for (final path in written) {
        try {
          await _photos.delete(path);
        } on Object {
          // Cleanup is best effort; a failed DB transaction restored no rows.
        }
      }
      rethrow;
    }
  }

  Future<void> _ensureRestoreTargetEmpty() async {
    for (final table in [
      'savings_transactions', 'budgets', 'income_sources', 'saving_goals', 'habits', 'life_entries', 'wishlist_items', 'saving_challenges', 'money_journal'
    ]) {
      final count = await _database
          .customSelect('SELECT COUNT(*) AS total FROM $table')
          .getSingle();
      if (count.read<int>('total') > 0) {
        throw StateError(
            'Restore hanya ke database kosong. Data yang ada tidak boleh ditimpa.');
      }
    }
  }

  Map<String, List<Map<String, Object?>>> _validateData(
      Map<String, Object?> data) {
    final result = <String, List<Map<String, Object?>>>{};
    const limits = {
      'savings_transactions': 100000,
      'budget_categories': 1000,
      'budgets': 20000,
      'income_sources': 10000,
      'saving_goals': 10000,
      'goal_allocations': 200000,
      'habits': 10000,
      'habit_reminders': 50000,
      'habit_completions': 500000,
      'habit_pauses': 100000,
      'app_settings': 100,
      'life_entries': 100000,
      'habit_checkins': 500000,
      'habit_counters': 10000,
      'habit_counter_days': 500000,
      'wishlist_items': 100000,
      'saving_challenges': 100000,
      'money_journal': 100000,
    };
    for (final table in _tables) {
      final list = _list(data[table], table);
      if (list.length > limits[table]!) {
        throw FormatException('Jumlah baris $table melebihi batas backup.');
      }
      result[table] = list.map((row) => _map(row, table)).toList();
    }
    _uniqueIds(result, 'savings_transactions');
    _uniqueIds(result, 'budget_categories');
    _uniqueIds(result, 'budgets');
    _uniqueIds(result, 'income_sources');
    _uniqueIds(result, 'saving_goals');
    _uniqueIds(result, 'goal_allocations');
    _uniqueIds(result, 'habits');
    _uniqueIds(result, 'habit_reminders');
    _uniqueIds(result, 'habit_completions');
    _uniqueIds(result, 'habit_pauses');
    _uniqueIds(result, 'habit_checkins');
    _uniqueIds(result, 'wishlist_items');
    _uniqueIds(result, 'saving_challenges');
    _uniqueIds(result, 'money_journal');

    final transactionIds = _ids(result['savings_transactions']!);
    final goalIds = _ids(result['saving_goals']!);
    final habitIds = _ids(result['habits']!);
    final categoryIds = _ids(result['budget_categories']!);
    for (final row in result['savings_transactions']!) {
      if (!['income', 'expense', 'deposit', 'withdrawal'].contains(row['type']) ||
          _string(row['category']).isEmpty) {
        throw const FormatException('Transaksi backup tidak valid.');
      }
      _amount(row['amount']);
      _integer(row['created_at'], 'created_at');
      _optionalString(row['note']);
    }
    final categoryNames = <String>{};
    for (final row in result['budget_categories']!) {
      if (!categoryNames.add(_string(row['name']))) {
        throw const FormatException('Kategori backup duplikat.');
      }
      _integer(row['sort_order'], 'sort_order');
    }
    final budgetKeys = <String>{};
    for (final row in result['budgets']!) {
      if (!categoryIds.contains(row['category_id']) ||
          !RegExp(r'^\d{4}-(0[1-9]|1[0-2])$').hasMatch(_string(row['month'])) ||
          !budgetKeys.add('${row['category_id']}:${row['month']}')) {
        throw const FormatException('Anggaran backup tidak valid.');
      }
      _amount(row['limit_amount']);
    }
    final sourceNames = <String>{};
    for (final row in result['income_sources']!) {
      if (!sourceNames.add(_string(row['name']))) {
        throw const FormatException('Sumber pemasukan backup duplikat.');
      }
      _integer(row['created_at'], 'created_at');
    }
    final goalNames = <String>{};
    for (final row in result['saving_goals']!) {
      final name = _string(row['name']);
      if (name.isEmpty || !goalNames.add(name)) {
        throw const FormatException('Nama target backup kosong atau duplikat.');
      }
      _amount(row['target_amount']);
      _integer(row['created_at'], 'created_at');
      _optionalInteger(row['deadline']);
      _optionalInteger(row['deleted_at']);
      final photo = _optionalString(row['cover_photo_path']);
      if (photo != null && !GoalPhotoStorage.isManagedRelativePath(photo)) {
        throw const FormatException('Path foto backup tidak valid.');
      }
    }
    final allocatedTransactions = <int>{};
    for (final row in result['goal_allocations']!) {
      if (!goalIds.contains(row['goal_id']) ||
          !transactionIds.contains(row['transaction_id']) ||
          !allocatedTransactions.add(row['transaction_id'] as int) ||
          !['allocate', 'release'].contains(row['direction'])) {
        throw const FormatException('Alokasi backup tidak valid.');
      }
      _amount(row['amount']);
      _integer(row['created_at'], 'created_at');
    }
    for (final row in result['habits']!) {
      final frequency = _frequency(_string(row['frequency']));
      _string(row['name'], empty: false);
      _string(row['description']);
      _string(row['icon'], empty: false);
      _integer(row['color'], 'color');
      _days(_string(row['scheduled_days']));
      final target = _integer(row['target_per_week'], 'target_per_week');
      if (target < 1 || target > 7) {
        throw const FormatException('Target mingguan backup tidak valid.');
      }
      final start = _date(row['start_date']);
      final end = row['end_date'] == null ? null : _date(row['end_date']);
      if (end != null && end.isBefore(start)) {
        throw const FormatException('Rentang tanggal habit tidak valid.');
      }
      _boolInt(row['is_active']);
      _integer(row['created_at'], 'created_at');
      if (frequency == 'weekly_days' &&
          _days(_string(row['scheduled_days'])).isEmpty) {
        throw const FormatException('Hari habit backup kosong.');
      }
    }
    final remindersPerHabit = <int, int>{};
    for (final row in result['habit_reminders']!) {
      final habitId = _integer(row['habit_id'], 'habit_id');
      if (!habitIds.contains(habitId)) {
        throw const FormatException('Pengingat yatim dalam backup.');
      }
      final count = remindersPerHabit.update(habitId, (value) => value + 1,
          ifAbsent: () => 1);
      if (count > 5) throw const FormatException('Terlalu banyak pengingat.');
      validateReminder(HabitReminder(
        minutes: _integer(row['minutes'], 'minutes'),
        days: _days(_string(row['days'])),
        startDate: _date(row['start_date']),
        recurrence: ReminderRecurrence.values.byName(_string(row['recurrence'])),
        enabled: _boolInt(row['enabled']),
        sound: _boolInt(row['sound']),
        vibration: _boolInt(row['vibration']),
        title: _string(row['title']),
        body: _string(row['body']),
      ));
      _integer(row['created_at'], 'created_at');
    }
    final completionKeys = <String>{};
    for (final row in result['habit_completions']!) {
      if (!habitIds.contains(row['habit_id']) ||
          !completionKeys.add('${row['habit_id']}:${_date(row['completion_date']).key}')) {
        throw const FormatException('Log penyelesaian backup tidak valid.');
      }
      _integer(row['created_at'], 'created_at');
    }
    for (final row in result['habit_pauses']!) {
      if (!habitIds.contains(row['habit_id'])) {
        throw const FormatException('Jeda habit backup tidak valid.');
      }
      final start = _date(row['start_date']);
      final end = row['end_date'] == null ? null : _date(row['end_date']);
      if (end != null && end.isBefore(start)) {
        throw const FormatException('Rentang jeda backup tidak valid.');
      }
    }
    for (final row in result['money_journal']!) {
      _date(row['entry_date']);
      final note = _string(row['note'], empty: false);
      if (note.trim().isEmpty || note.length > 10000) {
        throw const FormatException('Catatan keuangan backup tidak valid.');
      }
      _integer(row['updated_at'], 'updated_at');
    }
    for (final row in result['saving_challenges']!) {
      final name = _string(row['name'], empty: false);
      final start = _integer(row['start_at'], 'start_at');
      final end = _integer(row['end_at'], 'end_at');
      if (!goalIds.contains(row['goal_id']) || name.trim().isEmpty || name.length > 100 || end <= start) {
        throw const FormatException('Challenge backup tidak valid.');
      }
      _amount(row['target_amount']);
    }
    for (final row in result['wishlist_items']!) {
      final name = _string(row['name'], empty: false);
      final price = _integer(row['price'], 'price');
      if (name.trim().isEmpty || name.length > 100 || price < 0 || price > 1000000000000 || _string(row['note']).length > 500) {
        throw const FormatException('Wishlist backup tidak valid.');
      }
      _boolInt(row['purchased']);
      _integer(row['created_at'], 'created_at');
    }
    final counterIds = <int>{};
    for (final row in result['habit_counters']!) {
      final habitId = _integer(row['habit_id'], 'habit_id');
      final target = _integer(row['target'], 'target');
      final unit = _string(row['unit'], empty: false);
      if (!habitIds.contains(habitId) || !counterIds.add(habitId) ||
          target < 1 || target > 1000000 || unit.length > 30) {
        throw const FormatException('Target counter tidak valid.');
      }
    }
    final counterDates = <String>{};
    for (final row in result['habit_counter_days']!) {
      final habitId = _integer(row['habit_id'], 'habit_id');
      final date = _date(row['local_date']).key;
      final amount = _integer(row['amount'], 'amount');
      if (!counterIds.contains(habitId) || !counterDates.add('$habitId:$date') || amount < 0 || amount > 1000000) {
        throw const FormatException('Riwayat counter tidak valid.');
      }
      _integer(row['updated_at'], 'updated_at');
    }
    for (final row in result['habit_checkins']!) {
      if (!habitIds.contains(row['habit_id']) || _string(row['note']).length > 500) {
        throw const FormatException('Check-in habit backup tidak valid.');
      }
      _integer(row['recorded_at'], 'recorded_at');
      _date(row['local_date']);
    }
    final entryDates = <String>{};
    for (final row in result['life_entries']!) {
      if (!entryDates.add(_date(row['entry_date']).key)) {
        throw const FormatException('Tanggal jurnal duplikat.');
      }
      if (_string(row['journal']).length > 10000 || _string(row['mood_note']).length > 2000) {
        throw const FormatException('Catatan backup terlalu panjang.');
      }
      final mood = row['mood'];
      if (mood != null && (mood is! int || mood < 1 || mood > 5)) {
        throw const FormatException('Mood backup tidak valid.');
      }
      _integer(row['updated_at'], 'updated_at');
    }
    final settingKeys = <String>{};
    for (final row in result['app_settings']!) {
      final key = _string(row['key'], empty: false);
      if (key.length > 100 || !settingKeys.add(key) ||
          _string(row['value']).length > 1000) {
        throw const FormatException('Pengaturan backup tidak valid.');
      }
    }
    return result;
  }

  Map<String, Uint8List?> _validatePhotos(
      Object? value, List<Map<String, Object?>> goals) {
    final result = <String, Uint8List?>{};
    for (final item in _list(value, 'photos')) {
      final photo = _map(item, 'photo');
      final path = _string(photo['path'], empty: false);
      if (!GoalPhotoStorage.isManagedRelativePath(path) ||
          result.containsKey(path)) {
        throw const FormatException('Path foto backup duplikat atau tidak aman.');
      }
      if (photo['missing'] == true) {
        result[path] = null;
        continue;
      }
      final encoded = _string(photo['data'], empty: false);
      if (encoded.length > (maxPhotoOutputBytes * 1.4).ceil()) {
        throw const FormatException('Foto backup terlalu besar.');
      }
      try {
        final bytes = base64Decode(encoded);
        if (bytes.length > maxPhotoOutputBytes) {
          throw const FormatException('Foto backup terlalu besar.');
        }
        result[path] = bytes;
      } on FormatException {
        throw const FormatException('Data foto backup bukan base64 yang valid.');
      }
    }
    for (final goal in goals) {
      final path = goal['cover_photo_path'];
      if (path != null && !result.containsKey(path)) {
        throw const FormatException('Foto target tidak ditemukan dalam backup.');
      }
    }
    return result;
  }

  Future<Map<int, int>> _restoreCategories(
      List<Map<String, Object?>> categories) async {
    final current = await _database
        .customSelect('SELECT id, name FROM budget_categories')
        .get();
    final byName = {
      for (final row in current) row.read<String>('name'): row.read<int>('id')
    };
    final map = <int, int>{};
    for (final category in categories) {
      final name = category['name'] as String;
      var id = byName[name];
      if (id == null) {
        id = await _database.customInsert(
          'INSERT INTO budget_categories (name, sort_order) VALUES (?, ?)',
          variables: [
            Variable.withString(name),
            Variable.withInt(category['sort_order'] as int),
          ],
        );
        byName[name] = id;
      }
      map[category['id'] as int] = id;
    }
    return map;
  }

  Future<void> _insertRows(String table, List<Map<String, Object?>> rows,
      List<String> columns) async {
    for (final row in rows) {
      await _insert(table, row, columns);
    }
  }

  Future<void> _insert(
      String table, Map<String, Object?> row, List<String> columns) async {
    final variables = columns.map((column) {
      final value = row[column];
      return switch (value) {
        int value => Variable.withInt(value),
        String value => Variable.withString(value),
        null => const Variable<String>(null),
        _ => throw FormatException('Tipe data $table.$column tidak didukung.'),
      };
    }).toList();
    await _database.customInsert(
      'INSERT INTO $table (${columns.join(', ')}) '
      'VALUES (${List.filled(columns.length, '?').join(', ')})',
      variables: variables,
    );
  }

  void _uniqueIds(Map<String, List<Map<String, Object?>>> data, String table) {
    final ids = <int>{};
    for (final row in data[table]!) {
      final id = _integer(row['id'], 'id');
      if (id <= 0 || !ids.add(id)) {
        throw FormatException('ID $table tidak valid atau duplikat.');
      }
    }
  }

  Set<int> _ids(List<Map<String, Object?>> rows) =>
      rows.map((row) => row['id'] as int).toSet();
}

Map<String, Object?> _map(Object? value, String label) {
  if (value is! Map) throw FormatException('$label harus berupa objek.');
  return value.cast<String, Object?>();
}

List<Object?> _list(Object? value, String label) {
  if (value is! List) throw FormatException('$label harus berupa daftar.');
  return value;
}

String _string(Object? value, {bool empty = true}) {
  if (value is! String || (!empty && value.trim().isEmpty)) {
    throw const FormatException('Teks backup tidak valid.');
  }
  return value;
}

String? _optionalString(Object? value) => value == null ? null : _string(value);

int _integer(Object? value, String label) {
  if (value is! int) throw FormatException('$label harus berupa integer.');
  return value;
}

int? _optionalInteger(Object? value) =>
    value == null ? null : _integer(value, 'integer');

void _amount(Object? value) {
  final amount = _integer(value, 'amount');
  if (amount <= 0 || amount > 999999999999) {
    throw const FormatException('Nominal backup tidak valid.');
  }
}

bool _boolInt(Object? value) {
  final number = _integer(value, 'boolean');
  if (number != 0 && number != 1) {
    throw const FormatException('Boolean backup tidak valid.');
  }
  return number == 1;
}

CivilDate _date(Object? value) {
  try {
    return CivilDate.parse(_string(value, empty: false));
  } on Object {
    throw const FormatException('Tanggal backup tidak valid.');
  }
}

Set<int> _days(String value) {
  final result = <int>{};
  for (final part in value.split(',')) {
    final day = int.tryParse(part);
    if (day == null || day < 1 || day > 7 || !result.add(day)) {
      throw const FormatException('Hari backup tidak valid.');
    }
  }
  return result;
}

String _frequency(String value) => switch (value) {
      'daily' => 'daily',
      'weekly_days' || 'weeklyDays' => 'weekly_days',
      'times_per_week' || 'timesPerWeek' => 'times_per_week',
      _ => throw const FormatException('Frekuensi backup tidak valid.'),
    };
