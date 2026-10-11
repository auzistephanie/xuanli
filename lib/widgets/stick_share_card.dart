import 'package:flutter/material.dart';

import '../engine/daily_stick.dart';
import '../theme/xuanli_theme.dart';
import 'share_parts.dart';
import 'vertical_verse.dart';

/// 每日一籤分享卡（9:16）。只放日期、籤號、籤級、籤詩同解曰——
/// **唔放姓名、出生資料、命理分**。
class StickShareCard extends StatelessWidget {
  final DailyStick stick;
  final DateTime date;

  const StickShareCard({super.key, required this.stick, required this.date});

  @override
  Widget build(BuildContext context) {
    return ShareCardBackground(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const ShareBrand(),
          const SizedBox(height: 14),
          Text(
            '${date.year}年${date.month}月${date.day}日・今日一籤',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, letterSpacing: 3, color: shareGold.withValues(alpha: 0.95)),
          ),
          const SizedBox(height: 14),
          Text(
            stick.levelName,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontFamily: XuanLiFonts.serif,
              fontSize: 42,
              fontWeight: FontWeight.w900,
              letterSpacing: 8,
              color: sharePaper,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            stick.numberLabel,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontFamily: XuanLiFonts.serif,
              fontSize: 16,
              letterSpacing: 4,
              color: shareGold,
            ),
          ),
          const SizedBox(height: 16),
          Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 16),
              decoration: BoxDecoration(
                border: Border.all(color: shareGold.withValues(alpha: 0.55)),
                borderRadius: BorderRadius.circular(6),
                color: sharePaper.withValues(alpha: 0.04),
              ),
              child: VerticalVerse(
                verse: stick.verse,
                color: sharePaper,
                fontSize: 21,
                columnGap: 14,
              ),
            ),
          ),
          const SizedBox(height: 14),
          Text(
            stick.interpretation,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, height: 1.65, color: sharePaper.withValues(alpha: 0.85)),
          ),
          const Spacer(),
          const SizedBox(height: 8),
          const ShareFooter(headline: '掃碼抽你嘅今日籤'),
        ],
      ),
    );
  }
}
