import 'dart:io';
import 'dart:typed_data';

import 'backup_service.dart' show maxBackupBytes;

/// Bound the actual stream, not just the picker-reported size. A provider can
/// report an inaccurate size, or the file can grow while it is being read.
Future<Uint8List> readBackupFile(File file, {int limit = maxBackupBytes}) async {
  if (limit < 1) throw ArgumentError.value(limit, 'limit');
  final builder = BytesBuilder(copy: false);
  await for (final chunk in file.openRead(0, limit + 1)) {
    builder.add(chunk);
    if (builder.length > limit) {
      throw const FormatException('Backup melebihi batas ukuran yang diizinkan.');
    }
  }
  return builder.takeBytes();
}
