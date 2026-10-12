import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:xuanli/widgets/tilt_math.dart';

void main() {
  test('中間 → 冇傾斜', () {
    final a = tiltAngles(Offset.zero);
    expect(a.rotateX, 0);
    expect(a.rotateY, 0);
  });

  test('右邊 → 繞 Y 正轉；上面 → 繞 X 正轉；夾喺最大值', () {
    final a = tiltAngles(const Offset(1, -1));
    expect(a.rotateY, closeTo(kMaxTiltY, 1e-9));
    expect(a.rotateX, closeTo(kMaxTiltX, 1e-9));
    final b = tiltAngles(const Offset(5, 5));
    expect(b.rotateY, closeTo(kMaxTiltY, 1e-9));
    expect(b.rotateX, closeTo(-kMaxTiltX, 1e-9));
  });

  test('pointerToNormalized：框內位置 → -1..1', () {
    const size = Size(200, 100);
    expect(pointerToNormalized(const Offset(100, 50), size), Offset.zero);
    expect(pointerToNormalized(const Offset(200, 0), size), const Offset(1, -1));
  });

  test('gravityToNormalized：平放手機（ax 0, ay ~6.5）≈ 中間', () {
    final n = gravityToNormalized(0, 6.5);
    expect(n.dx, closeTo(0, 1e-9));
    expect(n.dy, closeTo(0, 1e-9));
  });

  test('gravityToNormalized：向左側 ax>0 → dx<0，夾喺 -1..1', () {
    final n = gravityToNormalized(20, 6.5);
    expect(n.dx, -1);
  });
}
