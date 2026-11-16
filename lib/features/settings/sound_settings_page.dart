import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../app/theme/neo_theme.dart';
import '../../services/habit_notification_service.dart';
import '../../shared/neo_components.dart';
import '../../shared/neo_feedback.dart';
import '../habits/habit_settings_page.dart';
import '../habits/habits_page.dart';

class SoundSettingsPage extends ConsumerStatefulWidget {
  const SoundSettingsPage({super.key});
  @override
  ConsumerState<SoundSettingsPage> createState() => _SoundSettingsPageState();
}

class _SoundSettingsPageState extends ConsumerState<SoundSettingsPage> with WidgetsBindingObserver {
  static const _channel = MethodChannel('colpad/system_settings');
  bool? _enabled, _exact;
  bool _busy = false;
  AndroidHabitNotificationGateway get _gateway => ref.read(habitNotificationGatewayProvider) as AndroidHabitNotificationGateway;
  @override
  void initState() { super.initState(); WidgetsBinding.instance.addObserver(this); _load(); }
  @override
  void dispose() { WidgetsBinding.instance.removeObserver(this); super.dispose(); }
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) { if (state == AppLifecycleState.resumed) { _load(); } }
  Future<void> _load() async {
    try {
      final enabled = await _gateway.alarmEnabled();
      final exact = await _gateway.exactAllowed();
      if (mounted) { setState(() { _enabled = enabled; _exact = exact; }); }
    } catch (_) { if (mounted) { showNeoMessage(context, 'Mode alarm tidak tersedia pada perangkat ini.'); } }
  }
  Future<void> _change(bool value) async {
    setState(() => _busy = true);
    try {
      if (value && !await ref.read(habitNotificationServiceProvider).requestPermission()) {
        throw StateError('Aktifkan izin notifikasi agar tombol alarm dapat ditampilkan.');
      }
      // Stop previous native alarms before changing scheduling mode.
      await _gateway.cancelAll();
      await _gateway.setAlarmEnabled(value);
      final result = await ref.read(habitNotificationServiceProvider).syncAll();
      if (mounted) {
        setState(() => _enabled = value);
        showNeoMessage(context, result.globallyDisabled ? 'Mode disimpan; notifikasi habit global masih nonaktif.' : result.permissionDenied ? 'Mode disimpan; izin notifikasi belum diberikan.' : 'Mode disimpan. ${result.scheduled} jadwal disinkronkan.');
      }
    } catch (error) { if (mounted) { showNeoMessage(context, friendlyError(error)); } }
    finally { if (mounted) { setState(() => _busy = false); } }
  }
  @override
  Widget build(BuildContext context) => Scaffold(appBar: AppBar(title: const Text('SUARA & PENGINGAT')),
    body: ListView(padding: const EdgeInsets.all(16), children: [
      NeoCard(color: NeoPalette.of(context).primary, child: const Text('Mode alarm menggunakan jadwal pengingat habit yang aktif. Suara berulang sampai MATIKAN atau SNOOZE 10 MENIT ditekan pada notifikasi. Suara dan getaran mengikuti pilihan masing-masing pengingat dan pengaturan Android.')),
      const SizedBox(height: 14),
      NeoCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        SwitchListTile(contentPadding: EdgeInsets.zero, title: const Text('Mode alarm habit'),
          subtitle: const Text('Nonaktif: notifikasi biasa. Aktif: alarm manual-stop untuk semua pengingat habit.'),
          value: _enabled ?? false, onChanged: _busy || _enabled == null ? null : _change),
        Text(_exact == true ? 'Izin alarm presisi tersedia.' : 'Izin alarm presisi belum tersedia; Android dapat menunda alarm.'),
        OutlinedButton.icon(onPressed: _busy ? null : () async {
          try { await _gateway.openExactSettings(); } catch (_) { if (context.mounted) { showNeoMessage(context, 'Pengaturan alarm presisi tidak tersedia.'); } }
        }, icon: const Icon(Icons.alarm), label: const Text('Izin alarm presisi Android')),
        const Text('Izin alarm presisi opsional. Force-stop, baterai, mode senyap, DND dan pembatasan perangkat dapat mencegah atau menunda alarm. Beberapa alarm bersamaan dihentikan atau ditunda bersama.', style: TextStyle(fontSize: 12)),
        const SizedBox(height: 10),
        OutlinedButton.icon(onPressed: () => Navigator.push(context, MaterialPageRoute<void>(builder: (_) => const HabitsPage())), icon: const Icon(Icons.checklist), label: const Text('Pilih habit')),
        OutlinedButton.icon(onPressed: () => Navigator.push(context, MaterialPageRoute<void>(builder: (_) => const HabitSettingsPage())), icon: const Icon(Icons.notifications_outlined), label: const Text('Pengaturan notifikasi')),
        OutlinedButton.icon(onPressed: () async {
          try { await _channel.invokeMethod<void>('openSoundSettings'); }
          catch (_) { if (context.mounted) { showNeoMessage(context, 'Tidak dapat membuka pengaturan suara Android.'); } }
        }, icon: const Icon(Icons.volume_up_outlined), label: const Text('Suara sistem Android')),
      ])),
    ]));
}
