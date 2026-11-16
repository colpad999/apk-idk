import 'package:apk_idk/app/theme/neo_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

double contrast(Color a, Color b) {
  final x = a.computeLuminance();
  final y = b.computeLuminance();
  return ((x > y ? x : y) + .05) / ((x < y ? x : y) + .05);
}

void main() {
  test('dark ink remains readable against bright palette colors', () {
    const p = NeoPalette.light;
    for (final background in [p.background, p.surface, p.primary, p.secondary, p.accent, p.highlight, p.mutedSurface, const Color(0xFFFFA77F)]) {
      expect(contrast(p.text, background), greaterThanOrEqualTo(4.5));
    }
  });
}
