import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../app/providers.dart';
import '../../app/theme/neo_theme.dart';
import '../../core/utils/civil_date.dart';
import '../../data/habit.dart';
import '../../data/life_repository.dart';
import '../../domain/activity_calendar.dart';
import '../../shared/neo_components.dart';
import '../habits/habit_detail_page.dart';

class ActivityCalendarPage extends ConsumerStatefulWidget {
  const ActivityCalendarPage({super.key});
  @override
  ConsumerState<ActivityCalendarPage> createState() => _ActivityCalendarPageState();
}

class _ActivityCalendarPageState extends ConsumerState<ActivityCalendarPage> {
  late DateTime _month, _selected;
  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _selected = DateTime(now.year, now.month, now.day);
    _month = DateTime(now.year, now.month);
  }

  @override
  Widget build(BuildContext context) {
    final habits = ref.watch(habitsProvider);
    final entries = ref.watch(lifeEntriesProvider);
    final p = NeoPalette.of(context);
    return Scaffold(appBar: AppBar(title: const Text('KALENDER AKTIVITAS')),
      body: habits.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, __) => NeoErrorCard(onRetry: () => ref.invalidate(habitsProvider)),
        data: (allHabits) => entries.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, __) => NeoErrorCard(onRetry: () => ref.invalidate(lifeEntriesProvider)),
          data: (allEntries) => _content(context, p, allHabits, allEntries),
        ),
      ));
  }

  Widget _content(BuildContext context, NeoPalette p, List<Habit> habits, List<LifeEntry> entries) {
    final first = DateTime(_month.year, _month.month);
    final count = DateTime(_month.year, _month.month + 1, 0).day;
    final leading = first.weekday - 1;
    final rows = ((leading + count) / 7).ceil();
    final calendarIndex = ActivityCalendarIndex(habits, entries);
    final selected = calendarIndex.day(_selected);
    var monthDone = 0, monthTotal = 0, weekDone = 0, weekTotal = 0;
    final today = CivilDate.today();
    final weekStart = CivilDate.from(_selected).weekStart;
    for (var day = 1; day <= count; day++) {
      final date = CivilDate(DateTime(_month.year, _month.month, day));
      if (date.isAfter(today)) { continue; }
      final item = calendarIndex.day(date.value);
      monthDone += item.completed.length;
      monthTotal += item.scheduled.length;
    }
    for (var offset = 0; offset < 7; offset++) {
      final date = weekStart.addDays(offset);
      if (date.isAfter(today)) { continue; }
      final item = calendarIndex.day(date.value);
      weekDone += item.completed.length;
      weekTotal += item.scheduled.length;
    }
    return ListView(padding: const EdgeInsets.fromLTRB(16, 10, 16, 32), children: [
      NeoCard(child: Column(children: [
        Row(children: [
          IconButton(tooltip: 'Bulan sebelumnya', onPressed: () => _changeMonth(-1), icon: const Icon(Icons.chevron_left)),
          Expanded(child: Text(DateFormat('MMMM yyyy', 'id_ID').format(_month), textAlign: TextAlign.center, style: Theme.of(context).textTheme.titleMedium)),
          IconButton(tooltip: 'Bulan berikutnya', onPressed: () => _changeMonth(1), icon: const Icon(Icons.chevron_right)),
        ]),
        Row(children: [for (final label in weekdayLabels) Expanded(child: Text(label, textAlign: TextAlign.center, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800)))]),
        const SizedBox(height: 8),
        GridView.builder(shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
          itemCount: rows * 7, gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 7, childAspectRatio: 1),
          itemBuilder: (context, index) {
            final number = index - leading + 1;
            if (number < 1 || number > count) { return const SizedBox.shrink(); }
            final date = DateTime(_month.year, _month.month, number);
            final item = calendarIndex.day(date);
            final isFuture = CivilDate.from(date).isAfter(today);
            final Color background;
            if (item.scheduled.isEmpty || isFuture) {
              background = p.surface;
            } else if (item.completed.length == item.scheduled.length) {
              background = p.highlight;
            } else if (item.completed.isNotEmpty) {
              background = p.primary;
            } else {
              background = const Color(0xFFFF9B71);
            }
            final selected = CivilDate.from(date).key == CivilDate.from(_selected).key;
            return Padding(padding: const EdgeInsets.all(2), child: Material(
              color: background, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(3), side: BorderSide(color: p.border, width: selected ? 3 : 1)),
              child: InkWell(onTap: () => setState(() => _selected = date),
                child: Semantics(label: '${DateFormat('d MMMM yyyy', 'id_ID').format(date)}, ${item.completed.length} dari ${item.scheduled.length} selesai${item.entry != null ? ', ada jurnal atau mood' : ''}',
                  child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                    Text('$number', style: const TextStyle(fontWeight: FontWeight.w800)),
                    if (item.entry != null || item.flexible.any((h) => h.isComplete(date))) const Icon(Icons.circle, size: 5),
                  ]))),
            ));
          }),
        const SizedBox(height: 8),
        const Text('Warna menunjukkan selesai, sebagian, atau belum selesai; buka tanggal untuk detail.', style: TextStyle(fontSize: 11)),
      ])),
      const SizedBox(height: 16),
      NeoCard(color: p.accent, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('RINGKASAN', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        Text('Minggu terpilih: $weekDone / $weekTotal · Bulan terpilih: $monthDone / $monthTotal'),
        const SizedBox(height: 6),
        const Text('Jumlah penyelesaian dari jadwal tetap sampai hari ini. Habit target mingguan fleksibel tidak dianggap gagal setiap hari.', style: TextStyle(fontSize: 11)),
      ])),
      const SizedBox(height: 16),
      NeoSectionTitle(DateFormat('d MMMM yyyy', 'id_ID').format(_selected)),
      const SizedBox(height: 8),
      if (selected.scheduled.isEmpty && selected.flexible.isEmpty && selected.entry == null)
        const NeoCard(child: Text('Tidak ada aktivitas atau jadwal pada tanggal ini.')),
      for (final habit in [...selected.scheduled, ...selected.flexible]) ...[
        NeoCard(shadow: false, padding: EdgeInsets.zero, child: ListTile(
          leading: Icon(habit.isComplete(_selected) ? Icons.check_circle : Icons.radio_button_unchecked),
          title: Text(habit.name),
          subtitle: Text(habit.isFlexible ? 'Target mingguan · ${habit.isComplete(_selected) ? 'tercatat' : 'belum tercatat'}' : habit.isComplete(_selected) ? 'Selesai' : 'Belum selesai'),
          onTap: () => Navigator.push(context, MaterialPageRoute<void>(builder: (_) => HabitDetailPage(habitId: habit.id))),
        )), const SizedBox(height: 8),
      ],
      if (selected.entry != null) ...[
        NeoCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('JURNAL & MOOD', style: TextStyle(fontWeight: FontWeight.w900)),
          if (selected.entry!.mood != null) Text('Mood: ${['Buruk', 'Kurang baik', 'Biasa saja', 'Baik', 'Sangat baik'][selected.entry!.mood! - 1]}'),
          if (selected.entry!.moodNote.isNotEmpty) Text(selected.entry!.moodNote),
          if (selected.entry!.journal.isNotEmpty) Text(selected.entry!.journal),
        ])),
      ],
    ]);
  }

  void _changeMonth(int offset) => setState(() {
    _month = DateTime(_month.year, _month.month + offset);
    _selected = _month;
  });
}
