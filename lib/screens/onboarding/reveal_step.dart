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

  const RevealStep({
    super.key,
    required this.profile,
    required this.onContinue,
    required this.onShare,
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
    final chars = combo.name.characters.toList();

    final intro = _iv(0.0, 0.12);
    final seal = _iv(0.10, 0.30, Curves.easeOutBack);
    final chips = _iv(0.30, 0.40);
    final motto = _iv(0.72, 0.82);
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
                        '你嘅八字 × MBTI 組合係……',
                        style: TextStyle(
                          fontSize: 14,
                          letterSpacing: 3,
                          color: _paper.withValues(alpha: 0.7),
                        ),
                      ),
                    ),
                    const SizedBox(height: 36),
                    _seal(seal.value),
                    const SizedBox(height: 26),
                    _fadeUp(chips, _chips(profile)),
                    const SizedBox(height: 26),
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
                    const SizedBox(height: 14),
                    _fadeUp(
                      motto,
                      Text(
                        combo.motto,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 15,
                          letterSpacing: 3,
                          color: _gold,
                        ),
                      ),
                    ),
                    const SizedBox(height: 22),
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
                '玄',
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

  Widget _chips(Profile profile) {
    Widget chip(String text, {required bool filled}) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
      decoration: BoxDecoration(
        color: filled ? _gold : Colors.transparent,
        border: filled ? null : Border.all(color: _gold),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w700,
          color: filled ? _navy : _paper,
        ),
      ),
    );
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        chip('${profile.dayMaster}日主', filled: false),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 10),
          child: Text('×', style: TextStyle(fontSize: 16, color: _gold)),
        ),
        chip(profile.mbti, filled: true),
      ],
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
              fontSize: 48,
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
    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          height: 50,
          child: FilledButton(
            onPressed: widget.onShare,
            style: FilledButton.styleFrom(
              backgroundColor: _gold,
              foregroundColor: _navy,
              shape: shape,
              textStyle: const TextStyle(fontFamily: XuanLiFonts.sans, fontSize: 15, fontWeight: FontWeight.w700),
            ),
            child: const Text('分享我嘅組合'),
          ),
        ),
        const SizedBox(height: 10),
        SizedBox(
          width: double.infinity,
          height: 50,
          child: OutlinedButton(
            onPressed: widget.onContinue,
            style: OutlinedButton.styleFrom(
              foregroundColor: _paper,
              side: BorderSide(color: _paper.withValues(alpha: 0.35)),
              shape: shape,
              textStyle: const TextStyle(fontFamily: XuanLiFonts.sans, fontSize: 15),
            ),
            child: const Text('睇我嘅命理檔案'),
          ),
        ),
      ],
    );
  }
}
