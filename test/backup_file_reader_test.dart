import 'dart:io';

import 'package:apk_idk/services/backup_file_reader.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('reads within the real limit and rejects larger files', () async {
    final dir = await Directory.systemTemp.createTemp('backup_reader_');
    try {
      final file = File('${dir.path}/backup.json');
      await file.writeAsBytes([1, 2, 3, 4]);
      expect(await readBackupFile(file, limit: 4), [1, 2, 3, 4]);
      await expectLater(readBackupFile(file, limit: 3), throwsFormatException);
      await expectLater(readBackupFile(file, limit: 0), throwsArgumentError);
      await file.writeAsBytes([]);
      expect(await readBackupFile(file, limit: 4), isEmpty);
    } finally { await dir.delete(recursive: true); }
  });
}
