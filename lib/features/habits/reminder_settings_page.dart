import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../app/theme/neo_theme.dart';
import '../../core/utils/civil_date.dart';
import '../../data/habit.dart';
import '../../shared/neo_components.dart';
import '../../shared/neo_feedback.dart';
import 'habit_actions.dart';
import 'habit_widgets.dart';

class ReminderSettingsPage extends ConsumerStatefulWidget {
  const ReminderSettingsPage({
    required this.habitName,
    required this.startDate,
    this.endDate,
    this.habitId,
    this.initialReminders = const [],
    this.draftMode = false,
    super.key,
  });

  final String habitName;
  final CivilDate startDate;
  final CivilDate? endDate;
  final int? habitId;
  final List<HabitReminder> initialReminders;
  final bool draftMode;

  @override
  ConsumerState<ReminderSettingsPage> createState() => _ReminderSettingsPageState();
}

class _ReminderDraft {
  _ReminderDraft(HabitReminder reminder)
      : value = reminder,
        title = TextEditingController(text: reminder.title),
        body = TextEditingController(text: reminder.body);
  HabitReminder value;
  final TextEditingController title, body;
  void dispose() {
    title.dispose();
    body.dispose();
  }
}

class _ReminderSettingsPageState extends ConsumerState<ReminderSettingsPage> {
  late final List<_ReminderDraft> _drafts;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _drafts = widget.initialReminders.map(_ReminderDraft.new).toList();
  }

  @override
  void dispose() {
    for (final draft in _drafts) {
      draft.dispose();
    }
    super.dispose();
  }

  void _add() {
    if (_drafts.length >= 5) {
      showNeoMessage(context, 'Maksimal lima pengingat per habit.');
      return;
    }
    setState(() => _drafts.add(_ReminderDraft(HabitReminder(
          minutes: 19 * 60,
          days: {...allWeekdays},
          startDate: widget.startDate,
        ))));
  }

  Future<void> _reset() async {
    final confirmed = await confirmNeoAction(context,
        title: 'Reset semua pengingat?',
        message: 'Semua jadwal pada halaman ini akan dihapus. Habit dan riwayat tetap aman.',
        confirmLabel: 'Reset jadwal');
    if (confirmed && mounted) setState(() => _drafts.clear());
  }

  List<HabitReminder> _currentReminders() => [
        for (final draft in _drafts)
          draft.value.copyWith(title: draft.title.text, body: draft.body.text),
      ];

  Future<void> _save() async {
    if (_saving) return;
    final reminders = _currentReminders();
    try {
      for (final reminder in reminders) {
        validateReminder(reminder);
      }
    } catch (error) {
      showNeoMessage(context, friendlyError(error));
      return;
    }
    setState(() => _saving = true);
    try {
      final global = await ref.read(habitNotificationServiceProvider).globallyEnabled();
      if (global && reminders.any((reminder) => reminder.enabled)) {
        if (!mounted) return;
        await ensureHabitNotificationPermission(context, ref);
      }
      if (widget.draftMode) {
        if (mounted) Navigator.pop(context, reminders);
        return;
      }
      final repository = ref.read(habitRepositoryProvider);
      final habit = await repository.get(widget.habitId!);
      if (habit == null) throw StateError('Habit tidak ditemukan.');
      await repository.save(
        id: habit.id,
        name: habit.name,
        description: habit.description,
        icon: habit.icon,
        color: habit.color,
        frequency: habit.frequency,
        scheduledDays: habit.scheduledDays,
        targetPerWeek: habit.targetPerWeek,
        startDate: habit.startDate.value,
        endDate: habit.endDate?.value,
        isActive: habit.isActive,
        reminders: reminders,
      );
      ref.invalidate(habitsProvider);
      final result = await ref
          .read(habitNotificationServiceProvider)
          .syncHabit(habit.id);
      if (mounted) {
        showNeoMessage(context, result.permissionDenied
            ? 'Jadwal tersimpan, tetapi izin notifikasi belum diberikan.'
            : result.globallyDisabled
                ? 'Jadwal tersimpan. Notifikasi global sedang nonaktif.'
                : 'Jadwal tersimpan dan ${result.scheduled} alarm dasar diperbarui.');
        Navigator.pop(context, true);
      }
    } catch (error) {
      if (mounted) showNeoMessage(context, friendlyError(error));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _test(_ReminderDraft draft) async {
    if (widget.habitId == null) {
      showNeoMessage(context, 'Simpan habit terlebih dahulu untuk menguji pengingat.');
      return;
    }
    final reminder = draft.value.copyWith(
        title: draft.title.text, body: draft.body.text);
    try {
      validateReminder(reminder);
    } catch (error) {
      showNeoMessage(context, friendlyError(error));
      return;
    }
    await ensureHabitNotificationPermission(context, ref);
    final habit = await ref.read(habitRepositoryProvider).get(widget.habitId!);
    if (habit == null || !mounted) return;
    await guardNeoAction(context, () async {
      final result = await ref
          .read(habitNotificationServiceProvider)
          .testReminder(habit, reminder);
      if (result.permissionDenied) {
        throw StateError('Izin notifikasi belum diberikan.');
      }
      if (result.globallyDisabled) {
        throw StateError('Notifikasi habit sedang dimatikan secara global.');
      }
    }, success: 'Notifikasi uji dikirim. Suara/getaran mengikuti pengaturan Android.');
  }

  @override
  Widget build(BuildContext context) {
    final palette = NeoPalette.of(context);
    final globalEnabled = ref.watch(habitNotificationsEnabledProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('PENGATURAN PENGINGAT')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 30),
        children: [
          Text(widget.habitName, style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 6),
          Text('Waktu lokal perangkat. Android dapat menunda pengingat biasa demi menghemat baterai.',
              style: TextStyle(color: palette.muted)),
          if (widget.endDate != null) ...[
            const SizedBox(height: 8),
            Text('Habit berakhir: jadwal satu kali dibuat untuk 90 hari ke depan dan diperpanjang saat aplikasi dibuka/dilanjutkan.',
                style: TextStyle(color: palette.muted, fontSize: 12)),
          ],
          const SizedBox(height: 12),
          globalEnabled.when(
            loading: () => const LinearProgressIndicator(),
            error: (_, __) => NeoErrorCard(onRetry: () => ref.invalidate(habitNotificationsEnabledProvider)),
            data: (enabled) => enabled
                ? const SizedBox.shrink()
                : NeoCard(
                    color: palette.highlight,
                    child: const Text('Notifikasi habit global sedang nonaktif. Jadwal boleh disimpan, tetapi alarm tidak dijalankan.',
                        style: TextStyle(color: Color(0xFF171717), fontWeight: FontWeight.w800))),
          ),
          const SizedBox(height: 14),
          if (_drafts.isEmpty)
            NeoEmptyState(
              icon: Icons.alarm_add_outlined,
              title: 'Belum ada pengingat',
              message: 'Tambahkan satu atau beberapa waktu. Kamu bisa memakai pesan yang menenangkan dan tidak mewajibkan setoran.',
              actionLabel: 'Tambah pengingat',
              onAction: _add,
            ),
          for (var index = 0; index < _drafts.length; index++) ...[
            _buildReminderCard(_drafts[index], index),
            const SizedBox(height: 14),
          ],
          Wrap(spacing: 8, runSpacing: 8, children: [
            OutlinedButton.icon(
                onPressed: _drafts.length >= 5 ? null : _add,
                icon: const Icon(Icons.add_alarm_outlined),
                label: const Text('Tambah waktu')),
            OutlinedButton.icon(
                onPressed: _drafts.isEmpty ? null : _reset,
                icon: const Icon(Icons.restart_alt),
                label: const Text('Reset jadwal')),
          ]),
          const SizedBox(height: 18),
          FilledButton.icon(
            onPressed: _saving ? null : _save,
            icon: const Icon(Icons.save_outlined),
            label: Text(_saving ? 'Menyimpan...' : widget.draftMode ? 'Terapkan ke draft habit' : 'Simpan jadwal'),
          ),
          if (widget.draftMode)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text('Jadwal baru tersimpan permanen setelah kamu menekan “Simpan habit”.',
                  style: TextStyle(color: palette.muted, fontSize: 12)),
            ),
        ],
      ),
    );
  }

  Widget _buildReminderCard(_ReminderDraft draft, int index) {
    final palette = NeoPalette.of(context);
    final reminder = draft.value;
    void update(HabitReminder next) => setState(() => draft.value = next);
    return NeoCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(child: Text('PENGINGAT ${index + 1}', style: Theme.of(context).textTheme.titleMedium)),
          IconButton(
            tooltip: 'Hapus pengingat',
            onPressed: () => setState(() => _drafts.removeAt(index)),
            icon: const Icon(Icons.delete_outline),
          ),
        ]),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Pengingat aktif'),
          value: reminder.enabled,
          onChanged: (value) => update(reminder.copyWith(enabled: value)),
        ),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: () async {
              final picked = await showTimePicker(
                context: context,
                initialTime: TimeOfDay(hour: reminder.hour, minute: reminder.minute),
              );
              if (picked != null) {
                update(reminder.copyWith(minutes: picked.hour * 60 + picked.minute));
              }
            },
            icon: const Icon(Icons.schedule),
            label: Text('Waktu ${reminder.timeLabel}'),
          ),
        ),
        const SizedBox(height: 10),
        DropdownButtonFormField<ReminderRecurrence>(
          initialValue: reminder.recurrence,
          decoration: const InputDecoration(labelText: 'Jadwal'),
          items: const [
            DropdownMenuItem(value: ReminderRecurrence.daily, child: Text('Harian')),
            DropdownMenuItem(value: ReminderRecurrence.weekly, child: Text('Mingguan / hari pilihan')),
          ],
          onChanged: (value) => update(reminder.copyWith(
              recurrence: value,
              days: value == ReminderRecurrence.daily ? {...allWeekdays} : reminder.days)),
        ),
        if (reminder.recurrence == ReminderRecurrence.weekly) ...[
          const SizedBox(height: 10),
          NeoWeekdayPicker(
              selected: reminder.days,
              onChanged: (days) => update(reminder.copyWith(days: days))),
        ],
        const SizedBox(height: 10),
        NeoDateField(
          label: 'Mulai pengingat',
          value: reminder.startDate.value,
          onPicked: (date) => update(reminder.copyWith(startDate: CivilDate.from(date))),
        ),
        const SizedBox(height: 10),
        TextField(
          controller: draft.title,
          maxLength: 100,
          decoration: const InputDecoration(labelText: 'Judul notifikasi'),
        ),
        TextField(
          controller: draft.body,
          maxLength: 500,
          minLines: 2,
          maxLines: 4,
          decoration: const InputDecoration(labelText: 'Pesan notifikasi'),
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Suara'),
          subtitle: const Text('Mengikuti izin dan setelan kanal Android.'),
          value: reminder.sound,
          onChanged: (value) => update(reminder.copyWith(sound: value)),
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Getaran'),
          subtitle: const Text('Jika perangkat mendukung.'),
          value: reminder.vibration,
          onChanged: (value) => update(reminder.copyWith(vibration: value)),
        ),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton.icon(
            onPressed: () => _test(draft),
            icon: const Icon(Icons.notifications_active_outlined, size: 18),
            label: const Text('Uji pengingat'),
          ),
        ),
        Text('Pesan default tidak mewajibkan menabung saat dana belum tersedia.',
            style: TextStyle(color: palette.muted, fontSize: 11)),
      ]),
    );
  }
}
