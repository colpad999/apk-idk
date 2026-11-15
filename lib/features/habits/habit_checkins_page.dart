import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../app/providers.dart';
import '../../data/habit_checkin_repository.dart';
import '../../shared/neo_components.dart';
import '../../shared/neo_feedback.dart';

class HabitCheckinsPage extends ConsumerStatefulWidget {
  const HabitCheckinsPage({required this.habitId, required this.habitName, super.key});
  final int habitId;
  final String habitName;
  @override
  ConsumerState<HabitCheckinsPage> createState() => _HabitCheckinsPageState();
}

class _HabitCheckinsPageState extends ConsumerState<HabitCheckinsPage> {
  bool _busy = false;

  Future<void> _edit([HabitCheckin? checkin]) async {
    if (_busy) return;
    final controller = TextEditingController(text: checkin?.note ?? '');
    final note = await showDialog<String>(context: context, builder: (dialogContext) => AlertDialog(
      title: Text(checkin == null ? 'Check-in baru' : 'Edit catatan check-in'),
      content: TextField(controller: controller, maxLength: 500, minLines: 2, maxLines: 4,
        decoration: const InputDecoration(labelText: 'Catatan (opsional)')),
      actions: [
        TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Batal')),
        FilledButton(onPressed: () => Navigator.pop(dialogContext, controller.text), child: const Text('Simpan')),
      ],
    ));
    controller.dispose();
    if (!mounted || note == null || _busy) return;
    setState(() => _busy = true);
    try {
      final repository = ref.read(habitCheckinRepositoryProvider);
      if (checkin == null) {
        await repository.add(widget.habitId, note);
      } else {
        await repository.edit(widget.habitId, checkin.id, note);
      }
      ref.invalidate(habitCheckinsProvider(widget.habitId));
    } catch (error) {
      if (mounted) { showNeoMessage(context, friendlyError(error)); }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _delete(HabitCheckin checkin) async {
    if (_busy) return;
    final confirmed = await confirmNeoAction(context, title: 'Hapus check-in?',
      message: 'Catatan check-in ini akan dihapus. Status selesai habit tidak berubah.',
      confirmLabel: 'Hapus', destructive: true);
    if (!confirmed || !mounted || _busy) return;
    setState(() => _busy = true);
    try {
      await ref.read(habitCheckinRepositoryProvider).delete(widget.habitId, checkin.id);
      ref.invalidate(habitCheckinsProvider(widget.habitId));
    } catch (error) {
      if (mounted) { showNeoMessage(context, friendlyError(error)); }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final checkins = ref.watch(habitCheckinsProvider(widget.habitId));
    return Scaffold(appBar: AppBar(title: const Text('RIWAYAT CHECK-IN')),
      floatingActionButton: FloatingActionButton.extended(onPressed: _busy ? null : () => _edit(),
        icon: const Icon(Icons.add), label: const Text('Check-in')),
      body: checkins.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, __) => NeoErrorCard(onRetry: () => ref.invalidate(habitCheckinsProvider(widget.habitId))),
        data: (items) => ListView(padding: const EdgeInsets.fromLTRB(16, 12, 16, 100), children: [
          Text(widget.habitName, style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 8),
          const NeoCard(child: Text('Catat aktivitas berkali-kali. Check-in adalah catatan terpisah dan tidak otomatis mengubah tanda selesai atau streak.')),
          const SizedBox(height: 14),
          if (items.isEmpty) const NeoCard(child: Text('Belum ada check-in.')),
          for (final checkin in items) ...[
            NeoCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('${DateFormat('d MMM yyyy', 'id_ID').format(checkin.localDate.value)} · ${DateFormat('HH:mm').format(checkin.recordedAt)}', style: const TextStyle(fontWeight: FontWeight.w900)),
              if (checkin.note.isNotEmpty) ...[const SizedBox(height: 6), Text(checkin.note)],
              Wrap(spacing: 8, children: [
                TextButton.icon(onPressed: _busy ? null : () => _edit(checkin), icon: const Icon(Icons.edit_outlined), label: const Text('Edit')),
                TextButton.icon(onPressed: _busy ? null : () => _delete(checkin), icon: const Icon(Icons.delete_outline), label: const Text('Hapus')),
              ]),
            ])),
            const SizedBox(height: 12),
          ],
        ]),
      ));
  }
}
