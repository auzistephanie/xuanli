import 'package:flutter/material.dart';

import '../engine/rarity.dart';
import '../models/combo.dart';
import '../models/profile.dart';
import '../theme/xuanli_theme.dart';
import 'share_parts.dart';

export 'share_parts.dart' show xuanliWebUrl, shareCardSize;

const _navy = shareNavy;
const _paper = sharePaper;
const _gold = shareGold;

const _wuxingOrder = ['木', '火', '土', '金', '水'];
const _wuxingColors = {
  '木': Color(0xFF6CAE84),
  '火': Color(0xFFC96A6A),
  '土': Color(0xFFC9A24B),
  '金': Color(0xFF9AA3B8),
  '水': Color(0xFF5F87AD),
};

/// 八字×MBTI 組合分享卡。只放組合內容同五行比例，**唔放姓名、出生日期
/// 或時辰**——用家分享出去嘅係組合，唔係個人資料（鐵律 1 精神）。
class ShareCard extends StatelessWidget {
  final Profile profile;
  final Combo combo;

  const ShareCard({super.key, required this.profile, required this.combo});

  @override
  Widget build(BuildContext context) {
    return ShareCardBackground(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const ShareBrand(),
          const SizedBox(height: 24),
          _chips(),
          const SizedBox(height: 16),
          Text(
            combo.name,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontFamily: XuanLiFonts.serif,
              fontSize: 46,
              fontWeight: FontWeight.w900,
              letterSpacing: 8,
              color: _paper,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            combo.motto,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontFamily: XuanLiFonts.sans,
              fontSize: 14,
              letterSpacing: 3,
              color: _gold,
            ),
          ),
          const SizedBox(height: 16),
          _rarity(),
          const SizedBox(height: 16),
          _divider(),
          const SizedBox(height: 14),
          _wuxingBars(),
          const SizedBox(height: 14),
          _strengths(),
          const Spacer(),
          const SizedBox(height: 10),
          const ShareFooter(),
        ],
      ),
    );
  }

  Widget _chips() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _chip(
          '${profile.dayMaster}日主',
          Colors.transparent,
          _paper,
          border: _gold,
        ),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 10),
          child: Text(
            '×',
            style: TextStyle(
              fontFamily: XuanLiFonts.serif,
              fontSize: 16,
              color: _gold,
            ),
          ),
        ),
        _chip(profile.mbti, _gold, _navy),
      ],
    );
  }

  Widget _chip(String text, Color fill, Color textColor, {Color? border}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
      decoration: BoxDecoration(
        color: fill,
        borderRadius: BorderRadius.circular(20),
        border: border == null ? null : Border.all(color: border, width: 1),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontFamily: XuanLiFonts.sans,
          fontSize: 13,
          fontWeight: FontWeight.w700,
          color: textColor,
        ),
      ),
    );
  }

  Widget _rarity() {
    final rarity = comboRarity(
      dayGan: profile.pillars[2].substring(0, 1),
      mbti: profile.mbti,
    );
    return Text(
      '估算約 ${rarity.percentLabel}・每 ${rarity.oneIn} 人先有一個',
      textAlign: TextAlign.center,
      style: TextStyle(
        fontSize: 12,
        letterSpacing: 1,
        color: _paper.withValues(alpha: 0.75),
      ),
    );
  }

  Widget _divider() {
    return Row(
      children: [
        Expanded(
          child: Container(height: 1, color: _gold.withValues(alpha: 0.35)),
        ),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 10),
          child: Text(
            '五行',
            style: TextStyle(fontSize: 11, letterSpacing: 3, color: _gold),
          ),
        ),
        Expanded(
          child: Container(height: 1, color: _gold.withValues(alpha: 0.35)),
        ),
      ],
    );
  }

  Widget _wuxingBars() {
    return Column(
      children: [
        for (final element in _wuxingOrder)
          Padding(
            padding: const EdgeInsets.only(bottom: 5),
            child: Row(
              children: [
                SizedBox(
                  width: 20,
                  child: Text(
                    element,
                    style: TextStyle(
                      fontFamily: XuanLiFonts.serif,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: _wuxingColors[element],
                    ),
                  ),
                ),
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(3),
                    child: LinearProgressIndicator(
                      value: ((profile.wuxing[element] ?? 0) / 100).clamp(
                        0.0,
                        1.0,
                      ),
                      minHeight: 6,
                      backgroundColor: _paper.withValues(alpha: 0.1),
                      valueColor: AlwaysStoppedAnimation(
                        _wuxingColors[element]!,
                      ),
                    ),
                  ),
                ),
                SizedBox(
                  width: 38,
                  child: Text(
                    '${profile.wuxing[element] ?? 0}%',
                    textAlign: TextAlign.right,
                    style: TextStyle(
                      fontSize: 11,
                      color: _paper.withValues(alpha: 0.7),
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _strengths() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final item in combo.strengths)
          Padding(
            padding: const EdgeInsets.only(bottom: 5),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 用形狀而唔係「✦」字元：subset 字體冇呢個 glyph，圖會缺字。
                Padding(
                  padding: const EdgeInsets.only(top: 7, right: 10),
                  child: Transform.rotate(
                    angle: 0.785398,
                    child: Container(width: 6, height: 6, color: _gold),
                  ),
                ),
                Expanded(
                  child: Text(
                    item,
                    style: const TextStyle(
                      fontSize: 13,
                      height: 1.5,
                      color: _paper,
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
