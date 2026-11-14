import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../app/providers.dart';
import '../../app/theme/neo_theme.dart';
import '../../data/habit.dart';
import '../../domain/habit_statistics.dart';
import '../../shared/neo_components.dart';
import 'habit_actions.dart';
import 'habit_detail_page.dart';
import 'habit_editor_page.dart';
import 'habit_settings_page.dart';
import 'habit_widgets.dart';

class HabitsPage extends ConsumerStatefulWidget {
  const HabitsPage({super.key});
  @override
  ConsumerState<HabitsPage> createState() => _HabitsPageState();
}

class _HabitsPageState extends ConsumerState<HabitsPage> {
  int _filter = 0;

  Future<void> _openEditor([Habit? habit, String? example]) async {
    await Navigator.of(context).push<void>(MaterialPageRoute(
        builder: (_) => HabitEditorPage(habit: habit, initialName: example)));
    if (mounted) ref.invalidate(habitsProvider);
  }

  @override
  Widget build(BuildContext context) {
    final habits = ref.watch(habitsProvider);
    final palette = NeoPalette.of(context);
    final today = DateTime.now();
    return Scaffold(
      appBar: AppBar(
        title: const Text('HABIT TRACKER'),
        actions: [
          IconButton(
            tooltip: 'Pengaturan notifikasi habit',
            onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(
                builder: (_) => const HabitSettingsPage())),
            icon: const Icon(Icons.notifications_none_rounded),
          ),
          IconButton(
            tooltip: 'Tambah habit',
            onPressed: () => _openEditor(),
            icon: const Icon(Icons.add_box_outlined),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async => ref.invalidate(habitsProvider),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 32),
          children: [
            Text('KEBIASAAN KECIL.\nPROGRES NYATA.',
                style: Theme.of(context).textTheme.headlineLarge),
            const SizedBox(height: 7),
            Text(DateFormat('EEEE, d MMMM yyyy', 'id_ID').format(today),
                style: TextStyle(color: palette.muted)),
            const SizedBox(height: 17),
            habits.when(
              loading: () => const NeoCard(
                  child: SizedBox(height: 130, child: Center(child: CircularProgressIndicator()))),
              error: (_, __) => NeoErrorCard(
                  message: 'Habit gagal dimuat. Data lama tetap aman.',
                  onRetry: () => ref.invalidate(habitsProvider)),
              data: (items) {
                if (items.isEmpty) {
                  return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    NeoEmptyState(
                      icon: Icons.auto_awesome_outlined,
                      title: 'Mulai dari satu kebiasaan.',
                      message: 'Menabung, mencatat pengeluaran, atau meninjau anggaran—pilih yang paling mudah dilakukan hari ini.',
                      actionLabel: 'Buat habit pertama',
                      onAction: () => _openEditor(),
                    ),
                    const SizedBox(height: 18),
                    const NeoSectionTitle('CONTOH UNTUKMU'),
                    const SizedBox(height: 9),
                    Wrap(spacing: 7, runSpacing: 7, children: [
                      for (final example in [
                        'Menabung setiap hari',
                        'Mencatat pengeluaran setiap malam',
                        'Mengevaluasi anggaran setiap minggu',
                        'Menyisihkan uang saku',
                        'Memeriksa progres tujuan',
                      ])
                        ActionChip(
                          label: Text(example),
                          onPressed: () => _openEditor(null, example),
                        ),
                    ]),
                  ]);
                }
                final active = items.where((habit) => habit.isActive).toList();
                final paused = items.where((habit) => !habit.isActive).toList();
                final stats = active.map((habit) => calculateHabitStatistics(habit)).toList();
                final dailyDone = stats.fold<int>(0, (sum, stat) => sum + stat.daily.completed);
                final dailyTarget = stats.fold<int>(0, (sum, stat) => sum + stat.daily.target);
                final weeklyDone = stats.fold<int>(0, (sum, stat) => sum + stat.weekly.completed);
                final weeklyTarget = stats.fold<int>(0, (sum, stat) => sum + stat.weekly.target);
                final visible = _filter == 0 ? active : _filter == 1 ? paused : items;
                return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  NeoCard(
                    color: palette.primary,
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Row(children: [
                        const Icon(Icons.bolt_rounded, color: Color(0xFF171717), size: 28),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text('HARI INI: $dailyDone/$dailyTarget',
                              style: const TextStyle(color: Color(0xFF171717), fontSize: 20, fontWeight: FontWeight.w900)),
                        ),
                      ]),
                      const SizedBox(height: 10),
                      NeoProgressBar(progress: dailyTarget == 0 ? 0 : dailyDone / dailyTarget, color: const Color(0xFF171717)),
                      const SizedBox(height: 8),
                      Text(dailyTarget == 0
                          ? 'Tidak ada jadwal aktif hari ini. Istirahat juga bagian dari ritme.'
                          : 'Minggu ini: $weeklyDone/$weeklyTarget target tercatat.',
                          style: const TextStyle(color: Color(0xFF171717), fontSize: 12, fontWeight: FontWeight.w700)),
                    ]),
                  ),
                  const SizedBox(height: 17),
                  SegmentedButton<int>(
                    segments: [
                      ButtonSegment(value: 0, label: Text('Aktif (${active.length})')),
                      ButtonSegment(value: 1, label: Text('Jeda (${paused.length})')),
                      const ButtonSegment(value: 2, label: Text('Semua')),
                    ],
                    selected: {_filter},
                    onSelectionChanged: (selection) => setState(() => _filter = selection.first),
                    showSelectedIcon: false,
                    style: SegmentedButton.styleFrom(textStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.w900)),
                  ),
                  const SizedBox(height: 15),
                  if (visible.isEmpty)
                    NeoCard(child: Text(_filter == 1 ? 'Tidak ada habit yang dijeda.' : 'Belum ada habit pada filter ini.')),
                  for (final habit in visible) ...[
                    _HabitCard(habit: habit),
                    const SizedBox(height: 13),
                  ],
                ]);
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _HabitCard extends ConsumerWidget {
  const _HabitCard({required this.habit});
  final Habit habit;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = NeoPalette.of(context);
    final today = DateTime.now();
    final stats = calculateHabitStatistics(habit);
    return NeoCard(
      padding: EdgeInsets.zero,
      child: InkWell(
        onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(
            builder: (_) => HabitDetailPage(habitId: habit.id))),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              HabitIconBadge(habit: habit),
              const SizedBox(width: 10),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(habit.name, style: Theme.of(context).textTheme.titleMedium, maxLines: 2, overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 3),
                  Text(habit.frequencyLabel, style: TextStyle(color: palette.muted, fontSize: 11)),
                ]),
              ),
              const SizedBox(width: 6),
              NeoTag(habit.isActive ? 'AKTIF' : 'JEDA', color: habit.isActive ? palette.primary : palette.highlight),
            ]),
            if (habit.description.isNotEmpty) ...[
              const SizedBox(height: 9),
              Text(habit.description, maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(color: palette.muted, fontSize: 12)),
            ],
            const SizedBox(height: 12),
            Row(children: [
              Expanded(child: Text('🔥 ${stats.streak} ${stats.streakUnit} konsisten', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 12))),
              Text('Minggu ${stats.weekly.label}', style: TextStyle(color: palette.muted, fontSize: 11)),
            ]),
            const SizedBox(height: 7),
            NeoProgressBar(progress: stats.weekly.ratio, color: Color(habit.color)),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(
                child: Text(habit.hasReminder ? '🔔 ${habit.reminders.where((r) => r.enabled).length} pengingat' : 'Tanpa pengingat',
                    style: TextStyle(color: palette.muted, fontSize: 11)),
              ),
              HabitCompletionButton(
                habit: habit,
                date: today,
                onPressed: () => toggleHabitCompletion(context, ref, habit, today),
              ),
            ]),
          ]),
        ),
      ),
    );
  }
}
