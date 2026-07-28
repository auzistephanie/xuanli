import 'package:flutter/material.dart';

import '../../theme/xuanli_theme.dart';

/// 活動 chip（design html `.chipTag`，選中實心藏藍底，未選中outline）。
class ActivityChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const ActivityChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.xuanliColors;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 7),
        decoration: BoxDecoration(
          color: selected ? colors.ink : colors.cardSurface,
          border: selected ? null : Border.all(color: colors.ink12),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12.5,
            color: selected ? colors.paper : colors.ink,
          ),
        ),
      ),
    );
  }
}

/// 反向擇日結果卡（design html 結果卡區塊）。[showCalendarActions] 淨係
/// 畀排名最高嗰張卡用（design html 淨係第一張示範咗日曆按鈕列）；
/// 日曆整合本身係 stub（spec §9.9 真整合留返之後 sub-plan）。
class ResultCard extends StatelessWidget {
  final String dateLabel;
  final int stars; // 1-5
  final String subtitleLine;
  final String reason;
  final bool showCalendarActions;

  const ResultCard({
    super.key,
    required this.dateLabel,
    required this.stars,
    required this.subtitleLine,
    required this.reason,
    required this.showCalendarActions,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.xuanliColors;
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colors.cardSurface,
        border: Border(left: BorderSide(color: colors.jade, width: 4)),
        borderRadius: BorderRadius.circular(XuanLiRadii.card),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                dateLabel,
                style: TextStyle(
                  fontFamily: XuanLiFonts.serif,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: colors.ink,
                ),
              ),
              Text(
                '★' * stars + '☆' * (5 - stars),
                style: TextStyle(color: colors.gold, fontSize: 13, letterSpacing: 1),
              ),
            ],
          ),
          const SizedBox(height: 3),
          Text(
            subtitleLine,
            style: TextStyle(fontSize: 11, color: colors.ink60),
          ),
          const SizedBox(height: 7),
          Text(
            reason,
            style: TextStyle(fontSize: 12.5, color: colors.ink, height: 1.75),
          ),
          if (showCalendarActions) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () => ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('日曆整合 — 之後 sub-plan 起')),
                    ),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: colors.ink,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '＋ 加入我嘅日曆',
                        style: TextStyle(fontSize: 11.5, color: colors.paper, letterSpacing: 1),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: GestureDetector(
                    onTap: () => ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('日曆整合 — 之後 sub-plan 起')),
                    ),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        border: Border.all(color: colors.ink12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '當日行程 ›',
                        style: TextStyle(fontSize: 11.5, color: colors.ink60),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
