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
import 'reminder_settings_page.dart';

class HabitEditorPage extends ConsumerStatefulWidget {
  const HabitEditorPage({this.habit, this.initialName, super.key});
  final Habit? habit;
  final String? initialName;

  @override
  ConsumerState<HabitEditorPage> createState() => _HabitEditorPageState();
}

class _HabitEditorPageState extends ConsumerState<HabitEditorPage> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _description;
  late HabitFrequency _frequency;
  late Set<int> _days;
  late int _targetPerWeek, _color;
  late String _icon;
  late CivilDate _start;
  late CivilDate? _end;
  late bool _active, _hasEnd;
  late List<HabitReminder> _reminders;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final habit = widget.habit;
    _name = TextEditingController(text: habit?.name ?? widget.initialName ?? '');
    _description = TextEditingController(text: habit?.description ?? '');
    _frequency = habit?.frequency ?? HabitFrequency.daily;
    _days = {...?habit?.scheduledDays};
    if (_days.isEmpty) _days.addAll(allWeekdays);
    _targetPerWeek = habit?.targetPerWeek ?? 3;
    _color = habit?.color ?? habitColorOptions.first;
    _icon = habit?.icon ?? 'savings';
    _start = habit?.startDate ?? CivilDate.today();
    _end = habit?.endDate;
    _hasEnd = _end != null;
    _active = habit?.isActive ?? true;
    _reminders = [...?habit?.reminders];
  }

  @override
  void dispose() {
    _name.dispose();
    _description.dispose();
    super.dispose();
  }

  Future<void> _editReminders() async {
    final result = await Navigator.of(context).push<List<HabitReminder>>(
      MaterialPageRoute(
        builder: (_) => ReminderSettingsPage(
          habitName: _name.text.trim().isEmpty ? 'Habit baru' : _name.text.trim(),
          startDate: _start,
          endDate: _hasEnd ? _end : null,
          initialReminders: _reminders,
          draftMode: true,
        ),
      ),
    );
    if (result != null && mounted) setState(() => _reminders = result);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate() || _saving) return;
    if (_hasEnd && _end!.isBefore(_start)) {
      showNeoMessage(context, 'Tanggal berakhir harus setelah tanggal mulai.');
      return;
    }
    setState(() => _saving = true);
    try {
      if (_reminders.any((reminder) => reminder.enabled) &&
          await ref.read(habitNotificationServiceProvider).globallyEnabled()) {
        if (!mounted) return;
        await ensureHabitNotificationPermission(context, ref);
      }
      final id = await ref.read(habitRepositoryProvider).save(
            id: widget.habit?.id,
            name: _name.text,
            description: _description.text,
            icon: _icon,
            color: _color,
            frequency: _frequency,
            scheduledDays: _days,
            targetPerWeek: _targetPerWeek,
            startDate: _start.value,
            endDate: _hasEnd ? _end!.value : null,
            isActive: _active,
            reminders: _reminders,
          );
      ref.invalidate(habitsProvider);
      try {
        final result =
            await ref.read(habitNotificationServiceProvider).syncHabit(id);
        if (result.permissionDenied && mounted) {
          showNeoMessage(context,
              'Habit tersimpan. Pengingat menunggu izin notifikasi Android.');
        } else if (result.globallyDisabled && _reminders.isNotEmpty && mounted) {
          showNeoMessage(context,
              'Habit tersimpan. Notifikasi habit sedang dimatikan secara global.');
        }
      } catch (_) {
        if (mounted) {
          showNeoMessage(context,
              'Habit tersimpan, tetapi jadwal belum dapat diperbarui. Buka pengaturan pengingat untuk mencoba lagi.');
        }
      }
      if (mounted) Navigator.pop(context, id);
    } catch (error) {
      if (mounted) showNeoMessage(context, friendlyError(error));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = NeoPalette.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(widget.habit == null ? 'TAMBAH HABIT' : 'EDIT HABIT')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 30),
          children: [
            Text('Bangun ritme, bukan tekanan.',
                style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 6),
            Text('Pilih kebiasaan yang realistis untukmu.',
                style: TextStyle(color: palette.muted)),
            const SizedBox(height: 18),
            TextFormField(
              controller: _name,
              maxLength: 80,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(labelText: 'Nama habit'),
              validator: (value) => value == null || value.trim().isEmpty
                  ? 'Nama habit wajib diisi.'
                  : null,
            ),
            TextFormField(
              controller: _description,
              maxLength: 500,
              minLines: 2,
              maxLines: 3,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                  labelText: 'Deskripsi (opsional)',
                  hintText: 'Apa langkah kecil yang ingin kamu lakukan?'),
            ),
            const NeoSectionTitle('IKON & WARNA'),
            const SizedBox(height: 10),
            Wrap(spacing: 7, runSpacing: 7, children: [
              for (final entry in habitIconOptions.entries)
                _ChoiceTile(
                  selected: _icon == entry.key,
                  color: _icon == entry.key ? palette.primary : palette.surface,
                  onTap: () => setState(() => _icon = entry.key),
                  child: Icon(entry.value, color: palette.text),
                ),
            ]),
            const SizedBox(height: 10),
            Wrap(spacing: 8, children: [
              for (final color in habitColorOptions)
                _ChoiceTile(
                  selected: _color == color,
                  color: Color(color),
                  onTap: () => setState(() => _color = color),
                  child: _color == color
                      ? const Icon(Icons.check, color: Color(0xFF171717))
                      : const SizedBox.expand(),
                ),
            ]),
            const SizedBox(height: 20),
            DropdownButtonFormField<HabitFrequency>(
              initialValue: _frequency,
              decoration: const InputDecoration(labelText: 'Target frekuensi'),
              items: const [
                DropdownMenuItem(value: HabitFrequency.daily, child: Text('Setiap hari')),
                DropdownMenuItem(value: HabitFrequency.weeklyDays, child: Text('Hari tertentu dalam seminggu')),
                DropdownMenuItem(value: HabitFrequency.timesPerWeek, child: Text('Beberapa kali per minggu')),
              ],
              onChanged: (value) => setState(() => _frequency = value!),
            ),
            if (_frequency == HabitFrequency.weeklyDays) ...[
              const SizedBox(height: 12),
              NeoWeekdayPicker(
                  selected: _days, onChanged: (days) => setState(() => _days = days)),
            ],
            if (_frequency == HabitFrequency.timesPerWeek) ...[
              const SizedBox(height: 10),
              Text('Target: $_targetPerWeek× per minggu',
                  style: Theme.of(context).textTheme.titleMedium),
              Slider(
                value: _targetPerWeek.toDouble(),
                min: 1,
                max: 7,
                divisions: 6,
                label: '$_targetPerWeek×',
                onChanged: (value) => setState(() => _targetPerWeek = value.round()),
              ),
              Text('Bisa diselesaikan pada hari mana pun. Streak dihitung per minggu.',
                  style: TextStyle(color: palette.muted, fontSize: 12)),
            ],
            const SizedBox(height: 18),
            NeoDateField(
              label: 'Tanggal mulai',
              value: _start.value,
              onPicked: (date) => setState(() {
                _start = CivilDate.from(date);
                if (_end != null && _end!.isBefore(_start)) _end = _start;
              }),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Tanggal berakhir opsional'),
              value: _hasEnd,
              onChanged: (value) => setState(() {
                _hasEnd = value;
                _end = value ? (_end ?? _start.addDays(30)) : null;
              }),
            ),
            if (_hasEnd)
              NeoDateField(
                label: 'Tanggal berakhir',
                value: _end?.value,
                firstDate: _start.value,
                onPicked: (date) => setState(() => _end = CivilDate.from(date)),
              ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Habit aktif'),
              subtitle: const Text('Matikan untuk menjeda tanpa menghapus riwayat.'),
              value: _active,
              onChanged: (value) => setState(() => _active = value),
            ),
            const SizedBox(height: 10),
            NeoCard(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const NeoSectionTitle('PENGINGAT'),
                const SizedBox(height: 7),
                Text(_reminders.isEmpty
                    ? 'Belum ada pengingat. Habit tetap bisa dicatat manual.'
                    : _reminders.map((reminder) =>
                        '${reminder.enabled ? '🔔' : '🔕'} ${reminder.timeLabel} · ${reminder.recurrence == ReminderRecurrence.daily ? 'harian' : reminder.days.length == 7 ? 'mingguan (semua hari)' : 'hari pilihan'}').join('\n')),
                const SizedBox(height: 10),
                OutlinedButton.icon(
                  onPressed: _editReminders,
                  icon: const Icon(Icons.alarm_outlined),
                  label: Text(_reminders.isEmpty ? 'Atur pengingat' : 'Ubah jadwal pengingat'),
                ),
              ]),
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: _saving ? null : _save,
              icon: _saving
                  ? const SizedBox.square(dimension: 18, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.save_outlined),
              label: Text(_saving ? 'Menyimpan...' : 'Simpan habit'),
            ),
          ],
        ),
      ),
    );
  }
}

class _ChoiceTile extends StatelessWidget {
  const _ChoiceTile({required this.selected, required this.color, required this.onTap, required this.child});
  final bool selected;
  final Color color;
  final VoidCallback onTap;
  final Widget child;
  @override
  Widget build(BuildContext context) {
    final palette = NeoPalette.of(context);
    return SizedBox(
      width: 44,
      height: 44,
      child: Material(
        color: color,
        child: InkWell(
          onTap: onTap,
          child: Ink(
            decoration: BoxDecoration(
              border: Border.all(color: palette.border, width: selected ? 3 : 1.5),
              borderRadius: BorderRadius.circular(3),
            ),
            child: Center(child: child),
          ),
        ),
      ),
    );
  }
}
