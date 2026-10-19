import 'dart:math';

import 'package:flutter/material.dart';

int seedOf(String s) {
  var a = 0;
  for (final c in s.codeUnits) {
    a = (a * 31 + c) & 0x7fffffff;
  }
  return a;
}

const _skies = [Color(0xFFE6EFE8), Color(0xFFF6ECD2), Color(0xFFE3E8F1), Color(0xFFEAF0E2)];
const _defaultLayers = [Color(0xFFB7CDBD), Color(0xFF7AA38F), Color(0xFF2F6B57)];

// Hill ridgelines drawn in code. The same seed always gives the same picture, so a property
// without photos keeps its own look. Also used in the home screen header.
class RidgePainter extends CustomPainter {
  final int seed;
  final bool sky;
  final List<Color> layers;

  const RidgePainter({required this.seed, this.sky = true, this.layers = _defaultLayers});

  @override
  void paint(Canvas canvas, Size size) {
    final rnd = Random(seed);
    final w = size.width;
    final h = size.height;
    if (sky) {
      canvas.drawRect(Rect.fromLTWH(0, 0, w, h), Paint()..color = _skies[rnd.nextInt(_skies.length)]);
      final sunX = w * (0.2 + rnd.nextDouble() * 0.6);
      canvas.drawCircle(Offset(sunX, h * 0.24), h * 0.075, Paint()..color = const Color(0xFFF4B000));
    }
    for (var i = 0; i < layers.length; i++) {
      final base = h * (0.52 + i * 0.17);
      final amp = h * (0.3 - i * 0.04);
      const steps = 7;
      final pts = <Offset>[];
      for (var j = 0; j <= steps; j++) {
        pts.add(Offset(w / steps * j, base - rnd.nextDouble() * amp));
      }
      final path = Path()
        ..moveTo(0, h)
        ..lineTo(pts[0].dx, pts[0].dy);
      for (var j = 1; j < pts.length; j++) {
        final a = pts[j - 1];
        final b = pts[j];
        final mx = (a.dx + b.dx) / 2;
        path.cubicTo(mx, a.dy, mx, b.dy, b.dx, b.dy);
      }
      path
        ..lineTo(w, h)
        ..close();
      canvas.drawPath(path, Paint()..color = layers[i]);
    }
  }

  @override
  bool shouldRepaint(covariant RidgePainter old) => old.seed != seed || old.sky != sky;
}

class Ridge extends StatelessWidget {
  final String seed;
  final bool sky;
  final List<Color>? layers;

  const Ridge({super.key, required this.seed, this.sky = true, this.layers});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: RidgePainter(seed: seedOf(seed), sky: sky, layers: layers ?? _defaultLayers),
      child: const SizedBox.expand(),
    );
  }
}
