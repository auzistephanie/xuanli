import 'package:flutter/material.dart';

import '../models/combo.dart';
import '../models/profile.dart';
import '../theme/xuanli_theme.dart';

/// 分享卡邏輯尺寸（9:16，以 pixelRatio 3 輸出 1080×1920，啱 IG Story）。
const shareCardSize = Size(360, 640);

// 分享卡一律用藏藍深色版（design html 檔案卡嘅配色），唔跟系統深淺色——
// 圖要喺任何人嘅 feed 入面睇落都一致。
const _navy = Color(0xFF1C2440);
const _navyDeep = Color(0xFF131829);
const _paper = Color(0xFFF6EFE2);
const _gold = Color(0xFFC9A24B);
const _sealRed = Color(0xFFB23A3A);

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
    return SizedBox.fromSize(
      size: shareCardSize,
      child: Material(
        type: MaterialType.transparency,
        child: DecoratedBox(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [_navy, _navyDeep],
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(30, 34, 30, 26),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _brand(),
                const SizedBox(height: 34),
                _chips(),
                const SizedBox(height: 22),
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
                const SizedBox(height: 26),
                _divider(),
                const SizedBox(height: 20),
                _wuxingBars(),
                const SizedBox(height: 22),
                _strengths(),
                const Spacer(),
                _footer(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _brand() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          width: 30,
          height: 30,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: _sealRed,
            borderRadius: BorderRadius.circular(5),
          ),
          child: const Text(
            '玄',
            style: TextStyle(
              fontFamily: XuanLiFonts.serif,
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: _paper,
              height: 1.1,
            ),
          ),
        ),
        const SizedBox(width: 10),
        const Text(
          '玄曆',
          style: TextStyle(
            fontFamily: XuanLiFonts.serif,
            fontSize: 20,
            fontWeight: FontWeight.w700,
            letterSpacing: 4,
            color: _paper,
          ),
        ),
      ],
    );
  }

  Widget _chips() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _chip('${profile.dayMaster}日主', Colors.transparent, _paper, border: _gold),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 10),
          child: Text('×',
              style: TextStyle(fontFamily: XuanLiFonts.serif, fontSize: 16, color: _gold)),
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

  Widget _divider() {
    return Row(
      children: [
        Expanded(child: Container(height: 1, color: _gold.withValues(alpha: 0.35))),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 10),
          child: Text('五行', style: TextStyle(fontSize: 11, letterSpacing: 3, color: _gold)),
        ),
        Expanded(child: Container(height: 1, color: _gold.withValues(alpha: 0.35))),
      ],
    );
  }

  Widget _wuxingBars() {
    return Column(
      children: [
        for (final element in _wuxingOrder)
          Padding(
            padding: const EdgeInsets.only(bottom: 7),
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
                      value: ((profile.wuxing[element] ?? 0) / 100).clamp(0.0, 1.0),
                      minHeight: 6,
                      backgroundColor: _paper.withValues(alpha: 0.1),
                      valueColor: AlwaysStoppedAnimation(_wuxingColors[element]!),
                    ),
                  ),
                ),
                SizedBox(
                  width: 38,
                  child: Text(
                    '${profile.wuxing[element] ?? 0}%',
                    textAlign: TextAlign.right,
                    style: TextStyle(fontSize: 11, color: _paper.withValues(alpha: 0.7)),
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
                    style: const TextStyle(fontSize: 13, height: 1.5, color: _paper),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _footer() {
    return Column(
      children: [
        Text(
          '睇下你嘅八字 × MBTI 組合',
          style: TextStyle(
            fontSize: 12,
            letterSpacing: 2,
            color: _paper.withValues(alpha: 0.85),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          '玄曆 XuanLi・僅供參考',
          style: TextStyle(fontSize: 10, letterSpacing: 1, color: _paper.withValues(alpha: 0.4)),
        ),
      ],
    );
  }
}
