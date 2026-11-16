import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../app/providers.dart';
import '../../app/theme/neo_theme.dart';
import '../../services/backup_service.dart';
import '../../services/transaction_csv_service.dart';
import '../../shared/neo_components.dart';
import '../../shared/neo_feedback.dart';

class BackupPage extends ConsumerStatefulWidget {
  const BackupPage({super.key});
  @override
  ConsumerState<BackupPage> createState() => _BackupPageState();
}

class _BackupPageState extends ConsumerState<BackupPage> {
  bool _busy = false;

  BackupService get _service => BackupService(
        database: ref.read(savingsDatabaseProvider),
        photos: ref.read(goalPhotoStorageProvider),
      );

  Future<void> _export() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final export = await _service.export();
      final name = 'colpad-backup-${DateFormat('yyyyMMdd-HHmm').format(DateTime.now())}.json';
      final saved = await FilePicker.platform.saveFile(
        dialogTitle: 'Simpan backup Colpad',
        fileName: name,
        type: FileType.custom,
        allowedExtensions: ['json'],
        bytes: export.bytes,
      );
      if (!mounted) return;
      if (saved == null) {
        showNeoMessage(context, 'Penyimpanan backup dibatalkan.');
      } else if (export.missingPhotoPaths.isNotEmpty) {
        showNeoMessage(context,
            'Backup tersimpan, tetapi foto untuk ${export.missingPhotoPaths.join(', ')} tidak tersedia dan tidak ikut dicadangkan.');
      } else {
        showNeoMessage(context, 'Backup tersimpan, termasuk foto target yang tersedia.');
      }
    } catch (error) {
      if (mounted) showNeoMessage(context, friendlyError(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _exportCsv() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final bytes = await TransactionCsvService(ref.read(savingsDatabaseProvider)).export();
      final saved = await FilePicker.platform.saveFile(
        dialogTitle: 'Ekspor transaksi CSV',
        fileName: 'colpad-transaksi-${DateFormat('yyyyMMdd-HHmm').format(DateTime.now())}.csv',
        type: FileType.custom, allowedExtensions: ['csv'], bytes: bytes,
      );
      if (mounted) {
        showNeoMessage(context, saved == null ? 'Ekspor CSV dibatalkan.' : 'CSV transaksi tersimpan.');
      }
    } catch (error) {
      if (mounted) showNeoMessage(context, friendlyError(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _import() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final picked = await FilePicker.platform.pickFiles(
        dialogTitle: 'Pilih backup Colpad (.json)',
        type: FileType.custom,
        allowedExtensions: ['json'],
        allowMultiple: false,
      );
      if (picked == null || !mounted) return;
      final file = picked.files.single;
      if (file.size > maxBackupBytes) {
        throw const FormatException('Backup melebihi 50 MB.');
      }
      final Uint8List bytes;
      if (file.bytes != null) {
        bytes = file.bytes!;
      } else if (file.path != null) {
        bytes = await File(file.path!).readAsBytes();
      } else {
        throw const FormatException('Berkas backup tidak dapat dibaca.');
      }
      if (!mounted) return;
      final confirmed = await confirmNeoAction(
        context,
        title: 'Pulihkan backup ini?',
        message:
            'Restore hanya diterima pada database kosong. Seluruh transaksi, anggaran, target, foto, habit, dan pengingat dalam backup akan dipulihkan. Data yang sudah ada tidak akan ditimpa.',
        confirmLabel: 'Pulihkan',
      );
      if (!confirmed) return;
      final result = await _service.restore(bytes);
      ref.invalidate(transactionsProvider);
      ref.invalidate(savingsSummaryProvider);
      ref.invalidate(weeklyActivityProvider);
      ref.invalidate(savingGoalsProvider);
      ref.invalidate(budgetsProvider);
      ref.invalidate(incomeSourcesProvider);
      ref.invalidate(habitsProvider);
      ref.invalidate(habitNotificationsEnabledProvider);
      try {
        await ref.read(habitNotificationServiceProvider).syncAll();
      } catch (_) {
        // Data restore succeeded even if this device cannot schedule alarms.
      }
      if (mounted) {
        showNeoMessage(context,
            'Backup dipulihkan. ${result.photos} foto tersedia${result.missingPhotos > 0 ? '; ${result.missingPhotos} foto ditandai hilang di backup, target tetap dibuat tanpa foto' : ''}.');
      }
    } catch (error) {
      if (mounted) showNeoMessage(context, friendlyError(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = NeoPalette.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('BACKUP & RESTORE')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 30),
        children: [
          Text('Data lokal, tetap terjaga.', style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 6),
          Text('Backup JSON tervalidasi berisi catatan keuangan, habit, check-in, counter, wishlist, challenge, jurnal, mood, pengaturan, dan foto target.',
              style: TextStyle(color: palette.muted)),
          const SizedBox(height: 17),
          NeoCard(
            color: palette.primary,
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('FOTO IKUT DICADANGKAN', style: TextStyle(color: Color(0xFF171717), fontWeight: FontWeight.w900)),
              const SizedBox(height: 7),
              const Text('Salinan JPEG dimasukkan ke backup. Jika file foto hilang, backup tetap dibuat dan target dipulihkan tanpa foto dengan pemberitahuan.',
                  style: TextStyle(color: Color(0xFF171717), fontSize: 12)),
              const SizedBox(height: 13),
              FilledButton.icon(
                onPressed: _busy ? null : _export,
                icon: const Icon(Icons.upload_file_outlined),
                label: Text(_busy ? 'Memproses...' : 'Buat backup'),
              ),
            ]),
          ),
          const SizedBox(height: 14),
          NeoCard(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const NeoSectionTitle('PULIHKAN'),
              const SizedBox(height: 8),
              Text('Hanya untuk database kosong, misalnya instalasi baru. Backup divalidasi sebelum ditulis dan dipulihkan dalam satu transaksi database.',
                  style: TextStyle(color: palette.muted)),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: _busy ? null : _import,
                icon: const Icon(Icons.restore),
                label: const Text('Pilih backup untuk dipulihkan'),
              ),
            ]),
          ),
          const SizedBox(height: 14),
          NeoCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const NeoSectionTitle('EKSPOR TRANSAKSI CSV'),
            const SizedBox(height: 8),
            const Text('Seluruh transaksi dan alokasi tujuan. Teks yang menyerupai rumus spreadsheet diberi awalan apostrof demi keamanan. CSV bukan backup penuh.'),
            const SizedBox(height: 12),
            OutlinedButton.icon(onPressed: _busy ? null : _exportCsv, icon: const Icon(Icons.table_chart_outlined), label: const Text('Ekspor CSV')),
          ])),
          const SizedBox(height: 14),
          NeoCard(
            color: palette.highlight,
            child: const Text('Simpan backup di tempat privat. Berkas berisi catatan keuangan dan foto pribadi, tanpa enkripsi tambahan.',
                style: TextStyle(color: Color(0xFF171717), fontWeight: FontWeight.w800)),
          ),
        ],
      ),
    );
  }
}
