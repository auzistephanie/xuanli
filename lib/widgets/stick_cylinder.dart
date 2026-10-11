import 'dart:math' as math;

import 'package:flutter/material.dart';

const _tube = Color(0xFFB23A3A);
const _tubeDark = Color(0xFF8E2C2C);
const _gold = Color(0xFFC9A24B);
const _stick = Color(0xFFE6D3A3);

/// 籤筒（畫出嚟，唔用圖片／字體 glyph）。[angle] 係搖動角度（弧度），
/// [pop] 係 0–1 一支籤彈起嘅程度。
class StickCylinder extends StatelessWidget {
  final double angle;
  final double pop;
  final double width;
  final double height;

  const StickCylinder({
    super.key,
    this.angle = 0,
    this.pop = 0,
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
          painter: _CylinderPainter(pop),
        ),
      ),
    );
  }
}

class _CylinderPainter extends CustomPainter {
  final double pop;

  _CylinderPainter(this.pop);

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final bodyTop = h * 0.40;
    final body = RRect.fromLTRBR(w * 0.18, bodyTop, w * 0.82, h, const Radius.circular(10));

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

    // 筒身。
    canvas.drawRRect(body, Paint()..color = _tube);
    canvas.drawRRect(
      RRect.fromLTRBR(w * 0.18, bodyTop, w * 0.30, h, const Radius.circular(10)),
      Paint()..color = _tubeDark.withValues(alpha: 0.45),
    );
    final band = Paint()
      ..color = _gold
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.2;
    canvas.drawLine(Offset(w * 0.18, bodyTop + h * 0.10), Offset(w * 0.82, bodyTop + h * 0.10), band);
    canvas.drawLine(Offset(w * 0.18, h - h * 0.10), Offset(w * 0.82, h - h * 0.10), band);

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

    // 筒口橢圓（令立體啲）。
    canvas.drawOval(
      Rect.fromLTWH(w * 0.18, bodyTop - 5, w * 0.64, 10),
      Paint()..color = _tubeDark,
    );
    // pop 時筒口微微發亮。
    if (pop > 0) {
      canvas.drawOval(
        Rect.fromLTWH(w * 0.18, bodyTop - 5, w * 0.64, 10),
        Paint()..color = _gold.withValues(alpha: 0.5 * math.min(1.0, pop)),
      );
    }
  }

  @override
  bool shouldRepaint(_CylinderPainter old) => old.pop != pop;
}
