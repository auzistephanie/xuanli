import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart' show defaultTargetPlatform;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:sensors_plus/sensors_plus.dart';

import '../../engine/daily_stick.dart';
import '../../services/shake_detector.dart';
import '../../theme/motion.dart';
import '../../theme/xuanli_theme.dart';
import '../../widgets/brand.dart';
import '../../widgets/flip_reveal.dart';
import '../../widgets/stick_cylinder.dart';
import '../../widgets/stick_share_card.dart';
import '../../widgets/vertical_verse.dart';
import '../combo/share_preview_screen.dart';

/// Tab A 嘅「今日一籤」：未抽 → 籤筒＋「搖籤」；撳咗 → 籤筒搖動、一支籤彈起（約 1.4 秒）
/// → 3D 翻卡顯示籤詩。手機上（環境動畫開住）搖一搖手機都得。
/// [alreadyDrawn] 為 true（今日抽過）就直接顯示支籤，唔翻卡。
/// 籤 deterministic（見 `daily_stick.dart`），所以重抽都係同一支。
class DailyStickCard extends StatefulWidget {
  final DailyStick stick;
  final DateTime date;
  final bool alreadyDrawn;

  /// 搖完、支籤出現嗰刻 call（用嚟記低「今日已抽」）。
  final VoidCallback onDrawn;

  const DailyStickCard({
    super.key,
    required this.stick,
    required this.date,
    required this.alreadyDrawn,
    required this.onDrawn,
  });

  @override
  State<DailyStickCard> createState() => _DailyStickCardState();
}

class _DailyStickCardState extends State<DailyStickCard> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  );
  late bool _revealed = widget.alreadyDrawn;

  /// 今次係搖出嚟（唔係重開 app 已抽）先翻卡。
  bool _flipOnReveal = false;

  StreamSubscription<UserAccelerometerEvent>? _shakeSub;
  bool? _sensorsOn;
  final _shake = ShakeDetector();
  final _clock = Stopwatch()..start();

  @override
  void initState() {
    super.initState();
    _c.addStatusListener((status) {
      if (status == AnimationStatus.completed) _finish();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // 同 TiltCard 一樣：TickerMode 關（路由畀人蓋住）就停聽；只喺值變咗先重新訂閱。
    final on = !_revealed && _canShake(context) && TickerMode.valuesOf(context).enabled;
    if (on == _sensorsOn) return;
    _sensorsOn = on;
    _shakeSub?.cancel();
    _shakeSub = null;
    if (on) {
      // 用「去咗重力」嘅加速度，ShakeDetector 要嘅係淨係搖動嘅力度。
      _shakeSub = userAccelerometerEventStream(samplingPeriod: SensorInterval.gameInterval).listen(
        (e) {
          final m = math.sqrt(e.x * e.x + e.y * e.y + e.z * e.z);
          if (_shake.add(magnitude: m, at: _clock.elapsed)) _draw();
        },
        onError: (_) {},
        cancelOnError: true,
      );
    }
  }

  /// 只限 Android／iOS（其他平台冇 sensors_plus 實作）＋環境動畫開住。
  static bool _canShake(BuildContext context) =>
      Motion.sensors(context) &&
      (defaultTargetPlatform == TargetPlatform.android || defaultTargetPlatform == TargetPlatform.iOS);

  void _stopShake() {
    _shakeSub?.cancel();
    _shakeSub = null;
    _sensorsOn = false;
  }

  @override
  void didUpdateWidget(DailyStickCard old) {
    super.didUpdateWidget(old);
    // 儲存嘅「今日已抽」係非同步載入，載完先到（呢個時候未開始搖就直接顯示）。
    if (widget.alreadyDrawn && !_revealed && !_c.isAnimating) {
      _stopShake();
      setState(() => _revealed = true);
    }
  }

  @override
  void dispose() {
    _shakeSub?.cancel();
    _c.dispose();
    super.dispose();
  }

  void _draw() {
    if (_revealed || _c.isAnimating) return;
    if (MediaQuery.disableAnimationsOf(context)) {
      _finish();
      return;
    }
    HapticFeedback.lightImpact();
    _c.forward();
  }

  void _finish() {
    if (!mounted || _revealed) return;
    HapticFeedback.mediumImpact();
    _stopShake();
    setState(() {
      _revealed = true;
      _flipOnReveal = true;
    });
    widget.onDrawn();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.xuanliColors;
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    final switcher = AnimatedSwitcher(
      duration: reduceMotion ? Duration.zero : const Duration(milliseconds: 450),
      switchInCurve: Curves.easeOut,
      // 翻卡路徑：舊嘅籤筒即刻收起，唔好同翻緊嘅卡疊埋一齊。
      layoutBuilder: (current, previous) => _flipOnReveal
          ? (current ?? const SizedBox.shrink())
          : AnimatedSwitcher.defaultLayoutBuilder(current, previous),
      // 翻卡路徑唔好再淡入：FlipReveal 自己做過場，疊埋 450ms 淡入會令卡背睇落暗咗。
      transitionBuilder: (child, anim) => _flipOnReveal
          ? child
          : FadeTransition(
              opacity: anim,
              child: ScaleTransition(scale: Tween(begin: 0.96, end: 1.0).animate(anim), child: child),
            ),
      child: _revealed
          ? (_flipOnReveal ? _flipResult(colors) : _result(colors))
          : _idle(colors),
    );
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.cardSurface,
        border: Border.all(color: colors.gold.withValues(alpha: 0.5)),
        borderRadius: BorderRadius.circular(XuanLiRadii.card),
      ),
      child: reduceMotion
          // AnimatedSize 用 Duration.zero 會喺 layout 入面即刻完成而 assert，所以減少動態就唔包。
          ? switcher
          // 高度變化（籤筒 → 籤詩）用 AnimatedSize 慢慢撐開，唔會一下跳。
          : AnimatedSize(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOutCubic,
              alignment: Alignment.topCenter,
              child: switcher,
            ),
    );
  }

  Widget _idle(XuanLiColors colors) {
    return Column(
      key: const ValueKey('idle'),
      children: [
        Text(
          '今日一籤',
          style: TextStyle(
            fontFamily: XuanLiFonts.serif,
            fontSize: 17,
            fontWeight: FontWeight.w700,
            letterSpacing: 4,
            color: colors.ink,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          _canShake(context) ? '靜心諗住一件事，搖一搖手機或者撳一下' : '靜心諗住一件事，撳一下搖籤',
          style: TextStyle(fontSize: 12, color: colors.ink60),
        ),
        // 唔使再加間距：籤筒上面本身有 popHeadroom（彈起嘅籤用）。
        GestureDetector(
          onTap: _draw,
          behavior: HitTestBehavior.opaque,
          child: AnimatedBuilder(
            animation: _c,
            builder: (context, _) {
              final t = _c.value;
              // 搖動：衰減嘅正弦；0.65 之後一支籤彈起。
              final angle = math.sin(t * math.pi * 10) * 0.20 * (1 - t * 0.45);
              final pop = t < 0.65 ? 0.0 : ((t - 0.65) / 0.35).clamp(0.0, 1.0);
              return StickCylinder(angle: angle, pop: pop, spin: t * 2);
            },
          ),
        ),
        const SizedBox(height: 10),
        FilledButton(
          onPressed: _draw,
          style: FilledButton.styleFrom(
            backgroundColor: colors.gold,
            foregroundColor: colors.ink,
            padding: const EdgeInsets.symmetric(horizontal: 34, vertical: 12),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(XuanLiRadii.card)),
            textStyle: const TextStyle(
              fontFamily: XuanLiFonts.sans,
              fontSize: 15,
              fontWeight: FontWeight.w700,
              letterSpacing: 4,
            ),
          ),
          child: const Text('搖籤'),
        ),
      ],
    );
  }

  Widget _flipResult(XuanLiColors colors) {
    return FlipReveal(
      key: const ValueKey('result'),
      back: Container(
        alignment: Alignment.center,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: colors.gold, width: 1.5),
          gradient: const LinearGradient(colors: [Color(0xFF7A2222), Color(0xFF8F2B2B)]),
        ),
        child: const BrandSeal(size: 44),
      ),
      front: _result(colors),
    );
  }

  Widget _result(XuanLiColors colors) {
    final stick = widget.stick;
    return Column(
      key: const ValueKey('result-front'),
      children: [
        Text(
          '今日一籤',
          style: TextStyle(fontSize: 11, letterSpacing: 4, color: colors.gold, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 6),
        Text(
          stick.levelName,
          style: TextStyle(
            fontFamily: XuanLiFonts.serif,
            fontSize: 30,
            fontWeight: FontWeight.w900,
            letterSpacing: 6,
            color: colors.ink,
          ),
        ),
        Text(
          stick.numberLabel,
          style: TextStyle(fontFamily: XuanLiFonts.serif, fontSize: 13, letterSpacing: 3, color: colors.gold),
        ),
        const SizedBox(height: 14),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
          decoration: BoxDecoration(
            color: colors.paper2.withValues(alpha: 0.55),
            borderRadius: BorderRadius.circular(8),
          ),
          child: VerticalVerse(verse: stick.verse, color: colors.ink, fontSize: 19, columnGap: 13),
        ),
        const SizedBox(height: 12),
        Text(
          stick.interpretation,
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 12.5, height: 1.7, color: colors.ink60),
        ),
        const SizedBox(height: 8),
        TextButton.icon(
          onPressed: () => Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => SharePreviewScreen(
                title: '分享今日籤',
                filename: '今日籤-${stick.levelName}',
                card: StickShareCard(stick: stick, date: widget.date),
              ),
            ),
          ),
          icon: Icon(Icons.ios_share, size: 16, color: colors.gold),
          label: Text('分享呢支籤', style: TextStyle(fontFamily: XuanLiFonts.sans, color: colors.gold)),
        ),
      ],
    );
  }
}
