import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../app/providers.dart';
import '../../app/theme/neo_theme.dart';
import '../../core/utils/civil_date.dart';
import '../../data/habit.dart';
import '../../domain/habit_statistics.dart';
import '../../shared/neo_components.dart';
import 'habit_actions.dart';
import 'habit_widgets.dart';

class HabitHistoryPage extends ConsumerStatefulWidget {
  const HabitHistoryPage({required this.habitId, super.key});
  final int habitId;
  @override
  ConsumerState<HabitHistoryPage> createState() => _HabitHistoryPageState();
}

class _HabitHistoryPageState extends ConsumerState<HabitHistoryPage> {
  late DateTime _month;
  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _month = DateTime(now.year, now.month);
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(habitProvider(widget.habitId));
    final palette = NeoPalette.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('RIWAYAT KEBIASAAN')),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, __) => Center(child: NeoErrorCard(onRetry: () => ref.invalidate(habitsProvider))),
        data: (habit) {
          if (habit == null) return const Center(child: Text('Habit tidak tersedia.'));
          final first = DateTime(_month.year, _month.month);
          final daysInMonth = DateTime(_month.year, _month.month + 1, 0).day;
          final leading = first.weekday - 1;
          final now = DateTime.now();
          final reference = _month.year == now.year && _month.month == now.month
              ? now
              : DateTime(_month.year, _month.month, daysInMonth);
          final progress = calculateHabitStatistics(habit, now: reference).monthly;
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 30),
            children: [
              Text(habit.name, style: Theme.of(context).textTheme.headlineSmall),
              const SizedBox(height: 6),
              Text('Ketuk tanggal terjadwal untuk mencatat atau membatalkan penyelesaian.',
                  style: TextStyle(color: palette.muted, fontSize: 12)),
              const SizedBox(height: 15),
              NeoCard(
                child: Column(children: [
                  Row(children: [
                    IconButton(
                      tooltip: 'Bulan sebelumnya',
                      onPressed: () => setState(() => _month = DateTime(_month.year, _month.month - 1)),
                      icon: const Icon(Icons.chevron_left),
                    ),
                    Expanded(
                      child: Text(DateFormat('MMMM yyyy', 'id_ID').format(_month),
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.titleMedium),
                    ),
                    IconButton(
                      tooltip: 'Bulan berikutnya',
                      onPressed: () => setState(() => _month = DateTime(_month.year, _month.month + 1)),
                      icon: const Icon(Icons.chevron_right),
                    ),
                  ]),
                  const SizedBox(height: 8),
                  Row(children: [
                    for (final label in weekdayLabels)
                      Expanded(child: Text(label, textAlign: TextAlign.center, style: TextStyle(color: palette.muted, fontSize: 10, fontWeight: FontWeight.w900))),
                  ]),
                  const SizedBox(height: 7),
                  LayoutBuilder(builder: (context, constraints) {
                    final cellWidth = constraints.maxWidth / 7;
                    final cellCount = leading + daysInMonth;
                    final rows = (cellCount / 7).ceil();
                    return SizedBox(
                      height: rows * cellWidth * .98,
                      child: GridView.builder(
                        physics: const NeverScrollableScrollPhysics(),
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 7,
                          childAspectRatio: 1 / .98,
                        ),
                        itemCount: rows * 7,
                        itemBuilder: (context, index) {
                          final dayNumber = index - leading + 1;
                          if (dayNumber < 1 || dayNumber > daysInMonth) return const SizedBox.shrink();
                          final date = DateTime(_month.year, _month.month, dayNumber);
                          return _CalendarDay(
                            habit: habit,
                            date: date,
                            onTap: () => toggleHabitCompletion(context, ref, habit, date),
                          );
                        },
                      ),
                    );
                  }),
                  const SizedBox(height: 12),
                  Text('Bulan ini: ${progress.label} ${habit.isFlexible ? 'target mingguan' : 'hari terjadwal'}',
                      style: const TextStyle(fontWeight: FontWeight.w900)),
                ]),
              ),
              const SizedBox(height: 15),
              Wrap(spacing: 12, runSpacing: 7, children: [
                _Legend(color: Color(habit.color), label: 'Selesai', icon: Icons.check),
                _Legend(color: palette.surface, label: 'Terjadwal'),
                _Legend(color: palette.muted, label: 'Jeda / di luar jadwal'),
              ]),
              const SizedBox(height: 12),
              Text('Tanggal identitasnya disimpan sebagai YYYY-MM-DD lokal, bukan jam UTC. Perubahan zona waktu tidak menulis ulang riwayat.',
                  style: TextStyle(color: palette.muted, fontSize: 11)),
            ],
          );
        },
      ),
    );
  }
}

class _CalendarDay extends StatelessWidget {
  const _CalendarDay({required this.habit, required this.date, required this.onTap});
  final Habit habit;
  final DateTime date;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = NeoPalette.of(context);
    final day = CivilDate.from(date);
    final today = day == CivilDate.today();
    final complete = habit.isComplete(date);
    final scheduled = habit.isScheduled(date);
    final paused = habit.isPausedOn(date);
    final future = day.isAfter(CivilDate.today());
    final eligible = habit.isActive && scheduled && !paused && !future;
    final background = complete
        ? Color(habit.color)
        : paused || !scheduled
            ? palette.muted.withValues(alpha: .18)
            : palette.surface;
    final foreground = complete ? const Color(0xFF171717) : palette.text;
    return Padding(
      padding: const EdgeInsets.all(2),
      child: Semantics(
        button: eligible,
        label: '${DateFormat('d MMMM yyyy', 'id_ID').format(date)}, '
            '${complete ? 'selesai' : paused ? 'dijeda' : scheduled ? 'terjadwal' : 'bukan jadwal'}',
        child: Material(
          color: background,
          child: InkWell(
            onTap: eligible ? onTap : null,
            child: Ink(
              decoration: BoxDecoration(
                border: Border.all(
                    color: today ? palette.secondary : palette.border.withValues(alpha: .55),
                    width: today ? 2.5 : 1),
                borderRadius: BorderRadius.circular(3),
              ),
              child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                Text('${date.day}', style: TextStyle(color: foreground, fontSize: 12, fontWeight: FontWeight.w900)),
                if (complete)
                  const Icon(Icons.check, size: 12, color: Color(0xFF171717))
                else if (paused)
                  Text('JEDA', style: TextStyle(color: palette.muted, fontSize: 6, fontWeight: FontWeight.w900))
                else if (scheduled && !future)
                  Container(width: 4, height: 4, color: palette.secondary),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}

class _Legend extends StatelessWidget {
  const _Legend({required this.color, required this.label, this.icon});
  final Color color;
  final String label;
  final IconData? icon;
  @override
  Widget build(BuildContext context) => Row(mainAxisSize: MainAxisSize.min, children: [
        Container(
          width: 16,
          height: 16,
          decoration: BoxDecoration(color: color, border: Border.all(color: NeoPalette.of(context).border)),
          child: icon == null ? null : Icon(icon, size: 11, color: const Color(0xFF171717)),
        ),
        const SizedBox(width: 5),
        Text(label, style: const TextStyle(fontSize: 10)),
      ]);
}
