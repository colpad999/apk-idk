import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../app/providers.dart';
import '../../app/theme/neo_theme.dart';
import '../../data/habit.dart';
import '../../domain/habit_statistics.dart';
import '../../shared/neo_components.dart';
import 'habit_actions.dart';
import 'habit_editor_page.dart';
import 'habit_checkins_page.dart';
import 'habit_history_page.dart';
import 'habit_widgets.dart';
import 'reminder_settings_page.dart';

class HabitDetailPage extends ConsumerWidget {
  const HabitDetailPage({required this.habitId, super.key});
  final int habitId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(habitProvider(habitId));
    final palette = NeoPalette.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('DETAIL HABIT')),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, __) => ListView(padding: const EdgeInsets.all(16), children: [
          NeoErrorCard(onRetry: () => ref.invalidate(habitsProvider)),
        ]),
        data: (habit) {
          if (habit == null) {
            return ListView(padding: const EdgeInsets.all(16), children: const [
              NeoCard(child: Text('Habit ini sudah tidak tersedia. Riwayat keuangan lainnya tetap aman.')),
            ]);
          }
          final stats = calculateHabitStatistics(habit);
          final today = DateTime.now();
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 32),
            children: [
              NeoCard(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    HabitIconBadge(habit: habit, size: 54),
                    const SizedBox(width: 12),
                    Expanded(child: Text(habit.name, style: Theme.of(context).textTheme.headlineSmall)),
                  ]),
                  const SizedBox(height: 10),
                  Wrap(spacing: 6, runSpacing: 6, children: [
                    NeoTag(habit.isActive ? 'AKTIF' : 'DIJEDA', color: habit.isActive ? palette.primary : palette.highlight),
                    NeoTag(habit.frequencyLabel, color: palette.accent),
                  ]),
                  if (habit.description.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Text(habit.description),
                  ],
                  const SizedBox(height: 10),
                  Text('Mulai ${DateFormat('d MMM yyyy', 'id_ID').format(habit.startDate.value)}'
                      '${habit.endDate == null ? ' · tanpa tanggal akhir' : ' · sampai ${DateFormat('d MMM yyyy', 'id_ID').format(habit.endDate!.value)}'}',
                      style: TextStyle(color: palette.muted, fontSize: 12)),
                  const SizedBox(height: 14),
                  HabitCompletionButton(
                    habit: habit,
                    date: today,
                    onPressed: () => toggleHabitCompletion(context, ref, habit, today),
                  ),
                ]),
              ),
              const SizedBox(height: 17),
              LayoutBuilder(builder: (context, constraints) {
                final width = (constraints.maxWidth - 10) / 2;
                return Wrap(spacing: 10, runSpacing: 10, children: [
                  SizedBox(width: width, child: _StatCard(label: 'Streak saat ini', value: '${stats.streak} ${stats.streakUnit}', color: palette.primary)),
                  SizedBox(width: width, child: _StatCard(label: 'Streak terbaik', value: '${stats.bestStreak} ${stats.streakUnit}', color: palette.highlight)),
                  SizedBox(width: width, child: _StatCard(label: 'Penyelesaian', value: '${(stats.completionRate * 100).round()}%', color: palette.accent)),
                  SizedBox(width: width, child: _StatCard(label: 'Total tercatat', value: '${habit.completionCount} kali', color: palette.surface)),
                ]);
              }),
              const SizedBox(height: 17),
              NeoCard(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const NeoSectionTitle('PROGRES'),
                  const SizedBox(height: 12),
                  _ProgressRow(label: 'Hari ini', progress: stats.daily, color: Color(habit.color)),
                  const SizedBox(height: 12),
                  _ProgressRow(label: 'Minggu ini', progress: stats.weekly, color: Color(habit.color)),
                  const SizedBox(height: 12),
                  _ProgressRow(label: 'Bulan ini', progress: stats.monthly, color: Color(habit.color)),
                  const SizedBox(height: 10),
                  Text(habit.isFlexible
                      ? 'Target fleksibel dihitung per minggu. Minggu yang bersinggungan dengan jeda tidak dianggap gagal.'
                      : 'Hari di luar jadwal dan hari saat jeda tidak dihitung sebagai kegagalan.',
                      style: TextStyle(color: palette.muted, fontSize: 11)),
                ]),
              ),
              const SizedBox(height: 17),
              Wrap(spacing: 8, runSpacing: 8, children: [
                OutlinedButton.icon(
                  onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(
                      builder: (_) => HabitEditorPage(habit: habit))),
                  icon: const Icon(Icons.edit_outlined, size: 18),
                  label: const Text('Edit'),
                ),
                OutlinedButton.icon(
                  onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(
                      builder: (_) => HabitHistoryPage(habitId: habit.id))),
                  icon: const Icon(Icons.calendar_month_outlined, size: 18),
                  label: const Text('Riwayat'),
                ),
                OutlinedButton.icon(
                  onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(
                      builder: (_) => HabitCheckinsPage(habitId: habit.id, habitName: habit.name))),
                  icon: const Icon(Icons.note_add_outlined, size: 18),
                  label: const Text('Check-in'),
                ),
                OutlinedButton.icon(
                  onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(
                      builder: (_) => ReminderSettingsPage(
                            habitId: habit.id,
                            habitName: habit.name,
                            startDate: habit.startDate,
                            endDate: habit.endDate,
                            initialReminders: habit.reminders,
                          ))),
                  icon: const Icon(Icons.alarm_outlined, size: 18),
                  label: const Text('Pengingat'),
                ),
              ]),
              const SizedBox(height: 12),
              NeoCard(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(habit.hasReminder
                      ? '${habit.reminders.where((reminder) => reminder.enabled).length} pengingat aktif'
                      : 'Pengingat tidak aktif',
                      style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 6),
                  Text(habit.reminders.isEmpty
                      ? 'Kamu tetap bisa mencatat habit secara manual.'
                      : habit.reminders.map((reminder) =>
                          '${reminder.enabled ? '🔔' : '🔕'} ${reminder.timeLabel} · ${reminder.recurrence == ReminderRecurrence.daily ? 'setiap hari' : 'hari pilihan'}').join('\n'),
                      style: TextStyle(color: palette.muted)),
                ]),
              ),
              const SizedBox(height: 14),
              Row(children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => changeHabitActive(context, ref, habit, !habit.isActive),
                    icon: Icon(habit.isActive ? Icons.pause_circle_outline : Icons.play_circle_outline, size: 19),
                    label: Text(habit.isActive ? 'Jeda habit' : 'Aktifkan'),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.outlined(
                  tooltip: 'Hapus habit',
                  onPressed: () async {
                    final deleted = await deleteHabit(context, ref, habit);
                    if (deleted && context.mounted) Navigator.pop(context);
                  },
                  icon: const Icon(Icons.delete_outline),
                ),
              ]),
              const SizedBox(height: 10),
              Text('Streak boleh dimulai lagi. Catatan ini alat bantu, bukan ukuran nilai dirimu.',
                  textAlign: TextAlign.center, style: TextStyle(color: palette.muted, fontSize: 11)),
            ],
          );
        },
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({required this.label, required this.value, required this.color});
  final String label, value;
  final Color color;
  @override
  Widget build(BuildContext context) {
    final isAccent = color != NeoPalette.of(context).surface;
    final textColor = isAccent ? const Color(0xFF171717) : NeoPalette.of(context).text;
    return NeoCard(
      color: color,
      padding: const EdgeInsets.all(12),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: TextStyle(color: textColor, fontSize: 11, fontWeight: FontWeight.w700)),
        const SizedBox(height: 5),
        Text(value, style: TextStyle(color: textColor, fontSize: 19, fontWeight: FontWeight.w900)),
      ]),
    );
  }
}

class _ProgressRow extends StatelessWidget {
  const _ProgressRow({required this.label, required this.progress, required this.color});
  final String label;
  final HabitProgress progress;
  final Color color;
  @override
  Widget build(BuildContext context) => Column(children: [
        Row(children: [
          Expanded(child: Text(label, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12))),
          Text(progress.target == 0 ? 'Tidak ada jadwal' : progress.label, style: const TextStyle(fontSize: 12)),
        ]),
        const SizedBox(height: 5),
        NeoProgressBar(progress: progress.ratio, color: color),
      ]);
}
