import 'dart:async';

import 'package:flutter/material.dart';
import 'package:sensors_plus/sensors_plus.dart';

import '../theme/brand.dart';
import '../theme/motion.dart';
import 'tilt_math.dart';

/// 跟手指（或手機傾斜）微微轉動嘅卡，加一條會游走嘅全息反光。
/// 環境動畫關咗：唔聽感應器，但手指拖動仍然有效（使用者主動操作）。
///
/// 用 [Listener] 而唔用 pan GestureDetector：唔入手勢競技場，
/// 所以卡放喺 scroll view 入面，垂直拖照樣 scroll 到成頁。
class TiltCard extends StatefulWidget {
  static const transformKey = ValueKey('tilt-card-transform');

  final Widget child;
  final BorderRadius borderRadius;

  const TiltCard({super.key, required this.child, this.borderRadius = const BorderRadius.all(Radius.circular(24))});

  @override
  State<TiltCard> createState() => _TiltCardState();
}

class _TiltCardState extends State<TiltCard> with SingleTickerProviderStateMixin {
  Offset _current = Offset.zero;
  Offset _settleFrom = Offset.zero;
  int? _pointer;
  StreamSubscription<AccelerometerEvent>? _sub;
  late final AnimationController _settle;

  @override
  void initState() {
    super.initState();
    _settle = AnimationController(vsync: this, duration: const Duration(milliseconds: 350))
      ..addListener(() => setState(() {
            _current = Offset.lerp(_settleFrom, Offset.zero, Curves.easeOut.transform(_settle.value))!;
          }));
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _sub?.cancel();
    _sub = null;
    if (Motion.sensors(context)) {
      try {
        _sub = accelerometerEventStream(samplingPeriod: SensorInterval.uiInterval).listen(
          (e) {
            if (_pointer != null || !mounted) return;
            final target = gravityToNormalized(e.x, e.y);
            setState(() => _current = Offset.lerp(_current, target, 0.15)!);
          },
          onError: (_) {},
          cancelOnError: true,
        );
      } catch (_) {
        // 冇感應器（模擬器／桌面）：靠拖動就得。
      }
    }
  }

  @override
  void dispose() {
    _sub?.cancel();
    _settle.dispose();
    super.dispose();
  }

  void _move(PointerEvent e) {
    if (_pointer != null && _pointer != e.pointer) return;
    final size = context.size;
    if (size == null || size.isEmpty) return;
    _pointer = e.pointer;
    _settle.stop();
    setState(() => _current = pointerToNormalized(e.localPosition, size));
  }

  void _release(PointerEvent e) {
    if (_pointer != e.pointer) return;
    _pointer = null;
    _settleFrom = _current;
    _settle.forward(from: 0);
  }

  @override
  Widget build(BuildContext context) {
    final a = tiltAngles(_current);
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: _move,
      onPointerMove: _move,
      onPointerUp: _release,
      onPointerCancel: _release,
      child: Transform(
        key: TiltCard.transformKey,
        alignment: Alignment.center,
        transform: Matrix4.identity()
          ..setEntry(3, 2, 0.0012)
          ..rotateX(a.rotateX)
          ..rotateY(a.rotateY),
        child: ClipRRect(
          borderRadius: widget.borderRadius,
          child: Stack(
            children: [
              widget.child,
              Positioned.fill(
                child: IgnorePointer(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment(-1.6 + _current.dx, -1),
                        end: Alignment(1.6 + _current.dx, 1),
                        colors: [
                          Colors.transparent,
                          KairoPalette.goldBright.withValues(alpha: 0.16),
                          KairoPalette.jadeBright.withValues(alpha: 0.12),
                          const Color(0x1FE57A6F),
                          Colors.transparent,
                        ],
                        stops: const [0.35, 0.45, 0.5, 0.55, 0.65],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
