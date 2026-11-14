import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';

const maxPhotoInputBytes = 20 * 1024 * 1024;
const maxPhotoOutputBytes = 8 * 1024 * 1024;
const maxPhotoDimension = 1600;

class PhotoCrop {
  const PhotoCrop({
    required this.x,
    required this.y,
    required this.width,
    required this.height,
  });
  final int x, y, width, height;
}

class PreparedGoalPhoto {
  const PreparedGoalPhoto({
    required this.bytes,
    required this.width,
    required this.height,
  });
  final Uint8List bytes;
  final int width, height;
}

/// Maps the interactive cover preview back to source pixels. The preview uses
/// BoxFit.cover, centered translation, and uniform zoom; no aspect distortion.
PhotoCrop cropRectForViewport({
  required int imageWidth,
  required int imageHeight,
  required double viewportWidth,
  required double viewportHeight,
  required double zoom,
  required double offsetX,
  required double offsetY,
}) {
  if (imageWidth <= 0 || imageHeight <= 0 ||
      viewportWidth <= 0 || viewportHeight <= 0 || zoom < 1) {
    throw ArgumentError('Ukuran pratinjau foto tidak valid.');
  }
  final baseScale = math.max(viewportWidth / imageWidth, viewportHeight / imageHeight);
  final scale = baseScale * zoom;
  final visibleWidth = math.min(imageWidth.toDouble(), viewportWidth / scale);
  final visibleHeight = math.min(imageHeight.toDouble(), viewportHeight / scale);
  final centerX = imageWidth / 2 - offsetX / scale;
  final centerY = imageHeight / 2 - offsetY / scale;
  final left = (centerX - visibleWidth / 2)
      .clamp(0, math.max(0, imageWidth - visibleWidth));
  final top = (centerY - visibleHeight / 2)
      .clamp(0, math.max(0, imageHeight - visibleHeight));
  return PhotoCrop(
    x: left.round(),
    y: top.round(),
    width: math.max(1, visibleWidth.round()),
    height: math.max(1, visibleHeight.round()),
  );
}

Future<PreparedGoalPhoto> processGoalPhoto(Uint8List bytes, {PhotoCrop? crop}) =>
    compute(_prepareGoalPhoto, (bytes, crop));

/// Runs in a worker isolate so decoding/encoding does not block the UI thread.
PreparedGoalPhoto _prepareGoalPhoto((Uint8List, PhotoCrop?) input) {
  final (bytes, crop) = input;
  if (bytes.isEmpty || bytes.length > maxPhotoInputBytes) {
    throw const FormatException('Berkas kosong atau lebih besar dari 20 MB.');
  }
  var image = img.decodeImage(bytes);
  if (image == null) {
    throw const FormatException('Berkas bukan gambar yang dapat dibaca.');
  }
  if (image.width * image.height > 40000000) {
    throw const FormatException('Resolusi gambar terlalu besar.');
  }
  image = img.bakeOrientation(image);
  if (crop != null) {
    if (crop.x < 0 || crop.y < 0 || crop.width <= 0 || crop.height <= 0 ||
        crop.x + crop.width > image.width ||
        crop.y + crop.height > image.height) {
      throw const FormatException('Area potong berada di luar gambar.');
    }
    image = img.copyCrop(image,
        x: crop.x, y: crop.y, width: crop.width, height: crop.height);
  }
  if (image.width > maxPhotoDimension || image.height > maxPhotoDimension) {
    final landscape = image.width >= image.height;
    image = img.copyResize(
      image,
      width: landscape ? maxPhotoDimension : null,
      height: landscape ? null : maxPhotoDimension,
      interpolation: img.Interpolation.linear,
      maintainAspect: true,
    );
  }
  final encoded = Uint8List.fromList(img.encodeJpg(image, quality: 85));
  if (encoded.length > maxPhotoOutputBytes) {
    throw const FormatException('Hasil kompresi gambar masih terlalu besar.');
  }
  return PreparedGoalPhoto(
      bytes: encoded, width: image.width, height: image.height);
}

class GoalPhotoStorage {
  GoalPhotoStorage({Future<Directory> Function()? rootDirectory})
      : _rootDirectory = rootDirectory ?? getApplicationDocumentsDirectory;
  final Future<Directory> Function() _rootDirectory;
  static final _relativePath = RegExp(r'^goal_covers/[A-Za-z0-9_-]+\.jpg$');

  static bool isManagedRelativePath(String path) => _relativePath.hasMatch(path);

  /// New records store relative paths. Older absolute paths are read only when
  /// they still live inside this app's persistent documents directory.
  Future<File?> fileFor(String? storedPath) async {
    if (storedPath == null || storedPath.isEmpty) return null;
    final root = await _rootDirectory();
    if (isManagedRelativePath(storedPath)) {
      return File('${root.path}/$storedPath');
    }
    if (storedPath.startsWith('/')) {
      final rootPath = root.absolute.path.replaceAll(RegExp(r'/+$'), '');
      final file = File(storedPath).absolute;
      final normalized = file.uri.normalizePath().toFilePath();
      if (normalized.startsWith('$rootPath/') && normalized.endsWith('.jpg')) {
        return file;
      }
    }
    return null;
  }

  Future<String> importFile(File source, {PhotoCrop? crop}) async {
    if (!await source.exists() || await source.length() > maxPhotoInputBytes) {
      throw const FormatException('Foto tidak tersedia atau terlalu besar.');
    }
    final prepared = await processGoalPhoto(await source.readAsBytes(), crop: crop);
    return savePrepared(prepared.bytes);
  }

  /// Persist bytes already validated/normalized by [processGoalPhoto].
  Future<String> savePrepared(Uint8List bytes) async {
    if (bytes.length < 3 || bytes.length > maxPhotoOutputBytes ||
        bytes[0] != 0xff || bytes[1] != 0xd8 || bytes[2] != 0xff) {
      throw const FormatException('Foto harus berupa JPEG yang valid.');
    }
    final root = await _rootDirectory();
    final directory = Directory('${root.path}/goal_covers');
    await directory.create(recursive: true);
    final random = math.Random.secure();
    final token = List.generate(16, (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0')).join();
    final name = '${DateTime.now().microsecondsSinceEpoch}_$token';
    final temporary = File('${directory.path}/$name.part');
    final relative = 'goal_covers/$name.jpg';
    try {
      await temporary.writeAsBytes(bytes, flush: true);
      await temporary.rename('${root.path}/$relative');
      return relative;
    } catch (_) {
      if (await temporary.exists()) await temporary.delete();
      rethrow;
    }
  }

  Future<void> delete(String? storedPath) async {
    final file = await fileFor(storedPath);
    if (file != null && await file.exists()) await file.delete();
  }
}
