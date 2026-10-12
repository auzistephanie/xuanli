import 'dart:ui';

const kMaxTiltX = 0.19; // ≈ 11°
const kMaxTiltY = 0.23; // ≈ 13°

class TiltAngles {
  final double rotateX, rotateY;
  const TiltAngles(this.rotateX, this.rotateY);
}

/// [n] 係 -1..1 嘅位置（右／下為正）。上面向住你 → rotateX 正。
TiltAngles tiltAngles(Offset n) => TiltAngles(
      -n.dy.clamp(-1.0, 1.0) * kMaxTiltX,
      n.dx.clamp(-1.0, 1.0) * kMaxTiltY,
    );

Offset pointerToNormalized(Offset local, Size size) => Offset(
      (local.dx / size.width * 2 - 1).clamp(-1.0, 1.0),
      (local.dy / size.height * 2 - 1).clamp(-1.0, 1.0),
    );

/// 加速計重力（m/s²）→ -1..1。手機自然拎住（約 40° 斜）時 ay ≈ 6.5 當中間。
Offset gravityToNormalized(double ax, double ay) => Offset(
      (-ax / 4).clamp(-1.0, 1.0),
      ((ay - 6.5) / 4).clamp(-1.0, 1.0),
    );
