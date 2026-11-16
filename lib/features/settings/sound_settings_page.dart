import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app/theme/neo_theme.dart';
import '../../shared/neo_components.dart';
import '../../shared/neo_feedback.dart';
import '../habits/habit_settings_page.dart';
import '../habits/habits_page.dart';

class SoundSettingsPage extends StatelessWidget {
  const SoundSettingsPage({super.key});
  static const _channel = MethodChannel('colpad/system_settings');
  @override
  Widget build(BuildContext context) => Scaffold(appBar: AppBar(title: const Text('SUARA & PENGINGAT')),
    body: ListView(padding: const EdgeInsets.all(16), children: [
      NeoCard(color: NeoPalette.of(context).primary, child: const Text('Suara dan getaran dapat diatur pada setiap pengingat habit. Android mengontrol volume, kanal, mode senyap dan Jangan Ganggu. Pengingat ini bukan alarm manual-stop.')),
      const SizedBox(height: 14),
      NeoCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Pilih habit → Pengingat untuk mengubah suara dan getaran jadwalnya.'),
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
