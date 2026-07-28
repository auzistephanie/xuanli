import 'package:flutter/material.dart';

import '../../theme/xuanli_theme.dart';

/// 一格月曆格仔嘅顯示資料（screen 計好先遞落嚟，widget 本身唔做
/// engine 計算——同 today_widgets.dart/activity_widgets.dart 一樣嘅
/// 「dumb widget」原則）。
class CalendarCellData {
  final int day;
  final String lunarLabel;
  final String band; // "吉"|"平"|"忌"
  final bool isToday;
  final bool hasEvents; // 永遠 false（stub，行事曆整合留返之後 sub-plan）

  const CalendarCellData({
    required this.day,
    required this.lunarLabel,
    required this.band,
    this.isToday = false,
    this.hasEvents = false,
  });
}

/// 月曆格仔（design html 月 grid）。[leadingBlanks] 係 1 號之前嘅空白格
/// 數量（0-6，由嗰個月 1 號係星期幾決定）。
class CalendarGrid extends StatelessWidget {
  final int leadingBlanks;
  final List<CalendarCellData> days;
  final int? selectedDay;
  final ValueChanged<int> onSelectDay;

  const CalendarGrid({
    super.key,
    required this.leadingBlanks,
    required this.days,
    required this.selectedDay,
    required this.onSelectDay,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.xuanliColors;
    return Column(
      children: [
        GridView.count(
          crossAxisCount: 7,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 4,
          crossAxisSpacing: 4,
          children: [
            for (var i = 0; i < leadingBlanks; i++) const SizedBox.shrink(),
            for (final cell in days) _buildCell(context, colors, cell),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _legendItem(colors, colors.jade, '吉'),
            const SizedBox(width: 14),
            _legendItem(colors, colors.red, '忌'),
            const SizedBox(width: 14),
            _legendItem(colors, colors.ink30, '平'),
            const SizedBox(width: 14),
            Row(
              children: [
                Container(width: 12, height: 3, color: colors.ink60),
                const SizedBox(width: 4),
                Text('有行程', style: TextStyle(fontSize: 10.5, color: colors.ink60)),
              ],
            ),
          ],
        ),
      ],
    );
  }

  Widget _legendItem(XuanLiColors colors, Color dotColor, String label) {
    return Row(
      children: [
        Container(width: 9, height: 9, decoration: BoxDecoration(color: dotColor, borderRadius: BorderRadius.circular(3))),
        const SizedBox(width: 4),
        Text(label, style: TextStyle(fontSize: 10.5, color: colors.ink60)),
      ],
    );
  }

  Widget _buildCell(BuildContext context, XuanLiColors colors, CalendarCellData cell) {
    final dotColor = cell.band == '吉'
        ? colors.jade
        : cell.band == '忌'
            ? colors.red
            : colors.ink30;
    final bgColor = cell.band == '吉'
        ? colors.jade.withValues(alpha: 0.10)
        : cell.band == '忌'
            ? colors.red.withValues(alpha: 0.08)
            : colors.cardSurface;
    final isSelected = cell.day == selectedDay;

    return GestureDetector(
      onTap: () => onSelectDay(cell.day),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 5),
        decoration: BoxDecoration(
          color: bgColor,
          border: Border.all(
            color: cell.isToday ? colors.gold : colors.ink12,
            width: cell.isToday ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(XuanLiRadii.cell),
          boxShadow: isSelected
              ? [BoxShadow(color: colors.jade, spreadRadius: 2, blurRadius: 0)]
              : null,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              '${cell.day}',
              style: TextStyle(
                fontFamily: XuanLiFonts.serif,
                fontWeight: FontWeight.w700,
                fontSize: 13,
                color: colors.ink,
              ),
            ),
            Text(
              cell.lunarLabel,
              style: TextStyle(fontSize: 8.5, color: colors.ink60),
            ),
            const SizedBox(height: 3),
            Container(width: 5, height: 5, decoration: BoxDecoration(color: dotColor, shape: BoxShape.circle)),
            if (cell.hasEvents) ...[
              const SizedBox(height: 2),
              Container(width: 14, height: 2.5, decoration: BoxDecoration(color: colors.ink60, borderRadius: BorderRadius.circular(2))),
            ],
          ],
        ),
      ),
    );
  }
}

/// 展開日卡（design html 撳日展開嗰張卡）。宜/忌用一行精簡列表顯示
/// （唔係 Tab A `YjColumn` 嗰種盒仔），行程部分係 stub。
class DayCard extends StatelessWidget {
  final String dateLabel;
  final String band;
  final int score;
  final String subtitleLine;
  final String yiLine;
  final String jiLine;

  const DayCard({
    super.key,
    required this.dateLabel,
    required this.band,
    required this.score,
    required this.subtitleLine,
    required this.yiLine,
    required this.jiLine,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.xuanliColors;
    final bandColor = band == '吉' ? colors.jade : (band == '忌' ? colors.red : colors.ink60);
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colors.cardSurface,
        border: Border.all(color: colors.ink12),
        borderRadius: BorderRadius.circular(XuanLiRadii.card),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  dateLabel,
                  style: TextStyle(
                    fontFamily: XuanLiFonts.serif,
                    fontSize: 15.5,
                    fontWeight: FontWeight.w700,
                    color: colors.ink,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                decoration: BoxDecoration(
                  color: bandColor.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '$band $score',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: bandColor),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(subtitleLine, style: TextStyle(fontSize: 11, color: colors.ink60)),
          Container(
            margin: const EdgeInsets.only(top: 8),
            padding: const EdgeInsets.only(top: 8),
            decoration: BoxDecoration(border: Border(top: BorderSide(color: colors.ink12))),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text.rich(
                  TextSpan(children: [
                    TextSpan(text: '宜 ', style: TextStyle(color: colors.jade, fontWeight: FontWeight.w700)),
                    TextSpan(text: yiLine, style: TextStyle(color: colors.ink)),
                  ]),
                  style: const TextStyle(fontSize: 12.5, height: 1.7),
                ),
                Text.rich(
                  TextSpan(children: [
                    TextSpan(text: '忌 ', style: TextStyle(color: colors.red, fontWeight: FontWeight.w700)),
                    TextSpan(text: jiLine, style: TextStyle(color: colors.ink)),
                  ]),
                  style: const TextStyle(fontSize: 12.5, height: 1.7),
                ),
              ],
            ),
          ),
          Container(
            margin: const EdgeInsets.only(top: 8),
            padding: const EdgeInsets.only(top: 8),
            decoration: BoxDecoration(border: Border(top: BorderSide(color: colors.ink12))),
            child: Text(
              '📅 你嘅行程 — 行事曆整合之後 sub-plan 起',
              style: TextStyle(fontSize: 11.5, color: colors.ink60),
            ),
          ),
        ],
      ),
    );
  }
}
