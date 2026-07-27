import 'package:lunar/lunar.dart';
import 'wuxing_tables.dart';

/// 流年概覽（spec §9.1 命理檔案卡「流年+沖太歲提示」）——MVP 簡化版，
/// 淨係計算今年天干地支 + 沖唔沖用戶生肖，唔做完整流年吉凶排盤
/// （同 ziwei.dart 降級版一樣嘅範圍決定：夠用、deterministic，
/// 唔喺 MVP 度追求命理學上完整——已同 Stephanie 確認）。
class AnnualOutlook {
  final String yearGanZhi; // "丙午"
  final bool isZodiacClash; // 今年地支沖唔沖用戶年支（沖太歲）
  final String summary; // 模板文案，畀檔案卡直接顯示

  AnnualOutlook({
    required this.yearGanZhi,
    required this.isZodiacClash,
    required this.summary,
  });
}

/// [date] 通常傳今日；[userYearZhi] = 用戶四柱年支
/// （`profile.pillars[0]` 最後一個字）。
AnnualOutlook computeAnnualOutlook({
  required DateTime date,
  required String userYearZhi,
}) {
  final lunar = Solar.fromYmd(date.year, date.month, date.day).getLunar();
  final yearGanZhi = lunar.getYearInGanZhi();
  final yearZhi = yearGanZhi.substring(1);
  final isZodiacClash = zhiClash[yearZhi] == userYearZhi;

  final summary = isZodiacClash
      ? '$yearGanZhi流年：沖太歲，流年運勢反覆，凡事宜留一線，忌臨時改大計。'
      : '$yearGanZhi流年：本年整體平順，留意人際關係嘅小變動。';

  return AnnualOutlook(
    yearGanZhi: yearGanZhi,
    isZodiacClash: isZodiacClash,
    summary: summary,
  );
}
