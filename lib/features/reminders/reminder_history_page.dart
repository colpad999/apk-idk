import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../../app/theme/neo_theme.dart';
import '../../shared/neo_components.dart';

class ReminderHistoryPage extends StatefulWidget {
  const ReminderHistoryPage({super.key});
  @override
  State<ReminderHistoryPage> createState() => _ReminderHistoryPageState();
}

class _ReminderHistoryPageState extends State<ReminderHistoryPage> with WidgetsBindingObserver {
  static const _channel = MethodChannel('colpad/habit_alarm');
  late Future<List<Map<Object?, Object?>>> _history;
  @override
  void initState() { super.initState(); WidgetsBinding.instance.addObserver(this); _history = _load(); }
  @override
  void dispose() { WidgetsBinding.instance.removeObserver(this); super.dispose(); }
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) { _refresh(); }
  }
  Future<List<Map<Object?, Object?>>> _load() async {
    final rows = await _channel.invokeListMethod<Object?>('history') ?? [];
    return rows.map((row) => Map<Object?, Object?>.from(row as Map)).toList();
  }
  void _refresh() { if (mounted) { setState(() => _history = _load()); } }
  String _event(Object? value) => switch (value) {
    'triggered' => 'Alarm dipicu',
    'snooze_due' => 'Snooze jatuh tempo',
    'snoozed' => 'Ditunda 10 menit',
    'stopped' => 'Dimatikan',
    'blocked' => 'Tidak dimulai: izin atau kanal notifikasi nonaktif',
    'service_denied' => 'Layanan alarm ditolak Android; suara mungkin tidak ada',
    _ => 'Peristiwa alarm',
  };
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('RIWAYAT PENGINGAT'), actions: [IconButton(tooltip: 'Muat ulang', onPressed: _refresh, icon: const Icon(Icons.refresh))]),
    body: FutureBuilder<List<Map<Object?, Object?>>>(future: _history, builder: (context, snapshot) {
      if (!snapshot.hasData && !snapshot.hasError) { return const Center(child: CircularProgressIndicator()); }
      if (snapshot.hasError) { return Center(child: NeoErrorCard(onRetry: _refresh)); }
      final rows = snapshot.data!;
      return ListView(padding: const EdgeInsets.fromLTRB(16, 12, 16, 32), children: [
        NeoCard(color: NeoPalette.of(context).primary, child: const Text('Riwayat peristiwa mode alarm Android mulai dari versi ini. Pengingat biasa dan kejadian sebelum fitur ini tidak tercatat. “Dipicu” tidak menjamin suara terdengar. Riwayat disimpan di perangkat dan belum termasuk backup. Menampilkan 200 peristiwa terbaru.')),
        const SizedBox(height: 14),
        if (rows.isEmpty) const NeoCard(child: Text('Belum ada peristiwa alarm yang tercatat.')),
        for (final row in rows) ...[
          NeoCard(shadow: false, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(row['title'] as String? ?? 'Alarm habit', style: const TextStyle(fontWeight: FontWeight.w900)),
            Text(_event(row['event'])),
            Text(DateFormat('dd MMM yyyy · HH:mm:ss', 'id_ID').format(DateTime.fromMillisecondsSinceEpoch(row['time'] as int)), style: const TextStyle(fontSize: 12)),
          ])), const SizedBox(height: 8),
        ],
      ]);
    }));
}
