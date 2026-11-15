import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../app/providers.dart';
import '../../app/theme/neo_theme.dart';
import '../../core/utils/civil_date.dart';
import '../../data/habit_counter_repository.dart';
import '../../shared/neo_components.dart';
import '../../shared/neo_feedback.dart';

class HabitCounterPage extends ConsumerStatefulWidget {
  const HabitCounterPage({required this.habitId, required this.habitName, super.key});
  final int habitId;
  final String habitName;
  @override
  ConsumerState<HabitCounterPage> createState() => _HabitCounterPageState();
}

class _HabitCounterPageState extends ConsumerState<HabitCounterPage> {
  bool _busy = false;
  Future<void> _configure(HabitCounter? current) async {
    final target = TextEditingController(text: current?.target.toString() ?? '');
    final unit = TextEditingController(text: current?.unit ?? '');
    final result = await showDialog<(String, String)>(context: context, builder: (context) => AlertDialog(
      title: const Text('Target harian'),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        TextField(controller: target, keyboardType: TextInputType.number, maxLength: 7, decoration: const InputDecoration(labelText: 'Target (bilangan bulat)')),
        const SizedBox(height: 8),
        TextField(controller: unit, maxLength: 30, decoration: const InputDecoration(labelText: 'Satuan', hintText: 'gelas, menit, kali...')),
      ]),
      actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Batal')),
        FilledButton(onPressed: () => Navigator.pop(context, (target.text, unit.text)), child: const Text('Simpan'))],
    ));
    target.dispose(); unit.dispose();
    if (!mounted || result == null || _busy) return;
    final number = int.tryParse(result.$1);
    if (number == null) {
      showNeoMessage(context, 'Masukkan target bilangan bulat.');
      return;
    }
    setState(() => _busy = true);
    try {
      await ref.read(habitCounterRepositoryProvider).configure(widget.habitId, number, result.$2);
      ref.invalidate(habitCounterProvider(widget.habitId));
    } catch (error) {
      if (mounted) { showNeoMessage(context, friendlyError(error)); }
    } finally { if (mounted) setState(() => _busy = false); }
  }

  Future<void> _change(int delta) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await ref.read(habitCounterRepositoryProvider).change(widget.habitId, delta);
      ref.invalidate(habitCounterHistoryProvider(widget.habitId));
    } catch (error) {
      if (mounted) { showNeoMessage(context, friendlyError(error)); }
    } finally { if (mounted) setState(() => _busy = false); }
  }

  @override
  Widget build(BuildContext context) {
    final config = ref.watch(habitCounterProvider(widget.habitId));
    final history = ref.watch(habitCounterHistoryProvider(widget.habitId));
    final palette = NeoPalette.of(context);
    return Scaffold(appBar: AppBar(title: const Text('COUNTER HABIT')),
      body: config.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, __) => NeoErrorCard(onRetry: () => ref.invalidate(habitCounterProvider(widget.habitId))),
        data: (counter) => history.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, __) => NeoErrorCard(onRetry: () => ref.invalidate(habitCounterHistoryProvider(widget.habitId))),
          data: (days) {
            final todayKey = CivilDate.today().key;
            final current = days.where((day) => day.date.key == todayKey).fold<int>(0, (_, day) => day.amount);
            return ListView(padding: const EdgeInsets.fromLTRB(16, 12, 16, 30), children: [
              Text(widget.habitName, style: Theme.of(context).textTheme.headlineSmall),
              const SizedBox(height: 12),
              NeoCard(color: palette.primary, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                if (counter == null) const Text('Atur target untuk mulai mencatat progres.') else ...[
                  Text('$current / ${counter.target} ${counter.unit}', style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 8),
                  NeoProgressBar(progress: current / counter.target),
                  const SizedBox(height: 8),
                  Text('${(100 * current / counter.target).round()}% · ${current >= counter.target ? 'Target tercapai' : 'Sedang berlangsung'}'),
                  const SizedBox(height: 8),
                  Wrap(spacing: 8, children: [
                    OutlinedButton.icon(onPressed: _busy || current == 0 ? null : () => _change(-1), icon: const Icon(Icons.remove), label: const Text('Kurangi')),
                    FilledButton.icon(onPressed: _busy || current >= 1000000 ? null : () => _change(1), icon: const Icon(Icons.add), label: const Text('Tambah')),
                  ]),
                ],
                const SizedBox(height: 8),
                OutlinedButton(onPressed: _busy ? null : () => _configure(counter), child: Text(counter == null ? 'Atur target' : 'Ubah target')),
              ])),
              const SizedBox(height: 12),
              const Text('Counter ini terpisah dari check-in dan tanda selesai habit; target tercapai tidak otomatis mengubah streak. Perubahan target berlaku pada tampilan semua tanggal.', style: TextStyle(fontSize: 12)),
              const SizedBox(height: 16),
              const NeoSectionTitle('RIWAYAT HARIAN'),
              const SizedBox(height: 8),
              if (days.isEmpty) const NeoCard(child: Text('Belum ada progres tercatat.')),
              for (final day in days) ...[
                NeoCard(shadow: false, child: Row(children: [
                  Expanded(child: Text(DateFormat('d MMMM yyyy', 'id_ID').format(day.date.value))),
                  Text('${day.amount} ${counter?.unit ?? ''}', style: const TextStyle(fontWeight: FontWeight.w900)),
                ])), const SizedBox(height: 8),
              ],
            ]);
          },
        ),
      ));
  }
}
