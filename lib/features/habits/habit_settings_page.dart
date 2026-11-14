import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../app/theme/neo_theme.dart';
import '../../shared/neo_components.dart';
import '../../shared/neo_feedback.dart';
import 'habit_actions.dart';

class HabitSettingsPage extends ConsumerStatefulWidget {
  const HabitSettingsPage({super.key});
  @override
  ConsumerState<HabitSettingsPage> createState() => _HabitSettingsPageState();
}

class _HabitSettingsPageState extends ConsumerState<HabitSettingsPage> {
  bool _busy = false;
  int _permissionRevision = 0;

  Future<void> _setGlobal(bool enabled) async {
    setState(() => _busy = true);
    try {
      if (enabled) await ensureHabitNotificationPermission(context, ref);
      final result = await ref
          .read(habitNotificationServiceProvider)
          .setGloballyEnabled(enabled);
      ref.invalidate(habitNotificationsEnabledProvider);
      if (mounted) {
        setState(() => _permissionRevision++);
        showNeoMessage(context, !enabled
            ? 'Semua notifikasi habit dinonaktifkan dan alarm dibatalkan.'
            : result.permissionDenied
                ? 'Pengaturan aktif, tetapi izin Android belum diberikan.'
                : 'Notifikasi habit aktif. ${result.scheduled} alarm dasar dijadwalkan.');
      }
    } catch (error) {
      if (mounted) showNeoMessage(context, friendlyError(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _resync() async {
    setState(() => _busy = true);
    try {
      final service = ref.read(habitNotificationServiceProvider);
      await service.refreshTimezone();
      final result = await service.syncAll();
      ref.invalidate(habitsProvider);
      if (mounted) {
        showNeoMessage(context, result.globallyDisabled
            ? 'Notifikasi global nonaktif; semua alarm habit dibatalkan.'
            : result.permissionDenied
                ? 'Izin notifikasi belum diberikan. Tidak ada alarm yang dijadwalkan.'
                : 'Jadwal disinkronkan: ${result.scheduled} alarm dasar, tanpa duplikat.');
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
    final enabled = ref.watch(habitNotificationsEnabledProvider);
    final service = ref.watch(habitNotificationServiceProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('NOTIFIKASI HABIT')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 30),
        children: [
          Text('Jadwal milikmu.', style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 6),
          Text('Atur pengingat tanpa tekanan dan tanpa izin alarm presisi.',
              style: TextStyle(color: palette.muted)),
          const SizedBox(height: 17),
          NeoCard(
            child: enabled.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (_, __) => NeoErrorCard(onRetry: () => ref.invalidate(habitNotificationsEnabledProvider)),
              data: (value) => SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Semua notifikasi habit', style: TextStyle(fontWeight: FontWeight.w900)),
                subtitle: Text(value ? 'Aktif—pengingat per habit tetap mengikuti jadwalnya.' : 'Nonaktif—semua alarm habit dibatalkan.'),
                value: value,
                onChanged: _busy ? null : _setGlobal,
              ),
            ),
          ),
          const SizedBox(height: 14),
          FutureBuilder<bool>(
            key: ValueKey(_permissionRevision),
            future: service.permissionGranted(),
            builder: (context, snapshot) => NeoCard(
              color: snapshot.data == true ? palette.primary : palette.highlight,
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(snapshot.data == true ? 'IZIN ANDROID: AKTIF' : 'IZIN ANDROID: PERLU DIPERIKSA',
                    style: const TextStyle(color: Color(0xFF171717), fontWeight: FontWeight.w900)),
                const SizedBox(height: 7),
                const Text('Android 13+ meminta izin notifikasi. Suara dan getaran juga mengikuti setelan sistem/kanal.',
                    style: TextStyle(color: Color(0xFF171717), fontSize: 12)),
                const SizedBox(height: 10),
                OutlinedButton.icon(
                  onPressed: _busy
                      ? null
                      : () async {
                          await ensureHabitNotificationPermission(context, ref);
                          if (mounted) setState(() => _permissionRevision++);
                        },
                  icon: const Icon(Icons.notifications_active_outlined, size: 18),
                  label: const Text('Periksa / minta izin'),
                ),
              ]),
            ),
          ),
          const SizedBox(height: 14),
          NeoCard(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const NeoSectionTitle('TENTANG JADWAL'),
              const SizedBox(height: 9),
              const Text('• Pengingat memakai alarm lokal biasa, bukan alarm presisi.\n'
                  '• Waktu dapat bergeser karena Doze, penghemat baterai, atau pembatasan latar belakang.\n'
                  '• Zona waktu dibaca ulang dan jadwal disinkronkan saat aplikasi dibuka/dilanjutkan.\n'
                  '• Restart didukung oleh receiver Android; force-stop atau pembatasan OEM dapat menunda alarm sampai aplikasi dibuka lagi.\n'
                  '• Habit dengan tanggal akhir memakai jendela 90 hari yang diperpanjang saat aplikasi aktif.'),
              const SizedBox(height: 13),
              FilledButton.icon(
                onPressed: _busy ? null : _resync,
                icon: const Icon(Icons.sync),
                label: Text(_busy ? 'Menyinkronkan...' : 'Sinkronkan ulang jadwal'),
              ),
            ]),
          ),
          if (service.initializationError != null) ...[
            const SizedBox(height: 12),
            NeoCard(color: palette.secondary, child: const Text(
                'Layanan notifikasi belum siap di perangkat ini. Pencatatan kebiasaan tetap bisa digunakan; coba sinkronkan ulang.',
                style: TextStyle(color: Color(0xFF171717)))),
          ],
        ],
      ),
    );
  }
}
