import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../engine/daily_stick.dart';
import '../../theme/xuanli_theme.dart';
import '../../widgets/stick_cylinder.dart';
import '../../widgets/stick_share_card.dart';
import '../../widgets/vertical_verse.dart';
import '../combo/share_preview_screen.dart';

/// Tab A 嘅「今日一籤」：未抽 → 籤筒＋「搖籤」；撳咗 → 籤筒搖動、一支籤彈起（約 1.4 秒）
/// → 顯示籤詩。[alreadyDrawn] 為 true（今日抽過）就直接顯示支籤。
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

  @override
  void initState() {
    super.initState();
    _c.addStatusListener((status) {
      if (status == AnimationStatus.completed) _finish();
    });
  }

  @override
  void didUpdateWidget(DailyStickCard old) {
    super.didUpdateWidget(old);
    // 儲存嘅「今日已抽」係非同步載入，載完先到（呢個時候未開始搖就直接顯示）。
    if (widget.alreadyDrawn && !_revealed && !_c.isAnimating) {
      setState(() => _revealed = true);
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  void _draw() {
    if (_revealed || _c.isAnimating) return;
    if (MediaQuery.of(context).disableAnimations) {
      _finish();
      return;
    }
    HapticFeedback.lightImpact();
    _c.forward();
  }

  void _finish() {
    if (!mounted || _revealed) return;
    HapticFeedback.mediumImpact();
    setState(() => _revealed = true);
    widget.onDrawn();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.xuanliColors;
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.cardSurface,
        border: Border.all(color: colors.gold.withValues(alpha: 0.5)),
        borderRadius: BorderRadius.circular(XuanLiRadii.card),
      ),
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 450),
        switchInCurve: Curves.easeOut,
        transitionBuilder: (child, anim) => FadeTransition(
          opacity: anim,
          child: ScaleTransition(scale: Tween(begin: 0.96, end: 1.0).animate(anim), child: child),
        ),
        child: _revealed ? _result(colors) : _idle(colors),
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
          '靜心諗住一件事，撳一下搖籤',
          style: TextStyle(fontSize: 12, color: colors.ink60),
        ),
        const SizedBox(height: 10),
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
              return StickCylinder(angle: angle, pop: pop);
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

  Widget _result(XuanLiColors colors) {
    final stick = widget.stick;
    return Column(
      key: const ValueKey('result'),
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
