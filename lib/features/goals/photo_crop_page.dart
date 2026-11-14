import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../app/theme/neo_theme.dart';
import '../../services/goal_photo_storage.dart';
import '../../shared/neo_components.dart';
import '../../shared/neo_feedback.dart';

class PhotoCropPage extends StatefulWidget {
  const PhotoCropPage({required this.source, super.key});
  final File source;
  @override
  State<PhotoCropPage> createState() => _PhotoCropPageState();
}

enum _CropRatio { original, square, wide }

class _PhotoCropPageState extends State<PhotoCropPage> {
  PreparedGoalPhoto? _prepared;
  Object? _error;
  _CropRatio _ratio = _CropRatio.original;
  double _zoom = 1, _offsetX = 0, _offsetY = 0;
  double _startZoom = 1, _startOffsetX = 0, _startOffsetY = 0;
  double _viewportWidth = 1, _viewportHeight = 1;
  bool _processing = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _error = null;
      _prepared = null;
    });
    try {
      if (!await widget.source.exists() ||
          await widget.source.length() > maxPhotoInputBytes) {
        throw const FormatException('Foto tidak tersedia atau terlalu besar.');
      }
      final prepared = await processGoalPhoto(await widget.source.readAsBytes());
      if (mounted) setState(() => _prepared = prepared);
    } catch (error) {
      if (mounted) setState(() => _error = error);
    }
  }

  double get _aspectRatio => switch (_ratio) {
        _CropRatio.original => _prepared!.width / _prepared!.height,
        _CropRatio.square => 1,
        _CropRatio.wide => 16 / 10,
      };

  void _clampOffset() {
    final photo = _prepared!;
    final base = math.max(_viewportWidth / photo.width, _viewportHeight / photo.height);
    final displayedWidth = photo.width * base * _zoom;
    final displayedHeight = photo.height * base * _zoom;
    final maxX = math.max(0.0, (displayedWidth - _viewportWidth) / 2);
    final maxY = math.max(0.0, (displayedHeight - _viewportHeight) / 2);
    _offsetX = _offsetX.clamp(-maxX, maxX);
    _offsetY = _offsetY.clamp(-maxY, maxY);
  }

  Future<void> _apply() async {
    if (_prepared == null || _processing) return;
    setState(() => _processing = true);
    try {
      _clampOffset();
      final crop = cropRectForViewport(
        imageWidth: _prepared!.width,
        imageHeight: _prepared!.height,
        viewportWidth: _viewportWidth,
        viewportHeight: _viewportHeight,
        zoom: _zoom,
        offsetX: _offsetX,
        offsetY: _offsetY,
      );
      final result = await processGoalPhoto(_prepared!.bytes, crop: crop);
      if (mounted) Navigator.pop(context, result);
    } catch (error) {
      if (mounted) showNeoMessage(context, friendlyError(error));
    } finally {
      if (mounted) setState(() => _processing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = NeoPalette.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('ATUR FOTO TUJUAN')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
        children: [
          Text('Pilih bagian yang penting.', style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 6),
          Text('Geser dan cubit untuk zoom. Rasio tetap terjaga; hasil dikompresi maksimal 1600 px.',
              style: TextStyle(color: palette.muted)),
          const SizedBox(height: 16),
          if (_error != null)
            NeoErrorCard(message: friendlyError(_error!), onRetry: _load)
          else if (_prepared == null)
            const SizedBox(height: 280, child: Center(child: CircularProgressIndicator()))
          else ...[
            SegmentedButton<_CropRatio>(
              segments: const [
                ButtonSegment(value: _CropRatio.original, label: Text('Asli')),
                ButtonSegment(value: _CropRatio.square, label: Text('1:1')),
                ButtonSegment(value: _CropRatio.wide, label: Text('16:10')),
              ],
              selected: {_ratio},
              showSelectedIcon: false,
              onSelectionChanged: (selection) => setState(() {
                _ratio = selection.first;
                _zoom = 1;
                _offsetX = _offsetY = 0;
              }),
            ),
            const SizedBox(height: 13),
            LayoutBuilder(builder: (context, constraints) {
              var width = constraints.maxWidth;
              var height = width / _aspectRatio;
              if (height > 360) {
                height = 360;
                width = height * _aspectRatio;
              }
              _viewportWidth = width;
              _viewportHeight = height;
              _clampOffset();
              return Center(
                child: SizedBox(
                  width: width,
                  height: height,
                  child: ClipRect(
                    child: GestureDetector(
                      onScaleStart: (_) {
                        _startZoom = _zoom;
                        _startOffsetX = _offsetX;
                        _startOffsetY = _offsetY;
                      },
                      onScaleUpdate: (details) => setState(() {
                        _zoom = (_startZoom * details.scale).clamp(1.0, 4.0);
                        _offsetX = _startOffsetX + details.focalPointDelta.dx;
                        _offsetY = _startOffsetY + details.focalPointDelta.dy;
                        _clampOffset();
                      }),
                      child: Transform.translate(
                        offset: Offset(_offsetX, _offsetY),
                        child: Transform.scale(
                          scale: _zoom,
                          child: Image.memory(
                            _prepared!.bytes,
                            width: width,
                            height: height,
                            fit: BoxFit.cover,
                            gaplessPlayback: true,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              );
            }),
            const SizedBox(height: 12),
            Text('Zoom ${_zoom.toStringAsFixed(1)}× · pratinjau ini sama dengan area yang disimpan.',
                textAlign: TextAlign.center, style: TextStyle(color: palette.muted, fontSize: 11)),
          ],
          const SizedBox(height: 18),
          Row(children: [
            Expanded(
              child: OutlinedButton(
                onPressed: _processing ? null : () => Navigator.pop(context),
                child: const Text('Batal'),
              ),
            ),
            const SizedBox(width: 9),
            Expanded(
              child: FilledButton.icon(
                onPressed: _prepared == null || _processing ? null : _apply,
                icon: const Icon(Icons.crop, size: 18),
                label: Text(_processing ? 'Memproses...' : 'Pakai foto'),
              ),
            ),
          ]),
        ],
      ),
    );
  }
}
