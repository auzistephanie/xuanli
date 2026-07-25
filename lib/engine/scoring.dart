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

/// 建除十二神：屬「動」嘅六神（利 E）。
/// 建除十二神已窮盡分做動／靜兩組，冇灰色地帶 → E/I 呢軸冇 ambiguous 狀態。
const _dongZhiXing = {'建', '除', '危', '成', '開'};

/// E/I 軸（spec §6.3）：建除屬動 → 利 E；屬靜 → 利 I。
/// 十二建除已窮盡兩分，呢軸冇 ambiguous（15 分）狀態，只有 25 / 8。
/// 判斷邏輯只需查 [_dongZhiXing]（唔屬動即屬靜），因為 spec 已確認 12 建除
/// 窮盡分做動／靜兩組，冇第三種可能。
int axisScoreEI(AlmanacDay day, String userLetter) {
  final dayLeansE = _dongZhiXing.contains(day.zhiXing);
  final matches = (dayLeansE && userLetter == 'E') || (!dayLeansE && userLetter == 'I');
  return matches ? 25 : 8;
}

/// S/N 軸（spec §6.3）：宜項含糊（諸事不宜／餘事勿取）→ 利 N；
/// 宜項 >=6 具體 → 利 S；其餘（宜項 1–5 項、唔含糊）→ ambiguous（15）。
int axisScoreSN(AlmanacDay day, String userLetter) {
  if (day.isYiVague) {
    return userLetter == 'N' ? 25 : 8;
  }
  if (day.yi.length >= 6) {
    return userLetter == 'S' ? 25 : 8;
  }
  return 15;
}

/// T/F 軸（spec §6.3）：吉神 >=3 → 利 F；凶煞多過吉神 → 利 T；其餘 ambiguous（15）。
int axisScoreTF(AlmanacDay day, String userLetter) {
  if (day.jiShenCount >= 3) {
    return userLetter == 'F' ? 25 : 8;
  }
  if (day.xiongShaCount > day.jiShenCount) {
    return userLetter == 'T' ? 25 : 8;
  }
  return 15;
}

/// J/P 軸（spec §6.3）：有沖／建除屬破危（動盪）→ 利 P；
/// 無沖且建除屬定成收（穩定）→ 利 J；其餘 ambiguous（15）。
int axisScoreJP(AlmanacDay day, {required bool hasClash, required String userLetter}) {
  final isVolatile = hasClash || day.zhiXing == '破' || day.zhiXing == '危';
  if (isVolatile) {
    return userLetter == 'P' ? 25 : 8;
  }
  final isStable = !hasClash && (day.zhiXing == '定' || day.zhiXing == '成' || day.zhiXing == '收');
  if (isStable) {
    return userLetter == 'J' ? 25 : 8;
  }
  return 15;
}

/// 計算 [day] 對指定 [mbti]（四字母，例如 "ISFP"）嘅契合度分（spec §6.3）。
/// 完全獨立於 [computeFortuneScore]：唔會讀取 favorable/unfavorable，
/// 淨係取 [day]／MBTI 字母／[hasClash]。
int computeMbtiScore({required AlmanacDay day, required String mbti, required bool hasClash}) {
  final letters = mbti.split('');
  final score = axisScoreEI(day, letters[0]) +
      axisScoreSN(day, letters[1]) +
      axisScoreTF(day, letters[2]) +
      axisScoreJP(day, hasClash: hasClash, userLetter: letters[3]);
  return score.clamp(0, 100);
}
