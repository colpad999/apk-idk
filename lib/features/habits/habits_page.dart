import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../app/providers.dart';
import '../../app/theme/neo_theme.dart';
import '../../data/habit_repository.dart';
import '../../shared/neo_components.dart';
import '../../services/habit_notification_service.dart';

int calculateHabitStreak(Habit habit, {DateTime? today}) {
  var cursor = DateTime(today?.year ?? DateTime.now().year,
      today?.month ?? DateTime.now().month, today?.day ?? DateTime.now().day);
  var streak = 0;
  while (cursor.isAfter(habit.startDate.subtract(const Duration(days: 1)))) {
    if (habit.isScheduled(cursor)) {
      if (!habit.isComplete(cursor)) break;
      streak++;
    }
    cursor = cursor.subtract(const Duration(days: 1));
  }
  return streak;
}

class HabitsPage extends ConsumerWidget {
  const HabitsPage({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final habits = ref.watch(habitsProvider);
    final palette = NeoPalette.of(context);
    return ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
        children: [
          Row(children: [
            Expanded(
                child: Text('Habit tracker',
                    style: Theme.of(context).textTheme.headlineSmall)),
            IconButton(
                onPressed: () => _openEditor(context),
                icon: const Icon(Icons.add_box_outlined))
          ]),
          Text('Kebiasaan kecil, progres yang terasa.',
              style: TextStyle(color: palette.muted)),
          const SizedBox(height: 16),
          habits.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, s) => Text('Habit gagal dimuat: $e'),
              data: (items) {
                if (items.isEmpty)
                  return NeoCard(
                      color: palette.highlight,
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(Icons.auto_awesome, size: 30),
                            const SizedBox(height: 10),
                            Text('Belum ada habit',
                                style: Theme.of(context).textTheme.titleLarge),
                            const SizedBox(height: 6),
                            const Text(
                                'Mulai dari kebiasaan sederhana seperti menabung atau mencatat pengeluaran.'),
                            const SizedBox(height: 14),
                            FilledButton.icon(
                                onPressed: () => _openEditor(context),
                                icon: const Icon(Icons.add),
                                label: const Text('Buat habit'))
                          ]));
                return Column(children: [
                  for (final habit in items) ...[
                    _HabitCard(
                        habit: habit,
                        onEdit: () => _openEditor(context, habit),
                        onChanged: () => ref.invalidate(habitsProvider)),
                    const SizedBox(height: 13)
                  ]
                ]);
              }),
        ]);
  }

  void _openEditor(BuildContext context, [Habit? habit]) =>
      showModalBottomSheet<void>(
          context: context,
          isScrollControlled: true,
          useSafeArea: true,
          builder: (_) => _HabitEditor(habit: habit));
}

class _HabitCard extends ConsumerWidget {
  const _HabitCard(
      {required this.habit, required this.onChanged, required this.onEdit});
  final Habit habit;
  final VoidCallback onChanged;
  final VoidCallback onEdit;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = NeoPalette.of(context);
    final today = DateTime.now();
    final done = habit.isComplete(today);
    return NeoCard(
        color: Color(habit.color),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            CircleAvatar(
                backgroundColor: palette.surface,
                child: Icon(_icon(habit.icon), color: palette.text)),
            const SizedBox(width: 10),
            Expanded(
                child: Text(habit.name,
                    style: Theme.of(context).textTheme.titleLarge)),
            PopupMenuButton<String>(
                onSelected: (value) async {
                  if (value == 'edit') onEdit();
                  if (value == 'pause')
                    await ref
                        .read(habitRepositoryProvider)
                        .setActive(habit.id, !habit.isActive);
                  if (value == 'delete') {
                    await HabitNotificationService.instance.cancel(habit.id);
                    await ref.read(habitRepositoryProvider).delete(habit.id);
                  }
                  onChanged();
                },
                itemBuilder: (_) => [
                      const PopupMenuItem(
                          value: 'edit', child: Text('Edit habit')),
                      PopupMenuItem(
                          value: 'pause',
                          child: Text(
                              habit.isActive ? 'Jeda habit' : 'Aktifkan lagi')),
                      const PopupMenuItem(value: 'delete', child: Text('Hapus'))
                    ])
          ]),
          if (habit.description.isNotEmpty)
            Padding(
                padding: const EdgeInsets.only(top: 7),
                child: Text(habit.description)),
          const SizedBox(height: 13),
          Row(children: [
            Expanded(
                child: Text('Streak ${calculateHabitStreak(habit)} hari',
                    style: const TextStyle(fontWeight: FontWeight.w900))),
            NeoTag(habit.isActive ? 'AKTIF' : 'DIJEDA',
                color: habit.isActive ? palette.primary : palette.secondary)
          ]),
          const SizedBox(height: 11),
          Row(children: [
            Expanded(
                child: Text(
                    'Hari ini · ${DateFormat('d MMM', 'id_ID').format(today)}')),
            FilledButton.icon(
                onPressed: !habit.isActive || !habit.isScheduled(today)
                    ? null
                    : () async {
                        await ref
                            .read(habitRepositoryProvider)
                            .toggleCompletion(habit.id, today);
                        onChanged();
                      },
                icon: Icon(done ? Icons.check : Icons.circle_outlined),
                label: Text(done ? 'Selesai' : 'Tandai'))
          ]),
          const SizedBox(height: 10),
          NeoProgressBar(
              progress: (habit.completionCount / 30).clamp(0, 1).toDouble(),
              color: palette.primary),
          const SizedBox(height: 5),
          Text('${habit.completionCount} penyelesaian · ${_frequency(habit)}',
              style: TextStyle(color: palette.muted, fontSize: 12)),
        ]));
  }
}

class _HabitEditor extends ConsumerStatefulWidget {
  const _HabitEditor({this.habit});
  final Habit? habit;
  @override
  ConsumerState<_HabitEditor> createState() => _HabitEditorState();
}

class _HabitEditorState extends ConsumerState<_HabitEditor> {
  final name = TextEditingController(), description = TextEditingController();
  HabitFrequency frequency = HabitFrequency.daily;
  Set<int> days = {1, 2, 3, 4, 5, 6, 7};
  TimeOfDay time = const TimeOfDay(hour: 19, minute: 0);
  DateTime start = DateTime.now();
  bool reminder = false, saving = false;
  @override
  void initState() {
    super.initState();
    final h = widget.habit;
    if (h != null) {
      name.text = h.name;
      description.text = h.description;
      frequency = h.frequency;
      days = {...h.scheduledDays};
      start = h.startDate;
      reminder = h.reminderEnabled;
      time = TimeOfDay(
          hour: h.reminderMinutes ~/ 60, minute: h.reminderMinutes % 60);
    }
  }

  @override
  void dispose() {
    name.dispose();
    description.dispose();
    super.dispose();
  }

  Future<void> save() async {
    if (name.text.trim().isEmpty) return;
    setState(() => saving = true);
    final id = await ref.read(habitRepositoryProvider).save(
        id: widget.habit?.id,
        name: name.text,
        description: description.text,
        frequency: frequency,
        scheduledDays: days,
        startDate: start,
        reminderEnabled: reminder,
        reminderMinutes: time.hour * 60 + time.minute,
        reminderDays: days);
    final items = await ref.read(habitRepositoryProvider).list();
    final saved = items.firstWhere((h) => h.id == id);
    await HabitNotificationService.instance.reschedule(saved);
    ref.invalidate(habitsProvider);
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) => Padding(
        padding: EdgeInsets.fromLTRB(
            20, 18, 20, MediaQuery.viewInsetsOf(context).bottom + 20),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(widget.habit == null ? 'Tambah habit' : 'Edit habit',
                  style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 13),
              TextField(
                  controller: name,
                  decoration: const InputDecoration(labelText: 'Nama habit')),
              const SizedBox(height: 10),
              TextField(
                  controller: description,
                  decoration:
                      const InputDecoration(labelText: 'Deskripsi (opsional)')),
              const SizedBox(height: 10),
              DropdownButtonFormField<HabitFrequency>(
                  value: frequency,
                  decoration: const InputDecoration(labelText: 'Frekuensi'),
                  items: const [
                    DropdownMenuItem(
                        value: HabitFrequency.daily,
                        child: Text('Setiap hari')),
                    DropdownMenuItem(
                        value: HabitFrequency.weeklyDays,
                        child: Text('Hari tertentu')),
                    DropdownMenuItem(
                        value: HabitFrequency.timesPerWeek,
                        child: Text('Beberapa kali per minggu'))
                  ],
                  onChanged: (v) => setState(() => frequency = v!)),
              const SizedBox(height: 10),
              Wrap(spacing: 5, children: [
                for (var i = 1; i <= 7; i++)
                  FilterChip(
                      label: Text([
                        'Sen',
                        'Sel',
                        'Rab',
                        'Kam',
                        'Jum',
                        'Sab',
                        'Min'
                      ][i - 1]),
                      selected: days.contains(i),
                      onSelected: (v) =>
                          setState(() => v ? days.add(i) : days.remove(i)))
              ]),
              SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Pengingat lokal'),
                  subtitle: Text(
                      'Jam ${time.format(context)} · mengikuti jadwal habit'),
                  value: reminder,
                  onChanged: (v) async {
                    if (v) {
                      time = (await showTimePicker(
                              context: context, initialTime: time)) ??
                          time;
                    }
                    setState(() => reminder = v);
                  }),
              SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                      onPressed: saving ? null : save,
                      child: Text(saving ? 'Menyimpan...' : 'Simpan habit')))
            ],
          ),
        ),
      );
}

IconData _icon(String name) => name == 'edit_note'
    ? Icons.edit_note
    : name == 'flag'
        ? Icons.flag
        : Icons.savings;
String _frequency(Habit h) => h.frequency == HabitFrequency.daily
    ? 'setiap hari'
    : h.frequency == HabitFrequency.weeklyDays
        ? 'hari terjadwal'
        : '${h.targetPerWeek}x per minggu';
