import 'package:flutter/material.dart';

import '../../models/combo.dart';
import '../../models/profile.dart';
import '../../theme/xuanli_theme.dart';

/// 組合詳解頁（spec §9.5）：由檔案卡撳入，顯示 [profile] 嘅日主×MBTI
/// 組合（160 模板之一，`combos.json`／`getCombo()` 已喺 Phase 1 起好）。
/// 純顯示畫面，冇自己嘅 state。
class ComboDetailScreen extends StatelessWidget {
  final Profile profile;

  const ComboDetailScreen({super.key, required this.profile});

  @override
  Widget build(BuildContext context) {
    final colors = context.xuanliColors;
    final dayGan = profile.pillars[2].substring(0, 1);
    final combo = getCombo(dayGan: dayGan, mbti: profile.mbti);

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(context, colors),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(18, 4, 18, 24),
                child: Column(
                  children: [
                    _buildNameCard(colors, dayGan, combo),
                    const SizedBox(height: 12),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(child: _buildListCard(colors, '✦ 你嘅優勢', colors.jade, combo.strengths)),
                        const SizedBox(width: 10),
                        Expanded(child: _buildListCard(colors, '◈ 留意位', colors.red, combo.watchouts)),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _buildHowToWinCard(colors, combo),
                    const SizedBox(height: 12),
                    _buildRarityPlaceholder(colors, dayGan),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, XuanLiColors colors) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 6, 10, 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          GestureDetector(
            onTap: () => Navigator.of(context).pop(),
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: Text('‹', style: TextStyle(fontSize: 22, color: colors.ink60)),
            ),
          ),
          Text(
            '我嘅組合',
            style: TextStyle(
              fontFamily: XuanLiFonts.serif,
              fontWeight: FontWeight.w700,
              fontSize: 16,
              color: colors.ink,
            ),
          ),
          GestureDetector(
            onTap: () => ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('分享卡 — 第二版先做')),
            ),
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: Text('⇪', style: TextStyle(fontSize: 18, color: colors.ink60)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNameCard(XuanLiColors colors, String dayGan, Combo combo) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 22),
      decoration: BoxDecoration(
        color: colors.cardSurface,
        borderRadius: BorderRadius.circular(XuanLiRadii.card),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                decoration: BoxDecoration(
                  color: colors.jade.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '$dayGan${_dayGanElement(dayGan)}日主',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: colors.jade),
                ),
              ),
              const SizedBox(width: 10),
              Text('×', style: TextStyle(fontFamily: XuanLiFonts.serif, fontSize: 15, color: colors.gold)),
              const SizedBox(width: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                decoration: BoxDecoration(
                  color: colors.gold,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  profile.mbti,
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: colors.ink),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            combo.name,
            style: TextStyle(
              fontFamily: XuanLiFonts.serif,
              fontSize: 28,
              fontWeight: FontWeight.w900,
              letterSpacing: 6,
              color: colors.ink,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 6),
          Text(
            combo.motto,
            style: TextStyle(fontSize: 11, color: colors.gold, letterSpacing: 2),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 14),
          Text(
            combo.description,
            style: TextStyle(fontSize: 12.5, height: 1.8, color: colors.ink60),
            textAlign: TextAlign.left,
          ),
        ],
      ),
    );
  }

  Widget _buildListCard(XuanLiColors colors, String title, Color titleColor, List<String> items) {
    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: colors.cardSurface,
        borderRadius: BorderRadius.circular(XuanLiRadii.card),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(fontSize: 11, letterSpacing: 2, fontWeight: FontWeight.w700, color: titleColor),
          ),
          const SizedBox(height: 7),
          for (final item in items)
            Padding(
              padding: const EdgeInsets.only(bottom: 2),
              child: Text(item, style: TextStyle(fontSize: 12, height: 1.6, color: colors.ink)),
            ),
        ],
      ),
    );
  }

  Widget _buildHowToWinCard(XuanLiColors colors, Combo combo) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: colors.cardSurface,
        borderRadius: BorderRadius.circular(XuanLiRadii.card),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '☾ 點樣發力（跟你嘅組合）',
            style: TextStyle(fontSize: 11, letterSpacing: 2, fontWeight: FontWeight.w700, color: colors.gold),
          ),
          const SizedBox(height: 7),
          Text(combo.howToWin, style: TextStyle(fontSize: 12, height: 1.7, color: colors.ink)),
        ],
      ),
    );
  }

  Widget _buildRarityPlaceholder(XuanLiColors colors, String dayGan) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: colors.cardSurface,
        border: Border.all(color: colors.ink12, style: BorderStyle.solid),
        borderRadius: BorderRadius.circular(XuanLiRadii.card),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            '$dayGan${_dayGanElement(dayGan)} × ${profile.mbti}・稀有度',
            style: TextStyle(fontSize: 11.5, color: colors.ink60),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: colors.paper2,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text('即將推出', style: TextStyle(fontSize: 11, color: colors.ink30)),
          ),
        ],
      ),
    );
  }

  static const _ganElement = {
    '甲': '木', '乙': '木', '丙': '火', '丁': '火', '戊': '土',
    '己': '土', '庚': '金', '辛': '金', '壬': '水', '癸': '水',
  };

  String _dayGanElement(String dayGan) => _ganElement[dayGan]!;
}
