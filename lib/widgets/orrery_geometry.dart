import 'dart:math' as math;
import 'dart:ui';

/// 投影後嘅點：畫面位置＋depth（> 0 = 向住鏡頭，即「前面」）。
class ProjectedPoint {
  final Offset offset;
  final double depth;
  const ProjectedPoint(this.offset, this.depth);
}

/// 一個環嘅姿勢：環原本喺畫面平面（XY），先沿自己圓周轉 [spin]，
/// 再繞 X 軸傾 [tiltX]，最後繞 Y 軸轉 [tiltY]（全部弧度）。
class RingPose {
  final double tiltX, tiltY, spin;
  const RingPose({this.tiltX = 0, this.tiltY = 0, this.spin = 0});
}

ProjectedPoint projectRingPoint({
  required double radius,
  required double angle,
  required RingPose pose,
  required Offset center,
  double perspective = 900,
}) {
  final a = angle + pose.spin;
  var x = radius * math.cos(a);
  var y = radius * math.sin(a);
  var z = 0.0;

  final cx = math.cos(pose.tiltX), sx = math.sin(pose.tiltX);
  final y1 = y * cx - z * sx;
  final z1 = y * sx + z * cx;
  y = y1;
  z = z1;

  final cy = math.cos(pose.tiltY), sy = math.sin(pose.tiltY);
  final x2 = x * cy + z * sy;
  final z2 = -x * sy + z * cy;
  x = x2;
  z = z2;

  final s = perspective / (perspective - z);
  return ProjectedPoint(center + Offset(x * s, y * s), z);
}

List<ProjectedPoint> projectRing({
  required double radius,
  required RingPose pose,
  required Offset center,
  int segments = 96,
  double perspective = 900,
}) =>
    [
      for (var i = 0; i <= segments; i++)
        projectRingPoint(
          radius: radius,
          angle: 2 * math.pi * i / segments,
          pose: pose,
          center: center,
          perspective: perspective,
        ),
    ];
