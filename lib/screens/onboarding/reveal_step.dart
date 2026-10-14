import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../engine/rarity.dart';
import '../../models/combo.dart';
import '../../models/profile.dart';
import '../../theme/xuanli_theme.dart';

const revealBackground = Color(0xFF131829);
const _navy = Color(0xFF1C2440);
const _paper = Color(0xFFF6EFE2);
const _gold = Color(0xFFC9A24B);
const _sealRed = Color(0xFFB23A3A);

/// Onboarding MBTI 之後、檔案卡之前嘅「揭曉一刻」：暗場 → 朱紅印章蓋落
/// （輕震）→ 四字組合名逐字浮現 → motto → 稀有度 → 掣。撳任何位置跳到尾；
/// 系統開咗「減少動態效果」就直接顯示最後畫面。
class RevealStep extends StatefulWidget {
  final Profile profile;
  final VoidCallback onContinue;
  final VoidCallback onShare;

  /// 唔儲存，幫另一個人再試（重新由出生資料開始）。null = 唔顯示呢個掣。
  final VoidCallback? onTryAnother;

  const RevealStep({
    super.key,
    required this.profile,
    required this.onContinue,
    required this.onShare,
    this.onTryAnother,
  });

  @override
  State<RevealStep> createState() => _RevealStepState();
}

class _RevealStepState extends State<RevealStep>
    with SingleTickerProviderStateMixin {
  static const _total = Duration(milliseconds: 3400);

  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: _total,
  );
  bool _stamped = false;
  bool _started = false;

  @override
  void initState() {
    super.initState();
    _c.addListener(_maybeStampHaptic);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    if (MediaQuery.of(context).disableAnimations) {
      _stamped = true;
      _c.value = 1;
    } else {
      _c.forward();
    }
  }

  void _maybeStampHaptic() {
    // 印章落地嗰下（seal interval 尾）震一震。
    if (!_stamped && _c.value >= 0.30) {
      _stamped = true;
      HapticFeedback.mediumImpact();
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  void _skip() {
    if (_c.isAnimating) {
      _stamped = true;
      _c.value = 1;
    }
  }

  // [begin, end] 係成條 timeline 嘅比例（0–1）。
  Animation<double> _iv(double begin, double end, [Curve curve = Curves.easeOut]) =>
      CurvedAnimation(parent: _c, curve: Interval(begin, end, curve: curve));

  @override
  Widget build(BuildContext context) {
    final profile = widget.profile;
    final dayGan = profile.pillars[2].substring(0, 1);
    final combo = getCombo(dayGan: dayGan, mbti: profile.mbti);
    final rarity = comboRarity(dayGan: dayGan, mbti: profile.mbti);
    final chars = combo.palaceTitle.characters.toList();

    final intro = _iv(0.0, 0.12);
    final seal = _iv(0.10, 0.30, Curves.easeOutBack);
    final seen = _iv(0.74, 0.86);
    final rarityIn = _iv(0.80, 0.90);
    final buttons = _iv(0.88, 1.0);

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _skip,
      child: ColoredBox(
        color: revealBackground,
        child: SafeArea(
          child: AnimatedBuilder(
            animation: _c,
            builder: (context, _) {
              return Padding(
                padding: const EdgeInsets.fromLTRB(28, 24, 28, 24),
                child: Column(
                  children: [
                    const Spacer(flex: 2),
                    _fadeUp(
                      intro,
                      Text(
                        '你的宮職是',
                        style: TextStyle(
                          fontSize: 14,
                          letterSpacing: 3,
                          color: _paper.withValues(alpha: 0.7),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    _seal(seal.value),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        for (var i = 0; i < chars.length; i++)
                          _char(
                            chars[i],
                            _iv(0.40 + i * 0.07, 0.52 + i * 0.07),
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    _fadeUp(
                      seen,
                      Column(
                        children: [
                          Text(
                            '${profile.dayMaster}命 · ${profile.mbti}',
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 14,
                              letterSpacing: 1.2,
                              color: _gold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            combo.thisIsYou,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 13.5,
                              height: 1.4,
                              color: _paper.withValues(alpha: 0.9),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    _fadeUp(
                      rarityIn,
                      Column(
                        children: [
                          Text(
                            '每 ${rarity.oneIn} 人先有一個',
                            style: const TextStyle(
                              fontFamily: XuanLiFonts.serif,
                              fontSize: 17,
                              fontWeight: FontWeight.w700,
                              color: _paper,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '估算約 ${rarity.percentLabel}',
                            style: TextStyle(
                              fontSize: 11,
                              color: _paper.withValues(alpha: 0.5),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Spacer(flex: 3),
                    _fadeUp(buttons, _buttons(), ignoreWhenHidden: true),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _fadeUp(
    Animation<double> a,
    Widget child, {
    bool ignoreWhenHidden = false,
  }) {
    final v = a.value.clamp(0.0, 1.0);
    final w = Opacity(
      opacity: v,
      child: Transform.translate(offset: Offset(0, (1 - v) * 12), child: child),
    );
    return ignoreWhenHidden ? IgnorePointer(ignoring: v < 1, child: w) : w;
  }

  Widget _seal(double t) {
    // 由大（1.8 倍、透明）壓落 1.0；easeOutBack 令佢落地嗰下有少少回彈。
    final scale = 1.8 - 0.8 * t;
    final opacity = (t * 2).clamp(0.0, 1.0);
    return Opacity(
      opacity: opacity,
      child: Transform.rotate(
        angle: -0.06 * (1 - math.min(t, 1.0)),
        child: Transform.scale(
          scale: scale,
          child: Container(
            width: 64,
            height: 64,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: _sealRed,
              borderRadius: BorderRadius.circular(8),
              boxShadow: [
                BoxShadow(
                  color: _sealRed.withValues(alpha: 0.35 * opacity),
                  blurRadius: 24,
                ),
              ],
            ),
            child: Container(
              margin: const EdgeInsets.all(5),
              decoration: BoxDecoration(
                border: Border.all(color: _paper.withValues(alpha: 0.8)),
                borderRadius: BorderRadius.circular(4),
              ),
              alignment: Alignment.center,
              child: const Text(
                '吉',
                style: TextStyle(
                  fontFamily: XuanLiFonts.serif,
                  fontSize: 30,
                  fontWeight: FontWeight.w900,
                  color: _paper,
                  height: 1.1,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _char(String ch, Animation<double> a) {
    final v = a.value.clamp(0.0, 1.0);
    return Opacity(
      opacity: v,
      child: Transform.translate(
        offset: Offset(0, (1 - v) * 18),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Text(
            ch,
            style: const TextStyle(
              fontFamily: XuanLiFonts.serif,
              fontSize: 40,
              fontWeight: FontWeight.w900,
              color: _paper,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buttons() {
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(XuanLiRadii.card),
    );
    // 宮職名已經係結果。主掣繼續去儲存／命理檔案；分享留喺揭曉頁，但降做外框次掣。
    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          height: 50,
          child: FilledButton(
            onPressed: widget.onContinue,
            style: FilledButton.styleFrom(
              backgroundColor: _gold,
              foregroundColor: _navy,
              shape: shape,
              textStyle: const TextStyle(fontFamily: XuanLiFonts.sans, fontSize: 15, fontWeight: FontWeight.w700),
            ),
            child: const Text('儲存並睇我嘅命理檔案'),
          ),
        ),
        const SizedBox(height: 10),
        SizedBox(
          width: double.infinity,
          height: 50,
          child: OutlinedButton(
            onPressed: widget.onShare,
            style: OutlinedButton.styleFrom(
              foregroundColor: _paper,
              side: BorderSide(color: _paper.withValues(alpha: 0.35)),
              shape: shape,
              textStyle: const TextStyle(fontFamily: XuanLiFonts.sans, fontSize: 15),
            ),
            child: const Text('分享我嘅組合'),
          ),
        ),
        if (widget.onTryAnother != null) ...[
          const SizedBox(height: 4),
          TextButton(
            onPressed: widget.onTryAnother,
            style: TextButton.styleFrom(
              foregroundColor: _gold,
              textStyle: const TextStyle(fontFamily: XuanLiFonts.sans, fontSize: 14),
            ),
            child: const Text('幫朋友再試一個'),
          ),
        ],
        Text(
          '而家仲未儲存任何資料',
          style: TextStyle(fontSize: 11, color: _paper.withValues(alpha: 0.45)),
        ),
      ],
    );
  }
}
