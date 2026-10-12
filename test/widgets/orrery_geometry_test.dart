import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:xuanli/widgets/orrery_geometry.dart';

void main() {
  const c = Offset(100, 100);

  test('冇傾斜：每點距中心 = 半徑，depth 0', () {
    for (final p in projectRing(radius: 50, pose: const RingPose(), center: c)) {
      expect((p.offset - c).distance, closeTo(50, 1e-9));
      expect(p.depth, closeTo(0, 1e-9));
    }
  });

  test('繞 X 傾斜 90°：全部點落喺水平線', () {
    final pose = const RingPose(tiltX: math.pi / 2);
    for (final p in projectRing(radius: 50, pose: pose, center: c)) {
      expect(p.offset.dy, closeTo(c.dy, 1e-9));
    }
  });

  test('depth > 0 嘅點（近鏡頭）投影會放大', () {
    final pose = const RingPose(tiltX: math.pi / 2, tiltY: 0.3);
    final near = projectRingPoint(radius: 50, angle: math.pi / 2, pose: pose, center: c);
    final far = projectRingPoint(radius: 50, angle: -math.pi / 2, pose: pose, center: c);
    expect(near.depth, greaterThan(0));
    expect(far.depth, lessThan(0));
    expect((near.offset - c).distance, greaterThan((far.offset - c).distance));
  });

  test('spin 只係沿環轉，唔改環形狀', () {
    final a = projectRing(radius: 50, pose: const RingPose(tiltX: 1.1), center: c, segments: 360);
    final b = projectRing(radius: 50, pose: const RingPose(tiltX: 1.1, spin: 2 * math.pi / 360), center: c, segments: 360);
    expect(b[0].offset.dx, closeTo(a[1].offset.dx, 1e-9));
    expect(b[0].offset.dy, closeTo(a[1].offset.dy, 1e-9));
  });

  test('segments + 1 個點（頭尾相接）', () {
    expect(projectRing(radius: 10, pose: const RingPose(), center: c, segments: 24).length, 25);
  });
}
