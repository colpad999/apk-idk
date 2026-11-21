import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../app/theme/neo_theme.dart';
import '../../shared/neo_components.dart';
import '../../shared/neo_feedback.dart';

class ProfilePage extends ConsumerStatefulWidget {
  const ProfilePage({super.key});
  @override
  ConsumerState<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends ConsumerState<ProfilePage> {
  final _name = TextEditingController(), _note = TextEditingController();
  bool _loading = true, _saving = false, _failed = false;
  @override
  void initState() { super.initState(); _load(); }
  Future<void> _load() async {
    setState(() { _loading = true; _failed = false; });
    try {
      final profile = await ref.read(appSettingsRepositoryProvider).profile();
      if (!mounted) return;
      _name.text = profile.name; _note.text = profile.note;
    } catch (_) { if (mounted) { setState(() => _failed = true); } }
    finally { if (mounted) { setState(() => _loading = false); } }
  }
  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await ref.read(appSettingsRepositoryProvider).saveProfile(name: _name.text, note: _note.text);
      ref.invalidate(localProfileProvider);
      if (mounted) { showNeoMessage(context, 'Profil tersimpan di perangkat.'); }
    } catch (error) { if (mounted) { showNeoMessage(context, friendlyError(error)); } }
    finally { if (mounted) { setState(() => _saving = false); } }
  }
  @override
  void dispose() { _name.dispose(); _note.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) => Scaffold(appBar: AppBar(title: const Text('PROFIL')),
    body: _loading ? const Center(child: CircularProgressIndicator()) : _failed ? Center(child: NeoErrorCard(onRetry: _load)) : ListView(padding: const EdgeInsets.all(16), children: [
      NeoCard(color: NeoPalette.of(context).primary, child: const Text('Profil pribadi lokal, tanpa akun atau sinkronisasi online. Nama dan catatan ikut backup Colpad.')),
      const SizedBox(height: 14),
      NeoCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        TextField(controller: _name, maxLength: 100, textCapitalization: TextCapitalization.words, decoration: const InputDecoration(labelText: 'Nama panggilan (opsional)')),
        const SizedBox(height: 12),
        TextField(controller: _note, maxLength: 500, minLines: 2, maxLines: 4, decoration: const InputDecoration(labelText: 'Catatan profil (opsional)')),
        const SizedBox(height: 12),
        FilledButton.icon(onPressed: _saving ? null : _save, icon: const Icon(Icons.save_outlined), label: Text(_saving ? 'Menyimpan...' : 'Simpan profil')),
      ])),
    ]));
}
