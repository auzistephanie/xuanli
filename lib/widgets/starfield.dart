import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/motion.dart';

class StarSpec {
  final double x, y, phase, speed, radius;
  const StarSpec(this.x, this.y, this.phase, this.speed, this.radius);
}

/// 固定公式（唔用 Random），每次 render 一樣。
List<StarSpec> starSpecs(int count) => [
      for (var i = 0; i < count; i++)
        StarSpec(
          (i * 37.7 % 100) / 100,
          (i * 61.3 % 100) / 100,
          (i % 7) / 7,
          0.6 + (i % 5) * 0.25,
          i % 9 == 0 ? 1.4 : 0.9,
        ),
    ];

/// 閃爍星空背景。放喺 Stack 最底，填滿父層。
class Starfield extends StatefulWidget {
  final int count;
  final Color color;

  const Starfield({super.key, this.count = 46, this.color = Colors.white});

  @override
  State<Starfield> createState() => _StarfieldState();
}

class _StarfieldState extends State<Starfield> with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: const Duration(seconds: 6));
  late final List<StarSpec> _stars = starSpecs(widget.count);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (Motion.ambient(context)) {
      if (!_c.isAnimating) _c.repeat();
    } else {
      _c.stop();
      _c.value = 0.25;
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: RepaintBoundary(
        child: CustomPaint(
          size: Size.infinite,
          painter: _StarPainter(_stars, _c, widget.color),
        ),
      ),
    );
  }
}

class _StarPainter extends CustomPainter {
  final List<StarSpec> stars;
  final Animation<double> t;
  final Color color;

  _StarPainter(this.stars, this.t, this.color) : super(repaint: t);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint();
    for (final s in stars) {
      final wave = 0.5 + 0.5 * math.sin(2 * math.pi * (t.value * s.speed + s.phase));
      paint.color = color.withValues(alpha: 0.08 + 0.7 * wave);
      canvas.drawCircle(Offset(s.x * size.width, s.y * size.height), s.radius, paint);
    }
  }

  @override
  bool shouldRepaint(_StarPainter old) => old.stars != stars || old.color != color;
}
