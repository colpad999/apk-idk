import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../app/providers.dart';
import '../../data/habit.dart';
import '../../shared/neo_feedback.dart';

Future<bool> ensureHabitNotificationPermission(
    BuildContext context, WidgetRef ref) async {
  final service = ref.read(habitNotificationServiceProvider);
  if (await service.permissionGranted()) return true;
  if (!context.mounted) return false;
  final accepted = await confirmNeoAction(
    context,
    title: 'Izinkan pengingat lokal?',
    message:
        'Colpad memakai notifikasi untuk mengingatkan jadwal yang kamu pilih. '
        'Data tetap di perangkat. Pengingat biasa dapat tertunda oleh penghematan '
        'baterai Android; aplikasi tidak meminta izin alarm presisi.',
    confirmLabel: 'Lanjut ke izin',
  );
  if (!accepted) return false;
  final granted = await service.requestPermission();
  if (!granted && context.mounted) {
    showNeoMessage(context,
        'Izin notifikasi belum diberikan. Konfigurasi tetap disimpan; aktifkan izin di pengaturan Android untuk menerima pengingat.');
  }
  return granted;
}

Future<void> toggleHabitCompletion(
    BuildContext context, WidgetRef ref, Habit habit, DateTime date) async {
  if (habit.isComplete(date)) {
    final confirmed = await confirmNeoAction(
      context,
      title: 'Batalkan tanda selesai?',
      message:
          'Penyelesaian ${DateFormat('d MMMM yyyy', 'id_ID').format(date)} akan dihapus dari riwayat. Progres dihitung ulang.',
      confirmLabel: 'Batalkan selesai',
    );
    if (!confirmed || !context.mounted) return;
  }
  await guardNeoAction(context, () async {
    await ref
        .read(habitRepositoryProvider)
        .setCompletion(habit.id, date, !habit.isComplete(date));
    ref.invalidate(habitsProvider);
  });
}

Future<void> changeHabitActive(
    BuildContext context, WidgetRef ref, Habit habit, bool active) async {
  if (!active) {
    final confirmed = await confirmNeoAction(
      context,
      title: 'Jeda habit ini?',
      message:
          'Pengingat dihentikan sementara. Hari selama jeda tidak dianggap gagal dan tidak memutus streak.',
      confirmLabel: 'Jeda',
    );
    if (!confirmed || !context.mounted) return;
  }
  await guardNeoAction(context, () async {
    await ref.read(habitRepositoryProvider).setActive(habit.id, active);
    ref.invalidate(habitsProvider);
    final result =
        await ref.read(habitNotificationServiceProvider).syncHabit(habit.id);
    if (active && result.permissionDenied && context.mounted) {
      showNeoMessage(context,
          'Habit aktif kembali. Izin notifikasi belum diberikan, jadi pengingat belum dijadwalkan.');
    }
  }, success: active ? 'Habit aktif kembali.' : 'Habit dijeda.');
}

Future<bool> deleteHabit(
    BuildContext context, WidgetRef ref, Habit habit) async {
  final confirmed = await confirmNeoAction(
    context,
    title: 'Hapus habit?',
    message:
        '“${habit.name}”, riwayat penyelesaian, check-in, dan semua pengingatnya akan dihapus. Transaksi keuangan tidak terpengaruh.',
    confirmLabel: 'Hapus habit',
    destructive: true,
  );
  if (!confirmed || !context.mounted) return false;
  final result = await guardNeoAction<bool>(context, () async {
    await ref.read(habitRepositoryProvider).delete(habit.id);
    await ref.read(habitNotificationServiceProvider).cancelHabit(habit.id);
    ref.invalidate(habitsProvider);
    return true;
  }, success: 'Habit dihapus.');
  return result ?? false;
}
