import 'almanac.dart';
import 'wuxing_tables.dart';

/// 命理分計算結果（spec §6.2）。
class FortuneScoreResult {
  final int score;
  final String band;
  final String? clashWarning;
  FortuneScoreResult({required this.score, required this.band, required this.clashWarning});
}

/// 建除十二神 base 分（spec §6.2）。
const Map<String, int> _zhiXingBase = {
  '建': 55, '除': 65, '滿': 55, '平': 50, '定': 65, '執': 55,
  '破': 20, '危': 50, '成': 70, '收': 50, '開': 65, '閉': 35,
};

/// 地支 → 生肖（用於 clashWarning 文案）。
const Map<String, String> _zhiToZodiac = {
  '子': '鼠', '丑': '牛', '寅': '虎', '卯': '兔', '辰': '龍', '巳': '蛇',
  '午': '馬', '未': '羊', '申': '猴', '酉': '雞', '戌': '狗', '亥': '豬',
};

/// [score] 分帶：≥70 吉 ｜ 40–69 平 ｜ ≤39 忌。
String bandFor(int score) {
  if (score >= 70) return '吉';
  if (score >= 40) return '平';
  return '忌';
}

/// 計算 [day] 對於指定喜/忌五行、年支用戶嘅命理分（spec §6.2）。
/// Deterministic：純 [day]/[favorable]/[unfavorable]/[userYearZhi] input，
/// 冇 `Random`／`DateTime.now()`。
FortuneScoreResult computeFortuneScore({
  required AlmanacDay day,
  required List<String> favorable,
  required List<String> unfavorable,
  required String userYearZhi,
}) {
  var score = _zhiXingBase[day.zhiXing] ?? 50;

  score += (day.jiShenCount * 3).clamp(0, 12);
  score -= (day.xiongShaCount * 4).clamp(0, 16);

  final dayGanElement = ganWuxing[day.dayGan]!;
  if (favorable.contains(dayGanElement)) score += 8;
  if (unfavorable.contains(dayGanElement)) score -= 8;

  final dayZhiElement = zhiWuxing[day.dayZhi]!;
  if (favorable.contains(dayZhiElement)) score += 8;
  if (unfavorable.contains(dayZhiElement)) score -= 8;

  String? clashWarning;
  if (zhiClash[day.dayZhi] == userYearZhi) {
    score -= 20;
    clashWarning = '今日沖你生肖（${_zhiToZodiac[userYearZhi]}）';
  }

  // 通勝「忌：諸事不宜」→ 分數封頂 40。
  if (day.isJiSevere && score > 40) {
    score = 40;
  }

  score = score.clamp(0, 100);

  return FortuneScoreResult(score: score, band: bandFor(score), clashWarning: clashWarning);
}

/// 地支 → 對應鐘點範圍（十二時辰）。
const Map<String, String> _zhiHourRange = {
  '子': '23–1', '丑': '1–3', '寅': '3–5', '卯': '5–7',
  '辰': '7–9', '巳': '9–11', '午': '11–13', '未': '13–15',
  '申': '15–17', '酉': '17–19', '戌': '19–21', '亥': '21–23',
};

/// 用戶日支 [userDayZhi] → 沖佢嘅時辰標籤（例如「申時 15–17」）。
/// 十二地支必定有對沖時辰，唔會有 null case。
String computeAvoidHour(String userDayZhi) {
  final clashingZhi = zhiClash[userDayZhi]!;
  return '$clashingZhi時 ${_zhiHourRange[clashingZhi]}';
}
