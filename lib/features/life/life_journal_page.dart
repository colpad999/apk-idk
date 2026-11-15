import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../app/providers.dart';
import '../../app/theme/neo_theme.dart';
import '../../data/life_repository.dart';
import '../../shared/neo_components.dart';
import '../../shared/neo_feedback.dart';

const _moods = ['Buruk', 'Kurang baik', 'Biasa saja', 'Baik', 'Sangat baik'];

class LifeJournalPage extends ConsumerWidget {
  const LifeJournalPage({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final entries = ref.watch(lifeEntriesProvider);
    return Scaffold(appBar: AppBar(title: const Text('JURNAL & MOOD')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.push(context, MaterialPageRoute<void>(builder: (_) => const _EntryEditor())),
        icon: const Icon(Icons.add), label: const Text('Catat hari ini')),
      body: entries.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, __) => NeoErrorCard(onRetry: () => ref.invalidate(lifeEntriesProvider)),
        data: (items) => ListView(padding: const EdgeInsets.fromLTRB(16, 12, 16, 100), children: [
          const NeoCard(child: Text('Catatan dan mood tersimpan di perangkat. Mood adalah refleksi pribadi, bukan diagnosis.')),
          const SizedBox(height: 16),
          if (items.isEmpty) const NeoCard(child: Text('Belum ada catatan. Mulai kapan pun kamu siap.')),
          for (final entry in items) ...[
            NeoCard(child: ListTile(contentPadding: EdgeInsets.zero,
              title: Text(DateFormat('EEEE, d MMMM yyyy', 'id_ID').format(entry.date.value)),
              subtitle: Text([if (entry.mood != null) _moods[entry.mood! - 1], if (entry.journal.isNotEmpty) entry.journal, if (entry.moodNote.isNotEmpty) entry.moodNote].join(' · '), maxLines: 3, overflow: TextOverflow.ellipsis),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.push(context, MaterialPageRoute<void>(builder: (_) => _EntryEditor(entry: entry))),
            )), const SizedBox(height: 12),
          ],
        ]),
      ));
  }
}

class _EntryEditor extends ConsumerStatefulWidget {
  const _EntryEditor({this.entry});
  final LifeEntry? entry;
  @override
  ConsumerState<_EntryEditor> createState() => _EntryEditorState();
}

class _EntryEditorState extends ConsumerState<_EntryEditor> {
  late DateTime _date;
  late final TextEditingController _journal, _note;
  int? _mood;
  bool _busy = false;
  @override
  void initState() {
    super.initState();
    _date = widget.entry?.date.value ?? DateTime.now();
    _journal = TextEditingController(text: widget.entry?.journal ?? '');
    _note = TextEditingController(text: widget.entry?.moodNote ?? '');
    _mood = widget.entry?.mood;
  }
  @override
  void dispose() { _journal.dispose(); _note.dispose(); super.dispose(); }

  Future<void> _save() async {
    if (_busy) return;
    // Prevent accidentally overwriting another day when creating a new entry.
    final existing = await ref.read(lifeRepositoryProvider).list();
    if (!mounted) return;
    if (widget.entry == null && existing.any((e) => e.date.key == '${_date.year.toString().padLeft(4, '0')}-${_date.month.toString().padLeft(2, '0')}-${_date.day.toString().padLeft(2, '0')}')) {
      showNeoMessage(context, 'Tanggal ini sudah ada. Buka catatan tersebut untuk mengedit.');
      return;
    }
    setState(() => _busy = true);
    try {
      await ref.read(lifeRepositoryProvider).save(_date, _journal.text, _mood, _note.text);
      ref.invalidate(lifeEntriesProvider);
      if (mounted) Navigator.pop(context);
    } catch (error) {
      if (mounted) { showNeoMessage(context, friendlyError(error)); }
    } finally { if (mounted) setState(() => _busy = false); }
  }

  @override
  Widget build(BuildContext context) {
    final p = NeoPalette.of(context);
    return Scaffold(appBar: AppBar(title: const Text('CATAT HARI')),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        NeoCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          OutlinedButton.icon(onPressed: widget.entry != null ? null : () async {
            final date = await showDatePicker(context: context, initialDate: _date, firstDate: DateTime(2000), lastDate: DateTime(2100));
            if (date != null && mounted) setState(() => _date = date);
          }, icon: const Icon(Icons.calendar_today), label: Text(DateFormat('d MMMM yyyy', 'id_ID').format(_date))),
          const SizedBox(height: 12),
          TextField(controller: _journal, maxLength: 10000, minLines: 4, maxLines: 8, decoration: const InputDecoration(labelText: 'Jurnal dan kegiatan')),
          const SizedBox(height: 12),
          Text('Bagaimana suasana hatimu?', style: Theme.of(context).textTheme.titleMedium),
          Wrap(spacing: 6, children: [for (var i = 1; i <= 5; i++) ChoiceChip(label: Text(_moods[i - 1]), selected: _mood == i, onSelected: (_) => setState(() => _mood = _mood == i ? null : i))]),
          const SizedBox(height: 12),
          TextField(controller: _note, maxLength: 2000, minLines: 2, maxLines: 4, decoration: const InputDecoration(labelText: 'Catatan mood (opsional)')),
          const SizedBox(height: 12),
          NeoButton(label: 'Simpan', onPressed: _busy ? null : _save, loading: _busy, color: p.primary),
          if (widget.entry != null) TextButton.icon(onPressed: _busy ? null : () async {
            final confirmed = await confirmNeoAction(context, title: 'Hapus catatan?', message: 'Jurnal dan mood pada tanggal ini akan dihapus.', confirmLabel: 'Hapus', destructive: true);
            if (!confirmed || !context.mounted) return;
            try {
              await ref.read(lifeRepositoryProvider).delete(_date);
              ref.invalidate(lifeEntriesProvider);
              if (context.mounted) Navigator.pop(context);
            } catch (error) { if (context.mounted) { showNeoMessage(context, friendlyError(error)); } }
          }, icon: const Icon(Icons.delete_outline), label: const Text('Hapus catatan')),
        ])),
      ]));
  }
}
