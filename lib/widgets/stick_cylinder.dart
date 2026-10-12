import 'dart:math' as math;

import 'package:flutter/material.dart';

const _tube = Color(0xFFB23A3A);
const _tubeDark = Color(0xFF8E2C2C);
const _gold = Color(0xFFC9A24B);
const _stick = Color(0xFFE6D3A3);

/// 籤筒（畫出嚟，唔用圖片／字體 glyph）。[angle] 係搖動角度（弧度），
/// [pop] 係 0–1 一支籤彈起嘅程度；[spin] 係 0–1（可以超過，取小數部分）
/// 筒身直條紋嘅水平移位，模擬轉動。
class StickCylinder extends StatelessWidget {
  final double angle;
  final double pop;
  final double spin;
  final double width;
  final double height;

  const StickCylinder({
    super.key,
    this.angle = 0,
    this.pop = 0,
    this.spin = 0,
    this.width = 120,
    this.height = 160,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '籤筒',
      child: Transform.rotate(
        angle: angle,
        alignment: Alignment.bottomCenter,
        child: CustomPaint(
          size: Size(width, height),
          painter: _CylinderPainter(pop, spin),
        ),
      ),
    );
  }
}

class _CylinderPainter extends CustomPainter {
  final double pop;
  final double spin;

  _CylinderPainter(this.pop, this.spin);

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final bodyTop = h * 0.40;
    final body = RRect.fromLTRBR(w * 0.18, bodyTop, w * 0.82, h, const Radius.circular(10));

    // 底部陰影。
    canvas.drawOval(
      Rect.fromCenter(center: Offset(w / 2, h - 2), width: w * 0.9, height: 10),
      Paint()
        ..color = const Color(0x66000000)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
    );

    // 籤條（喺筒後面，由筒口伸出）。
    final stickPaint = Paint()..color = _stick;
    final capPaint = Paint()..color = _tube;
    const angles = [-0.30, -0.18, -0.07, 0.04, 0.15, 0.27, 0.0];
    const lifts = [0.0, 0.05, 0.02, 0.07, 0.03, 0.0, 0.10];
    for (var i = 0; i < angles.length; i++) {
      final isPopped = i == angles.length - 1;
      final extra = isPopped ? pop * h * 0.30 : 0.0;
      canvas.save();
      canvas.translate(w * (0.30 + 0.07 * i), bodyTop + 4);
      canvas.rotate(angles[i]);
      final length = h * (0.28 + lifts[i]) + extra;
      final rect = RRect.fromLTRBR(-3, -length, 3, 8, const Radius.circular(3));
      canvas.drawRRect(rect, stickPaint);
      canvas.drawRRect(RRect.fromLTRBR(-3, -length, 3, -length + 7, const Radius.circular(3)), capPaint);
      canvas.restore();
    }

    // 筒身：圓柱光影，左暗、中亮、右暗，做出立體感。
    canvas.drawRRect(
      body,
      Paint()
        ..shader = const LinearGradient(
          colors: [Color(0xFF6A1E1E), _tube, Color(0xFFD46060), _tube, Color(0xFF5E1A1A)],
          stops: [0, 0.3, 0.45, 0.65, 1],
        ).createShader(body.outerRect),
    );
    // 直條紋隨 spin 移動（似轉緊）；cos 投影令兩邊條紋較密。
    final stripe = Paint()
      ..color = const Color(0x22000000)
      ..strokeWidth = 1.2;
    for (var k = 0; k < 6; k++) {
      final u = (k / 6 + spin) % 1.0;
      final x = w * 0.18 + (w * 0.64) * (0.5 - 0.5 * math.cos(u * math.pi));
      canvas.drawLine(Offset(x, bodyTop + 6), Offset(x, h - 6), stripe);
    }
    final band = Paint()
      ..color = _gold
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.2;
    // 金箍跟筒口一樣係橢圓下半弧，睇落係圍住圓柱。
    for (final y in [bodyTop + h * 0.10, h - h * 0.10]) {
      canvas.drawArc(Rect.fromLTWH(w * 0.18, y - 6, w * 0.64, 12), 0, math.pi, false, band);
    }

    // 筒身中間嘅金色印章（外框＋內菱形）。
    final c = Offset(w / 2, bodyTop + (h - bodyTop) / 2);
    final r = (h - bodyTop) * 0.22;
    canvas.drawCircle(c, r, Paint()..color = _gold.withValues(alpha: 0.18));
    canvas.drawCircle(c, r, band..strokeWidth = 1.6);
    final diamond = Path()
      ..moveTo(c.dx, c.dy - r * 0.55)
      ..lineTo(c.dx + r * 0.55, c.dy)
      ..lineTo(c.dx, c.dy + r * 0.55)
      ..lineTo(c.dx - r * 0.55, c.dy)
      ..close();
    canvas.drawPath(diamond, Paint()..color = _gold);

    // 筒口橢圓：徑向漸變，內黑外紅、金邊。
    // RadialGradient 半徑跟短邊，所以用圓形漸變再垂直壓扁成橢圓。
    final mouth = Rect.fromLTWH(w * 0.18, bodyTop - 6, w * 0.64, 12);
    final rx = mouth.width / 2;
    canvas.save();
    canvas.translate(mouth.center.dx, mouth.center.dy);
    canvas.scale(1, mouth.height / mouth.width);
    canvas.drawCircle(
      Offset.zero,
      rx,
      Paint()
        ..shader = const RadialGradient(
          colors: [Color(0xFF2B1010), _tubeDark, _gold],
          stops: [0.5, 0.85, 1],
        ).createShader(Rect.fromCircle(center: Offset.zero, radius: rx)),
    );
    canvas.restore();
    // pop 時筒口微微發亮。
    if (pop > 0) {
      canvas.drawOval(
        mouth,
        Paint()..color = _gold.withValues(alpha: 0.5 * math.min(1.0, pop)),
      );
    }
  }

  @override
  bool shouldRepaint(_CylinderPainter old) => old.pop != pop || old.spin != spin;
}
