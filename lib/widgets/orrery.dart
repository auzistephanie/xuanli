import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/brand.dart';
import '../theme/motion.dart';
import 'orrery_geometry.dart';

/// 天體儀：後層環 → 核心球（可放 [core]）→ 前層環，做出環繞住球嘅遮擋感。
/// 一圈 38 秒；環境動畫關咗就停喺固定角度。
class Orrery extends StatefulWidget {
  final double size;
  final Widget? core;

  /// 核心球直徑佔 [size] 嘅比例。
  final double coreFraction;

  const Orrery({super.key, this.size = 220, this.core, this.coreFraction = 0.46});

  @override
  State<Orrery> createState() => _OrreryState();
}

class _OrreryState extends State<Orrery> with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: const Duration(seconds: 38));

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (Motion.ambient(context)) {
      if (!_c.isAnimating) _c.repeat();
    } else {
      _c.stop();
      _c.value = 0.12;
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.size;
    return SizedBox.square(
      dimension: s,
      child: Stack(
        alignment: Alignment.center,
        children: [
          ExcludeSemantics(
            child: RepaintBoundary(
              child: CustomPaint(size: Size.square(s), painter: _OrreryPainter(_c, front: false)),
            ),
          ),
          OrreryCore(diameter: s * widget.coreFraction, child: widget.core),
          IgnorePointer(
            child: ExcludeSemantics(
              child: RepaintBoundary(
                child: CustomPaint(size: Size.square(s), painter: _OrreryPainter(_c, front: true)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 立體深藍球＋金邊光暈。
class OrreryCore extends StatelessWidget {
  final double diameter;
  final Widget? child;

  const OrreryCore({super.key, required this.diameter, this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: diameter,
      height: diameter,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: const RadialGradient(
          center: Alignment(-0.1, 0.1),
          colors: [Color(0xFF3A4677), KairoPalette.navy, Color(0xFF0E1328)],
          stops: [0, 0.62, 1],
        ),
        border: Border.all(color: KairoPalette.gold.withValues(alpha: 0.6)),
        boxShadow: [
          BoxShadow(color: KairoPalette.gold.withValues(alpha: 0.35), blurRadius: diameter * 0.35),
        ],
      ),
      foregroundDecoration: const BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          center: Alignment(-0.35, -0.45),
          radius: 0.32,
          colors: [Color(0x80FFFFFF), Color(0x00FFFFFF)],
        ),
      ),
      child: child,
    );
  }
}

class _RingSpec {
  final double radius; // 佔半邊 size 比例
  final RingPose Function(double t) pose;
  final Color color;
  final double width;
  final bool dashed;
  const _RingSpec(this.radius, this.pose, this.color, this.width, {this.dashed = false});
}

const _tilt = 1.12; // ≈ 64°

final _rings = <_RingSpec>[
  _RingSpec(0.84, (t) => RingPose(tiltX: _tilt, spin: t * 2 * math.pi), KairoPalette.gold, 1.6),
  _RingSpec(1.0, (t) => RingPose(tiltX: _tilt, spin: -t * 2 * math.pi), KairoPalette.gold.withValues(alpha: 0.45), 1.0, dashed: true),
  _RingSpec(0.78, (t) => RingPose(tiltX: 0.25, tiltY: t * 4 * math.pi), KairoPalette.goldBright.withValues(alpha: 0.7), 1.2),
  _RingSpec(0.72, (t) => RingPose(tiltX: 0.6, tiltY: -t * 3 * math.pi), KairoPalette.jadeBright.withValues(alpha: 0.7), 1.2),
];

class _OrreryPainter extends CustomPainter {
  final Animation<double> t;
  final bool front;

  _OrreryPainter(this.t, {required this.front}) : super(repaint: t);

  bool _mine(double depth) => front ? depth >= 0 : depth < 0;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final half = size.width / 2 * 0.92;
    final v = t.value;

    for (final ring in _rings) {
      final pts = projectRing(radius: half * ring.radius, pose: ring.pose(v), center: c);
      final paint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeWidth = ring.width
        ..color = front ? ring.color : ring.color.withValues(alpha: ring.color.a * 0.4);
      for (var i = 0; i < pts.length - 1; i++) {
        if (ring.dashed && i.isOdd) continue;
        if (!_mine((pts[i].depth + pts[i + 1].depth) / 2)) continue;
        canvas.drawLine(pts[i].offset, pts[i + 1].offset, paint);
      }
    }

    // 主環刻度（24 格）。
    final main = _rings.first;
    final tickPaint = Paint()
      ..color = KairoPalette.gold.withValues(alpha: front ? 0.9 : 0.35)
      ..strokeWidth = 1;
    for (var k = 0; k < 24; k++) {
      final a = 2 * math.pi * k / 24;
      final p1 = projectRingPoint(radius: half * main.radius, angle: a, pose: main.pose(v), center: c);
      if (!_mine(p1.depth)) continue;
      final p2 = projectRingPoint(radius: half * main.radius * 1.06, angle: a, pose: main.pose(v), center: c);
      canvas.drawLine(p1.offset, p2.offset, tickPaint);
    }

    // 兩粒行星。
    _planet(canvas, c, half * _rings[0].radius, _rings[0].pose(v), v * 8 * math.pi, KairoPalette.goldBright, KairoPalette.gold, 7);
    _planet(canvas, c, half * _rings[1].radius, _rings[1].pose(v), -v * 5 * math.pi, const Color(0xFFD9FFF4), KairoPalette.jadeBright, 4.5);
  }

  void _planet(Canvas canvas, Offset c, double r, RingPose pose, double angle, Color hi, Color base, double radius) {
    final p = projectRingPoint(radius: r, angle: angle, pose: pose, center: c);
    if (!_mine(p.depth)) return;
    final rect = Rect.fromCircle(center: p.offset, radius: radius);
    canvas.drawCircle(p.offset, radius * 1.8, Paint()..color = base.withValues(alpha: 0.25));
    canvas.drawCircle(
      p.offset,
      radius,
      Paint()
        ..shader = RadialGradient(center: const Alignment(-0.4, -0.4), colors: [hi, base, Color.lerp(base, Colors.black, 0.6)!], stops: const [0, 0.45, 1])
            .createShader(rect),
    );
  }

  @override
  bool shouldRepaint(_OrreryPainter old) => old.front != front;
}
