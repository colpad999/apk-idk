import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../app/theme/neo_theme.dart';

class GoalCover extends ConsumerWidget {
  const GoalCover({required this.path, required this.name, this.height = 150, super.key});
  final String? path;
  final String name;
  final double height;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (path == null) return _Placeholder(name: name, height: height);
    final storage = ref.watch(goalPhotoStorageProvider);
    return FutureBuilder<File?>(
      future: storage.fileFor(path),
      builder: (context, snapshot) {
        final file = snapshot.data;
        if (file == null) return _Placeholder(name: name, height: height);
        return SizedBox(
          height: height,
          width: double.infinity,
          child: Image.file(
            file,
            height: height,
            width: double.infinity,
            fit: BoxFit.cover,
            cacheWidth: 900,
            semanticLabel: 'Foto tujuan $name',
            errorBuilder: (_, __, ___) => _Placeholder(
                name: name, height: height, unavailable: true),
          ),
        );
      },
    );
  }
}

class _Placeholder extends StatelessWidget {
  const _Placeholder({required this.name, required this.height, this.unavailable = false});
  final String name;
  final double height;
  final bool unavailable;
  @override
  Widget build(BuildContext context) {
    final palette = NeoPalette.of(context);
    return Container(
      height: height,
      width: double.infinity,
      color: palette.accent,
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(unavailable ? Icons.image_not_supported_outlined : Icons.flag_rounded,
            size: height > 180 ? 58 : 40, color: const Color(0xFF171717)),
        const SizedBox(height: 7),
        Text(unavailable ? 'FOTO TIDAK TERSEDIA' : 'FOTO TUJUAN',
            style: const TextStyle(color: Color(0xFF171717), fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1)),
        if (unavailable)
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 14, vertical: 4),
            child: Text('Target dan saldo tetap aman.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Color(0xFF171717), fontSize: 10)),
          ),
      ]),
    );
  }
}
