/// 純 Dart 搖動偵測：餵入「去咗重力」嘅加速度大小（m/s²）同時間。
/// [window] 內有 [hits] 次超過 [threshold] 就算搖一次，之後冷卻 [cooldown]。
class ShakeDetector {
  final double threshold;
  final int hits;
  final Duration window;
  final Duration cooldown;

  final List<Duration> _peaks = [];
  Duration? _lastShake;

  ShakeDetector({
    this.threshold = 12,
    this.hits = 2,
    this.window = const Duration(seconds: 1),
    this.cooldown = const Duration(seconds: 2),
  });

  bool add({required double magnitude, required Duration at}) {
    if (_lastShake != null && at - _lastShake! < cooldown) return false;
    if (magnitude < threshold) return false;
    _peaks.add(at);
    _peaks.removeWhere((t) => at - t > window);
    if (_peaks.length >= hits) {
      _peaks.clear();
      _lastShake = at;
      return true;
    }
    return false;
  }
}
