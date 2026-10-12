import 'dart:math' as math;

import 'package:flutter/material.dart';

/// 一出現就由 [back] 3D 翻去 [front]（約 0.9 秒，先蓄力後回彈）。
/// 「減少動態效果」→ 直接顯示 [front]。
class FlipReveal extends StatefulWidget {
  final Widget back;
  final Widget front;

  const FlipReveal({super.key, required this.back, required this.front});

  @override
  State<FlipReveal> createState() => _FlipRevealState();
}

class _FlipRevealState extends State<FlipReveal> with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 900));
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    if (MediaQuery.disableAnimationsOf(context)) {
      _c.value = 1;
    } else {
      _c.forward();
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (context, _) {
        // easeInOutBack：開頭背面停留（仲有少少反向蓄力），尾段回彈；
        // easeOutBack 會一開始就轉過 90°，背面根本睇唔到。
        final t = Curves.easeInOutBack.transform(_c.value);
        final angle = (1 - t) * math.pi;
        final showFront = angle < math.pi / 2;
        final s = 0.7 + 0.3 * _c.value;
        return Transform(
          alignment: Alignment.center,
          transform: Matrix4.identity()
            ..setEntry(3, 2, 0.0015)
            ..rotateY(angle)
            ..scaleByDouble(s, s, 1.0, 1.0),
          child: showFront
              ? widget.front
              // 背面預先反轉，翻到一半之前睇落唔會係鏡像。
              : Transform(
                  alignment: Alignment.center,
                  transform: Matrix4.rotationY(math.pi),
                  child: widget.back,
                ),
        );
      },
    );
  }
}
