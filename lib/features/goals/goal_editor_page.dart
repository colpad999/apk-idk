import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

import '../../app/providers.dart';
import '../../app/theme/neo_theme.dart';
import '../../data/savings_transaction.dart';
import '../../services/goal_photo_storage.dart';
import '../../shared/neo_components.dart';
import '../../shared/neo_feedback.dart';
import 'goal_cover.dart';
import 'photo_crop_page.dart';

class GoalEditorPage extends ConsumerStatefulWidget {
  const GoalEditorPage({this.goal, super.key});
  final SavingGoal? goal;
  @override
  ConsumerState<GoalEditorPage> createState() => _GoalEditorPageState();
}

class _GoalEditorPageState extends ConsumerState<GoalEditorPage> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name, _amount;
  late DateTime? _deadline;
  PreparedGoalPhoto? _newPhoto;
  bool _removePhoto = false, _saving = false, _picking = false;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: widget.goal?.name ?? '');
    _amount = TextEditingController(text: widget.goal?.targetAmount.toString() ?? '');
    _deadline = widget.goal?.deadline;
  }

  @override
  void dispose() {
    _name.dispose();
    _amount.dispose();
    super.dispose();
  }

  Future<void> _pickPhoto() async {
    if (_picking) return;
    setState(() => _picking = true);
    try {
      final picked = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        maxWidth: 1600,
        maxHeight: 1600,
        imageQuality: 90,
      );
      if (picked == null || !mounted) return;
      final prepared = await Navigator.of(context).push<PreparedGoalPhoto>(
        MaterialPageRoute(builder: (_) => PhotoCropPage(source: File(picked.path))),
      );
      if (prepared != null && mounted) {
        setState(() {
          _newPhoto = prepared;
          _removePhoto = false;
        });
      }
    } on PlatformException {
      if (mounted) {
        showNeoMessage(context,
            'Galeri tidak dapat dibuka. Periksa izin foto yang diminta pemilih sistem; Colpad tidak meminta akses seluruh penyimpanan.');
      }
    } catch (error) {
      if (mounted) showNeoMessage(context, friendlyError(error));
    } finally {
      if (mounted) setState(() => _picking = false);
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate() || _saving) return;
    setState(() => _saving = true);
    final storage = ref.read(goalPhotoStorageProvider);
    final repository = ref.read(goalRepositoryProvider);
    String? newPath;
    try {
      if (_newPhoto != null) newPath = await storage.savePrepared(_newPhoto!.bytes);
      final effectivePath = _newPhoto != null
          ? newPath
          : _removePhoto
              ? null
              : widget.goal?.coverPhotoPath;
      if (widget.goal == null) {
        await repository.create(
          name: _name.text,
          targetAmount: int.parse(_amount.text),
          deadline: _deadline,
          coverPhotoPath: effectivePath,
        );
      } else {
        final oldPath = await repository.update(
          id: widget.goal!.id,
          name: _name.text,
          targetAmount: int.parse(_amount.text),
          deadline: _deadline,
          coverPhotoPath: effectivePath,
        );
        if (oldPath != null && oldPath != effectivePath &&
            !await repository.isPhotoReferenced(oldPath)) {
          try {
            await storage.delete(oldPath);
          } catch (_) {
            // The database is already committed; an orphaned file must not
            // make a successful edit look failed or crash the page.
          }
        }
      }
      ref.invalidate(savingGoalsProvider);
      if (mounted) {
        showNeoMessage(context, 'Target tersimpan.');
        Navigator.pop(context);
      }
    } catch (error) {
      if (newPath != null) {
        try {
          await storage.delete(newPath);
        } catch (_) {}
      }
      if (mounted) showNeoMessage(context, friendlyError(error));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = NeoPalette.of(context);
    final hasPhoto = _newPhoto != null ||
        (!_removePhoto && widget.goal?.coverPhotoPath != null);
    return Scaffold(
      appBar: AppBar(title: Text(widget.goal == null ? 'BUAT TARGET' : 'EDIT TARGET')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 30),
          children: [
            Text('Tujuan yang terlihat nyata.', style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 6),
            Text('Foto opsional. Target tetap bisa dibuat dan digunakan tanpa foto.',
                style: TextStyle(color: palette.muted)),
            const SizedBox(height: 17),
            NeoCard(
              padding: EdgeInsets.zero,
              child: Column(children: [
                if (_newPhoto != null)
                  Image.memory(_newPhoto!.bytes, height: 190, width: double.infinity, fit: BoxFit.cover)
                else
                  GoalCover(
                    path: _removePhoto ? null : widget.goal?.coverPhotoPath,
                    name: _name.text.trim().isEmpty ? 'Tujuan baru' : _name.text,
                    height: 190,
                  ),
                Padding(
                  padding: const EdgeInsets.all(10),
                  child: Wrap(spacing: 7, runSpacing: 7, children: [
                    OutlinedButton.icon(
                      onPressed: _picking ? null : _pickPhoto,
                      icon: const Icon(Icons.photo_library_outlined, size: 18),
                      label: Text(_picking ? 'Membuka galeri...' : hasPhoto ? 'Ganti foto' : 'Pilih dari galeri'),
                    ),
                    if (hasPhoto)
                      OutlinedButton.icon(
                        onPressed: () => setState(() {
                          _newPhoto = null;
                          _removePhoto = true;
                        }),
                        icon: const Icon(Icons.delete_outline, size: 18),
                        label: const Text('Hapus foto'),
                      ),
                  ]),
                ),
              ]),
            ),
            const SizedBox(height: 8),
            Text('Pratinjau disimpan sebagai salinan JPEG terkompresi di penyimpanan privat aplikasi.',
                style: TextStyle(color: palette.muted, fontSize: 11)),
            const SizedBox(height: 15),
            TextFormField(
              controller: _name,
              maxLength: 80,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(labelText: 'Nama target'),
              validator: (value) => value == null || value.trim().isEmpty ? 'Nama target wajib diisi.' : null,
            ),
            TextFormField(
              controller: _amount,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(12)],
              decoration: const InputDecoration(labelText: 'Nominal target', prefixText: 'Rp '),
              validator: (value) {
                final amount = int.tryParse(value ?? '');
                return amount == null || amount <= 0 ? 'Masukkan nominal lebih dari Rp0.' : null;
              },
            ),
            const SizedBox(height: 13),
            OutlinedButton.icon(
              onPressed: () async {
                final now = DateTime.now();
                final picked = await showDatePicker(
                  context: context,
                  initialDate: _deadline ?? now,
                  firstDate: DateTime(now.year - 5),
                  lastDate: DateTime(now.year + 30),
                );
                if (picked != null) setState(() => _deadline = picked);
              },
              icon: const Icon(Icons.event_outlined, size: 18),
              label: Text(_deadline == null
                  ? 'Pilih deadline (opsional)'
                  : 'Deadline ${DateFormat('d MMMM yyyy', 'id_ID').format(_deadline!)}'),
            ),
            if (_deadline != null)
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(onPressed: () => setState(() => _deadline = null), child: const Text('Hapus deadline')),
              ),
            const SizedBox(height: 18),
            FilledButton.icon(
              onPressed: _saving ? null : _save,
              icon: _saving
                  ? const SizedBox.square(dimension: 18, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.save_outlined),
              label: Text(_saving ? 'Menyimpan...' : 'Simpan target'),
            ),
          ],
        ),
      ),
    );
  }
}
