import 'package:flutter/material.dart';

import '../../theme/xuanli_theme.dart';
import '../../widgets/marks.dart';
import 'reveal_step.dart' show revealBackground;

const _navy = Color(0xFF1C2440);
const _paper = Color(0xFFF6EFE2);
const _gold = Color(0xFFC9A24B);
const _sealRed = Color(0xFFB23A3A);

/// Onboarding 第 0 步：封面。畀未用過嘅人（包括掃分享卡 QR 入嚟嗰班）
/// 十秒內明白玄曆係咩、點解值得填資料，然後撳「睇我嘅組合」開始。
/// 風格同 [RevealStep] 一致（藏藍＋朱紅印＋金），令「封面 → … → 揭曉」似一個故事。
class WelcomeStep extends StatefulWidget {
  final VoidCallback onStart;

  const WelcomeStep({super.key, required this.onStart});

  @override
  State<WelcomeStep> createState() => _WelcomeStepState();
}

class _WelcomeStepState extends State<WelcomeStep>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  );
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    if (MediaQuery.of(context).disableAnimations) {
      _c.value = 1;
    } else {
      _c.forward();
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  Animation<double> _iv(double begin, double end) => CurvedAnimation(
    parent: _c,
    curve: Interval(begin, end, curve: Curves.easeOut),
  );

  Widget _fadeUp(Animation<double> a, Widget child) => AnimatedBuilder(
    animation: a,
    child: child,
    builder: (_, child) => Opacity(
      opacity: a.value,
      child: Transform.translate(
        offset: Offset(0, (1 - a.value) * 14),
        child: child,
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: revealBackground,
      child: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) => SingleChildScrollView(
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(30, 28, 30, 24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _fadeUp(_iv(0.0, 0.35), _brand()),
                    const SizedBox(height: 34),
                    _fadeUp(_iv(0.15, 0.5), _headline()),
                    const SizedBox(height: 30),
                    _fadeUp(_iv(0.35, 0.7), _points()),
                    const SizedBox(height: 34),
                    _fadeUp(_iv(0.6, 1.0), _cta()),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _brand() {
    return Column(
      children: [
        Container(
          width: 64,
          height: 64,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: _sealRed,
            borderRadius: BorderRadius.circular(8),
            boxShadow: [
              BoxShadow(color: _sealRed.withValues(alpha: 0.35), blurRadius: 24),
            ],
          ),
          child: Container(
            margin: const EdgeInsets.all(5),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              border: Border.all(color: _paper.withValues(alpha: 0.8)),
              borderRadius: BorderRadius.circular(4),
            ),
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
        const SizedBox(height: 14),
        const Text(
          '玄曆',
          style: TextStyle(
            fontFamily: XuanLiFonts.serif,
            fontSize: 26,
            fontWeight: FontWeight.w700,
            letterSpacing: 8,
            color: _paper,
          ),
        ),
      ],
    );
  }

  Widget _headline() {
    return Column(
      children: [
        const Text(
          '160 個組合，\n邊個係你？',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontFamily: XuanLiFonts.serif,
            fontSize: 34,
            height: 1.35,
            fontWeight: FontWeight.w900,
            letterSpacing: 3,
            color: _paper,
          ),
        ),
        const SizedBox(height: 14),
        Text(
          '八字日主 × MBTI，砌出只屬於你嘅四字組合',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 13,
            letterSpacing: 1.5,
            height: 1.6,
            color: _gold.withValues(alpha: 0.95),
          ),
        ),
      ],
    );
  }

  Widget _points() {
    const items = [
      '睇下你係「林間清泉」定「雪嶺孤松」',
      '之後每日宜忌、揀日子，都跟你嘅喜忌神',
      '免註冊・全離線・出生資料唔離你部機',
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final item in items)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.only(top: 4, right: 12),
                  child: DiamondMark(color: _gold, size: 10),
                ),
                Expanded(
                  child: Text(
                    item,
                    style: TextStyle(
                      fontSize: 14,
                      height: 1.55,
                      color: _paper.withValues(alpha: 0.9),
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _cta() {
    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          height: 52,
          child: FilledButton(
            onPressed: widget.onStart,
            style: FilledButton.styleFrom(
              backgroundColor: _gold,
              foregroundColor: _navy,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(XuanLiRadii.card),
              ),
              textStyle: const TextStyle(
                fontFamily: XuanLiFonts.sans,
                fontSize: 16,
                fontWeight: FontWeight.w700,
                letterSpacing: 2,
              ),
            ),
            child: const Text('睇我嘅組合'),
          ),
        ),
        const SizedBox(height: 10),
        Text(
          '約 1 分鐘・僅供參考，不代替專業意見',
          style: TextStyle(fontSize: 11, color: _paper.withValues(alpha: 0.45)),
        ),
      ],
    );
  }
}
