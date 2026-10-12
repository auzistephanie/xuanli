import 'dart:math' as math;

import 'package:flutter/material.dart';

// 細裝飾符號用畫嘅，唔用 ◈ ☾ 呢類字元：bundled subset 字體冇呢啲 glyph，
// 截圖／web／測試會變空白，靠系統字體 fallback 又令各平台樣子唔一致。

/// 外框菱形包住實心細菱形（取代「◈」）。
class DiamondMark extends StatelessWidget {
  final Color color;
  final double size;

  const DiamondMark({super.key, required this.color, this.size = 10});

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: size,
      child: Transform.rotate(
        angle: math.pi / 4,
        child: Container(
          margin: EdgeInsets.all(size * 0.15),
          decoration: BoxDecoration(
            border: Border.all(color: color, width: 1.2),
          ),
          padding: EdgeInsets.all(size * 0.17),
          child: ColoredBox(color: color),
        ),
      ),
    );
  }
}

/// 下弦月（取代「☾」）。
class MoonMark extends StatelessWidget {
  final Color color;
  final double size;

  const MoonMark({super.key, required this.color, this.size = 11});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(size: Size.square(size), painter: _MoonPainter(color));
  }
}

class _MoonPainter extends CustomPainter {
  final Color color;

  _MoonPainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final r = size.shortestSide / 2;
    final center = size.center(Offset.zero);
    final disc = Path()..addOval(Rect.fromCircle(center: center, radius: r));
    final bite = Path()
      ..addOval(
        Rect.fromCircle(
          center: center.translate(r * 0.55, -r * 0.2),
          radius: r * 0.85,
        ),
      );
    canvas.drawPath(
      Path.combine(PathOperation.difference, disc, bite),
      Paint()..color = color,
    );
  }

  @override
  bool shouldRepaint(_MoonPainter oldDelegate) => oldDelegate.color != color;
}

/// 標題前面加個畫出嚟嘅細符號。
class MarkedTitle extends StatelessWidget {
  final Widget mark;
  final String text;
  final TextStyle style;

  const MarkedTitle({
    super.key,
    required this.mark,
    required this.text,
    required this.style,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        mark,
        const SizedBox(width: 6),
        Text(text, style: style),
      ],
    );
  }
}
