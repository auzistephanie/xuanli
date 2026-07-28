import 'package:flutter/material.dart';

import '../../models/day_reading.dart';
import '../../theme/xuanli_theme.dart';

/// 雙環卡入面單一個環（design html `.ring` + SVG，用
/// [CircularProgressIndicator] 嘅 `strokeCap: StrokeCap.round` 對應
/// SVG 嘅 `stroke-linecap="round"`）。
class ScoreRing extends StatelessWidget {
  final int score; // 0-100
  final Color ringColor;
  final String label;

  const ScoreRing({
    super.key,
    required this.score,
    required this.ringColor,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.xuanliColors;
    return SizedBox(
      width: 104,
      height: 104,
      child: Stack(
        alignment: Alignment.center,
        children: [
          SizedBox(
            width: 104,
            height: 104,
            child: CircularProgressIndicator(
              value: score / 100,
              strokeWidth: 9,
              strokeCap: StrokeCap.round,
              backgroundColor: colors.paper2,
              color: ringColor,
            ),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '$score',
                style: TextStyle(
                  fontFamily: XuanLiFonts.serif,
                  fontSize: 30,
                  fontWeight: FontWeight.w900,
                  color: colors.ink,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                label,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 10,
                  color: colors.ink60,
                  letterSpacing: 1,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// 宜／忌其中一欄（design html `.yjCol`）。[isYi] 揀玉綠（宜）定朱紅
/// （忌）主題色。[extraNote]（例如避開時辰）淡色顯示喺項目列表下面。
///
/// [items] 有機會係空 list ——「宜」有真實可能全空（`almanac.dart` 明確
/// 處理咗 `yi.isEmpty` 呢個 case，掛落 `isYiVague` flag），所以呢度加咗
/// 空狀態 fallback，唔會淨係得個標題掛喺度。
///
/// 呢個 widget 內部自己包咗 [Expanded]——spec 入面呢個 widget 淨係得
/// 一種用法：同另一個 `YjColumn` 兩欄並排塞入一個 `Row`。將 `Expanded`
/// 交由呼叫方自己包，靠 doc comment 提醒，試過一次就證明唔可靠（第一稿
/// 咁做，Task 5 個計劃樣板碼就漏咗冇包，會即刻 crash）。搬入嚟 widget
/// 本身，令「兩欄並排」呢個唯一用法結構上冚晒，唔使靠人記得。
class YjColumn extends StatelessWidget {
  final String dotLabel; // '宜' | '忌'
  final String title; // '今日宜' | '今日忌'
  final List<YjItem> items;
  final bool isYi;
  final String? extraNote;

  const YjColumn({
    super.key,
    required this.dotLabel,
    required this.title,
    required this.items,
    required this.isYi,
    this.extraNote,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.xuanliColors;
    final themeColor = isYi ? colors.jade : colors.red;
    final bgColor = isYi
        ? colors.jade.withValues(alpha: 0.09)
        : colors.red.withValues(alpha: 0.07);
    final borderColor = isYi
        ? colors.jade.withValues(alpha: 0.25)
        : colors.red.withValues(alpha: 0.22);

    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: bgColor,
          border: Border.all(color: borderColor),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 20,
                  height: 20,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: themeColor,
                    borderRadius: BorderRadius.circular(5),
                  ),
                  child: Text(
                    dotLabel,
                    style: TextStyle(
                      color: colors.paper,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  title,
                  style: TextStyle(
                    fontFamily: XuanLiFonts.serif,
                    fontSize: 15,
                    letterSpacing: 2,
                    color: themeColor,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (items.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: Text(
                  '冇特別注明',
                  style: TextStyle(fontSize: 12.5, color: colors.ink30),
                ),
              ),
            for (final item in items)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Flexible(
                      child: Text(
                        item.label,
                        style: TextStyle(fontSize: 12.5, color: colors.ink),
                      ),
                    ),
                    if (item.matchesUser)
                      Text(
                        '✦ 合你',
                        style: TextStyle(
                          fontSize: 9.5,
                          color: colors.gold,
                          letterSpacing: 1,
                        ),
                      ),
                  ],
                ),
              ),
            if (extraNote != null)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: Text(
                  extraNote!,
                  style: TextStyle(fontSize: 12.5, color: colors.ink30),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// 🔮 今日貼身建議卡（design html `.card` 金色主題變體）。
class AdviceCard extends StatelessWidget {
  final String advice;

  const AdviceCard({super.key, required this.advice});

  @override
  Widget build(BuildContext context) {
    final colors = context.xuanliColors;
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.gold.withValues(alpha: 0.08),
        border: Border.all(color: colors.gold.withValues(alpha: 0.35)),
        borderRadius: BorderRadius.circular(XuanLiRadii.card),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '🔮 今日貼身建議',
            style: TextStyle(
              fontSize: 10.5,
              letterSpacing: 2,
              color: colors.gold,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            advice,
            style: TextStyle(
              fontFamily: XuanLiFonts.serif,
              fontSize: 13.5,
              height: 1.85,
              color: colors.ink,
            ),
          ),
        ],
      ),
    );
  }
}
