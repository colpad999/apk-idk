import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../app/theme/neo_theme.dart';
import '../../core/utils/civil_date.dart';
import '../../domain/life_insights.dart';
import '../../shared/neo_components.dart';

const _labels = ['Buruk', 'Kurang baik', 'Biasa saja', 'Baik', 'Sangat baik'];

class LifeInsightsPage extends ConsumerWidget {
  const LifeInsightsPage({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final habits = ref.watch(habitsProvider);
    final entries = ref.watch(lifeEntriesProvider);
    final palette = NeoPalette.of(context);
    final today = CivilDate.today();
    return Scaffold(appBar: AppBar(title: const Text('PROGRES DIRI')),
      body: ListView(padding: const EdgeInsets.fromLTRB(16, 10, 16, 32), children: [
        const Text('PENCAPAIAN', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
        const SizedBox(height: 8),
        habits.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, __) => NeoErrorCard(onRetry: () => ref.invalidate(habitsProvider)),
          data: (items) => Column(children: [
            for (final achievement in habitAchievements(items, today.value)) ...[
              NeoCard(color: achievement.unlocked ? palette.highlight : palette.surface, shadow: false,
                child: Row(children: [
                  Icon(achievement.unlocked ? Icons.star_rounded : Icons.lock_outline),
                  const SizedBox(width: 12),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(achievement.title, style: const TextStyle(fontWeight: FontWeight.w900)),
                    Text(achievement.description),
                    Text(achievement.unlocked ? 'Terbuka' : 'Belum terbuka', style: const TextStyle(fontSize: 11)),
                  ])),
                ])),
              const SizedBox(height: 8),
            ],
          ]),
        ),
        const SizedBox(height: 16),
        const Text('GRAFIK HABIT · 7 HARI', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
        const SizedBox(height: 8),
        habits.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, __) => NeoErrorCard(onRetry: () => ref.invalidate(habitsProvider)),
          data: (items) => NeoCard(color: palette.accent, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            for (final day in habitDailyReport(items, today)) ...[
              Row(children: [
                SizedBox(width: 70, child: Text('${day.date.day}/${day.date.month}', style: const TextStyle(fontWeight: FontWeight.w800))),
                Expanded(child: NeoProgressBar(progress: day.scheduled == 0 ? 0 : day.completed / day.scheduled)),
                const SizedBox(width: 8),
                Text('${day.completed}/${day.scheduled}'),
              ]),
              const SizedBox(height: 10),
            ],
            const Text('Selesai / terjadwal. Habit mingguan fleksibel tidak dihitung sebagai kegagalan harian; hari jeda juga dikecualikan.', style: TextStyle(fontSize: 12)),
          ])),
        ),
        const SizedBox(height: 16),
        const Text('RINGKASAN MOOD', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
        const SizedBox(height: 8),
        entries.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, __) => NeoErrorCard(onRetry: () => ref.invalidate(lifeEntriesProvider)),
          data: (items) => Column(children: [
            _MoodCard(title: 'Minggu ini', counts: moodCounts(items, today.weekStart, today), color: palette.accent),
            const SizedBox(height: 12),
            _MoodCard(title: 'Bulan ini', counts: moodCounts(items, today.monthStart, today), color: palette.primary),
          ]),
        ),
        const SizedBox(height: 12),
        const Text('Ringkasan ini hanya mencerminkan catatan yang kamu pilih untuk disimpan, bukan diagnosis.', style: TextStyle(fontSize: 12)),
      ]));
  }
}

class _MoodCard extends StatelessWidget {
  const _MoodCard({required this.title, required this.counts, required this.color});
  final String title;
  final List<int> counts;
  final Color color;
  @override
  Widget build(BuildContext context) {
    final total = counts.fold<int>(0, (sum, value) => sum + value);
    return NeoCard(color: color, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('$title · $total catatan', style: const TextStyle(fontWeight: FontWeight.w900)),
      const SizedBox(height: 8),
      for (var i = 0; i < counts.length; i++) ...[
        Row(children: [Expanded(child: Text(_labels[i])), Text('${counts[i]} hari', style: const TextStyle(fontWeight: FontWeight.w800))]),
        const SizedBox(height: 4),
        NeoProgressBar(progress: total == 0 ? 0 : counts[i] / total),
        const SizedBox(height: 6),
      ],
    ]));
  }
}
