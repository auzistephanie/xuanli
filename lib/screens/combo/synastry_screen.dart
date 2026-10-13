import 'package:flutter/material.dart';

import '../../engine/synastry.dart';
import '../../models/combo.dart';
import '../../models/profile.dart';
import '../../theme/xuanli_theme.dart';
import '../../widgets/marks.dart';
import '../../widgets/synastry_share_card.dart';
import 'share_preview_screen.dart';

/// 兩人合盤結果頁。[friend] 只係記憶體入面嘅 profile，唔會儲存。
class SynastryScreen extends StatelessWidget {
  final Profile me;
  final Profile friend;
  final VoidCallback onTryAnother;

  const SynastryScreen({
    super.key,
    required this.me,
    required this.friend,
    required this.onTryAnother,
  });

  Combo _combo(Profile p) =>
      getCombo(dayGan: p.pillars[2].substring(0, 1), mbti: p.mbti);

  @override
  Widget build(BuildContext context) {
    final colors = context.xuanliColors;
    final result = computeSynastry(me, friend);
    final comboA = _combo(me);
    final comboB = _combo(friend);

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(18, 4, 18, 24),
      child: Column(
        children: [
          _hero(colors, result, comboA, comboB),
          const SizedBox(height: 12),
          _card(
            colors,
            title: '你哋嘅關係',
            titleColor: colors.gold,
            mark: MoonMark(color: colors.gold),
            child: Text(
              result.description,
              style: TextStyle(fontSize: 12.5, height: 1.8, color: colors.ink),
            ),
          ),
          const SizedBox(height: 12),
          _card(
            colors,
            title: 'MBTI・${result.mbtiLabel}',
            titleColor: colors.jade,
            child: Text(
              result.mbtiNote,
              style: TextStyle(fontSize: 12.5, height: 1.8, color: colors.ink),
            ),
          ),
          const SizedBox(height: 12),
          _card(
            colors,
            title: '相處之道',
            titleColor: colors.gold,
            mark: DiamondMark(color: colors.gold),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final tip in result.tips)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Text(
                      tip,
                      style: TextStyle(fontSize: 12.5, height: 1.7, color: colors.ink),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: FilledButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => SharePreviewScreen(
                    title: '分享合盤',
                    filename: '合盤-${result.name}',
                    card: SynastryShareCard(
                      comboNameA: comboA.palaceTitle,
                      comboNameB: comboB.palaceTitle,
                      result: result,
                    ),
                  ),
                ),
              ),
              style: FilledButton.styleFrom(
                backgroundColor: colors.ink,
                foregroundColor: colors.paper,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(XuanLiRadii.card),
                ),
              ),
              child: const Text('分享合盤卡'),
            ),
          ),
          const SizedBox(height: 6),
          TextButton(
            onPressed: onTryAnother,
            child: Text('同另一個朋友合盤', style: TextStyle(color: colors.gold)),
          ),
          const SizedBox(height: 6),
          Text(
            '朋友嘅資料淨係喺呢部機計算，唔會儲存。僅供參考，不代替專業意見。',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 10.5, height: 1.6, color: colors.ink30),
          ),
        ],
      ),
    );
  }

  Widget _hero(XuanLiColors colors, SynastryResult result, Combo a, Combo b) {
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
              Flexible(child: _comboLabel(colors, '你', a.palaceTitle)),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                child: Text(
                  '×',
                  style: TextStyle(
                    fontFamily: XuanLiFonts.serif,
                    fontSize: 16,
                    color: colors.gold,
                  ),
                ),
              ),
              Flexible(child: _comboLabel(colors, '朋友', b.palaceTitle)),
            ],
          ),
          const SizedBox(height: 18),
          Text(
            '五行關係嘅稱呼',
            style: TextStyle(fontSize: 11, letterSpacing: 2, color: colors.ink30),
          ),
          const SizedBox(height: 6),
          Text(
            result.name,
            style: TextStyle(
              fontFamily: XuanLiFonts.serif,
              fontSize: 32,
              fontWeight: FontWeight.w900,
              letterSpacing: 6,
              color: colors.ink,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${result.score}',
                style: TextStyle(
                  fontFamily: XuanLiFonts.serif,
                  fontSize: 44,
                  height: 1.1,
                  fontWeight: FontWeight.w900,
                  color: colors.gold,
                ),
              ),
              const SizedBox(width: 6),
              Padding(
                padding: const EdgeInsets.only(bottom: 7),
                child: Text(
                  '合盤指數・${result.scoreTitle}',
                  style: TextStyle(fontSize: 12, letterSpacing: 1, color: colors.ink60),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 8,
            runSpacing: 8,
            children: [
              _pill(colors, result.stemRelationLabel),
              _pill(colors, result.branchLabel),
              _pill(colors, result.complementLabel),
            ],
          ),
        ],
      ),
    );
  }

  Widget _comboLabel(XuanLiColors colors, String who, String name) => Column(
    children: [
      Text(who, style: TextStyle(fontSize: 10.5, letterSpacing: 2, color: colors.ink30)),
      const SizedBox(height: 2),
      Text(
        name,
        style: TextStyle(
          fontFamily: XuanLiFonts.serif,
          fontSize: 16,
          fontWeight: FontWeight.w700,
          letterSpacing: 2,
          color: colors.ink,
        ),
      ),
    ],
  );

  Widget _pill(XuanLiColors colors, String text) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 4),
    decoration: BoxDecoration(
      color: colors.jade.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(20),
    ),
    child: Text(
      text,
      style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: colors.jade),
    ),
  );

  Widget _card(
    XuanLiColors colors, {
    required String title,
    required Color titleColor,
    required Widget child,
    Widget? mark,
  }) {
    final titleStyle = TextStyle(
      fontSize: 11,
      letterSpacing: 2,
      fontWeight: FontWeight.w700,
      color: titleColor,
    );
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
          mark == null
              ? Text(title, style: titleStyle)
              : MarkedTitle(mark: mark, text: title, style: titleStyle),
          const SizedBox(height: 7),
          child,
        ],
      ),
    );
  }
}
