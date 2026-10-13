import 'package:flutter/material.dart';

import '../../engine/rarity.dart';
import '../../models/combo.dart';
import '../../models/profile.dart';
import '../../theme/brand.dart';
import '../../theme/xuanli_theme.dart';
import '../../widgets/marks.dart';
import '../../widgets/tilt_card.dart';
import '../../widgets/wuxing_orbs.dart';
import 'partner_flow.dart';
import 'share_card_screen.dart';

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
                    _buildNameCard(colors, combo),
                    const SizedBox(height: 12),
                    _buildListCard(colors, '日常寫照', colors.jade, combo.daily),
                    const SizedBox(height: 12),
                    _buildTextCard(colors, '你的盲點', colors.red, combo.blindSpot, mark: DiamondMark(color: colors.red)),
                    const SizedBox(height: 12),
                    _buildListCard(colors, '適合的工作', colors.ink, combo.jobs),
                    const SizedBox(height: 12),
                    _buildTextCard(colors, '最合得來的人', colors.jade, combo.bestMatchDisplay()),
                    const SizedBox(height: 12),
                    _buildTextCard(colors, '給你的提醒', colors.gold, combo.reminder, mark: MoonMark(color: colors.gold)),
                    const SizedBox(height: 12),
                    _buildTextCard(colors, '開運小物', colors.gold, combo.luckyText),
                    const SizedBox(height: 12),
                    _buildRarityCard(colors, dayGan),
                    const SizedBox(height: 12),
                    _buildPartnerEntry(context, colors),
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
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => ShareCardScreen(profile: profile)),
            ),
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: Icon(Icons.ios_share, size: 19, color: colors.ink60, semanticLabel: '分享'),
            ),
          ),
        ],
      ),
    );
  }

  /// 全息名卡：深藍漸變喺淺色／深色主題都一樣，所以卡內一律用
  /// [KairoPalette] 固定色，唔跟 [XuanLiColors]（淺色主題嘅玉色喺深底睇唔清）。
  Widget _buildNameCard(XuanLiColors colors, Combo combo) {
    return TiltCard(
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 22),
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF25305C), Color(0xFF141A33), Color(0xFF0F1328)],
          ),
          borderRadius: BorderRadius.all(Radius.circular(24)),
        ),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                  decoration: BoxDecoration(
                    color: KairoPalette.jadeBright.withValues(alpha: 0.16),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '${profile.dayMaster}日主',
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: KairoPalette.jadeBright),
                  ),
                ),
                const SizedBox(width: 10),
                const Text(
                  '×',
                  style: TextStyle(fontFamily: XuanLiFonts.serif, fontSize: 15, color: KairoPalette.goldBright),
                ),
                const SizedBox(width: 10),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                  decoration: BoxDecoration(color: KairoPalette.gold, borderRadius: BorderRadius.circular(20)),
                  child: Text(
                    profile.mbti,
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: KairoPalette.night),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Text(
              combo.palaceTitle,
              style: const TextStyle(
                fontFamily: XuanLiFonts.serif,
                fontSize: 32,
                fontWeight: FontWeight.w900,
                letterSpacing: 4,
                color: KairoPalette.paper,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 6),
            Text(
              combo.roleLine,
              style: const TextStyle(fontSize: 12, height: 1.5, color: KairoPalette.goldBright),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              combo.plainLine,
              style: TextStyle(fontSize: 13, height: 1.5, color: KairoPalette.paper.withValues(alpha: 0.92)),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              combo.thisIsYou,
              style: TextStyle(fontSize: 13, height: 1.55, color: KairoPalette.paper.withValues(alpha: 0.92)),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 18),
            WuxingOrbs(wuxing: profile.wuxing),
          ],
        ),
      ),
    );
  }

  Widget _buildListCard(XuanLiColors colors, String title, Color titleColor, List<String> items,
      {Widget? mark}) {
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
          _title(title, TextStyle(fontSize: 11, letterSpacing: 2, fontWeight: FontWeight.w700, color: titleColor),
              mark: mark),
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

  Widget _title(String text, TextStyle style, {Widget? mark}) =>
      mark == null ? Text(text, style: style) : MarkedTitle(mark: mark, text: text, style: style);

  Widget _buildTextCard(XuanLiColors colors, String title, Color titleColor, String body, {Widget? mark}) {
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
          _title(title, TextStyle(fontSize: 11, letterSpacing: 2, fontWeight: FontWeight.w700, color: titleColor),
              mark: mark),
          const SizedBox(height: 7),
          Text(body, style: TextStyle(fontSize: 12, height: 1.7, color: colors.ink)),
        ],
      ),
    );
  }

  Widget _buildPartnerEntry(BuildContext context, XuanLiColors colors) {
    return Material(
      color: colors.cardSurface,
      borderRadius: BorderRadius.circular(XuanLiRadii.card),
      child: InkWell(
        borderRadius: BorderRadius.circular(XuanLiRadii.card),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => PartnerFlow(me: profile)),
        ),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          decoration: BoxDecoration(
            border: Border.all(color: colors.gold.withValues(alpha: 0.6)),
            borderRadius: BorderRadius.circular(XuanLiRadii.card),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '同朋友合盤',
                      style: TextStyle(
                        fontFamily: XuanLiFonts.serif,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 2,
                        color: colors.ink,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '輸入朋友生日同 MBTI，睇你哋嘅關係名同合盤指數。佢嘅資料唔會儲存。',
                      style: TextStyle(fontSize: 11.5, height: 1.6, color: colors.ink60),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Icon(Icons.arrow_forward_ios, size: 14, color: colors.gold),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRarityCard(XuanLiColors colors, String dayGan) {
    final rarity = comboRarity(dayGan: dayGan, mbti: profile.mbti);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: colors.cardSurface,
        borderRadius: BorderRadius.circular(XuanLiRadii.card),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${profile.dayMaster} × ${profile.mbti}・稀有度',
                style: TextStyle(fontSize: 11.5, color: colors.ink60),
              ),
              Text(
                '約 ${rarity.percentLabel}',
                style: TextStyle(
                  fontFamily: XuanLiFonts.serif,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: colors.gold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            '大約每 ${rarity.oneIn} 人先有一個同你一樣嘅組合',
            style: TextStyle(fontSize: 12, color: colors.ink),
          ),
          const SizedBox(height: 6),
          Text(rarityFootnote, style: TextStyle(fontSize: 10, height: 1.5, color: colors.ink30)),
        ],
      ),
    );
  }
}
