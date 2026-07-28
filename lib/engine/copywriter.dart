import 'dart:convert';
import 'activity.dart';
import 'almanac.dart';
import '../models/day_reading.dart';

Map<String, List<String>>? _toneCache;

void initMbtiTones(String jsonStr) {
  final jsonMap = json.decode(jsonStr) as Map<String, dynamic>;
  _toneCache = jsonMap.map((k, v) => MapEntry(k, List<String>.from(v as List)));
}

Map<String, List<String>> _loadMbtiTones() {
  final cache = _toneCache;
  if (cache == null) {
    throw StateError(
      'initMbtiTones() must be called before building advice — call it '
      'once at app startup (or in test setUpAll) with '
      'lib/data/mbti_tones.json\'s contents.',
    );
  }
  return cache;
}

/// 命理段：日干支 × 用戶喜忌關係。
String _fortuneSegment(AlmanacDay day, List<String> favorable, List<String> unfavorable) {
  final leaning = favorable.isNotEmpty ? '你${favorable.join('')}旺而${unfavorable.join('')}弱' : '';
  return '${day.ganzhiDay}${day.zhiXing}日，$leaning。'.replaceAll('，。', '。');
}

/// MBTI 段：由 mbti_tones.json 攞句，用 dayOfYear % length 輪換（deterministic）。
/// 如果 [mbti] 喺 mbti_tones.json 未有內容（Phase 1 淨係填咗 ISFP/ISFJ 兩型示範），
/// 就返回一句 fallback，唔會 crash——其餘 14 型內容係另外嘅文案工作。
String _mbtiSegment(AlmanacDay day, String mbti) {
  final tones = _loadMbtiTones();
  final lines = tones[mbti];
  if (lines == null || lines.isEmpty) {
    return '$mbti 嘅你，跟住今日嘅節奏行就得。';
  }
  final dayOfYear = _dayOfYear(day.date);
  final index = dayOfYear % lines.length;
  return lines[index];
}

int _dayOfYear(DateTime date) {
  return date.difference(DateTime(date.year, 1, 1)).inDays + 1;
}

/// 紫微段：14 主星輕量提示，[ziweiStar] 為 null 就省略呢一段。
String _ziweiSegment(String? ziweiStar) {
  if (ziweiStar == null) return '';
  return '$ziweiStar 坐命嘅你，今日順住個星氣行就啱。';
}

/// 建構今日貼身建議：命理段 + MBTI 段 + 紫微段（可省略）+ 避時提示（可省略）。
/// 全部 deterministic（用 [day.date] 做 dayOfYear seed，唔用 Random/DateTime.now()）。
String buildAdvice({
  required AlmanacDay day,
  required List<String> favorable,
  required List<String> unfavorable,
  required String mbti,
  required String? ziweiStar,
  required String? avoidHour,
}) {
  final segments = <String>[
    _fortuneSegment(day, favorable, unfavorable),
    _mbtiSegment(day, mbti),
  ];
  final ziwei = _ziweiSegment(ziweiStar);
  if (ziwei.isNotEmpty) segments.add(ziwei);
  if (avoidHour != null) segments.add('避開$avoidHour落重要決定。');
  return segments.where((s) => s.isNotEmpty).join('');
}

/// 反向擇日「🔮 原因」文案（spec §7：「每個結果經 copywriter 產生🔮原因」）。
/// MVP 簡化版：檢查 [scoreActivityForDay] 已經計緊嘅 3 個信號
/// （宜項關鍵字命中／建除相合／五行親和），有邊個中就講邊個，
/// 全部唔中就用返一句保底文案——deterministic，唔用 LLM。
String buildActivityReason({
  required Activity activity,
  required AlmanacDay day,
  required List<String> favorable,
}) {
  final keywordHit = activity.hitKeywords.any((k) => day.yi.contains(k));
  final zhiXingHit = activity.goodZhiXing.contains(day.zhiXing);
  final elementMatch = favorable.contains(activity.element);

  final clauses = <String>[];
  if (keywordHit) {
    // .firstWhere（唔用 .first）：日後如果某個活動加多個
    // hitKeyword，要確保引用嘅的確係「通勝入面真係中咗」嗰個字，
    // 唔係淨係嗰個活動嘅第一個字（可能同 [day.yi] 完全冇關）。
    final matchedKeyword = activity.hitKeywords.firstWhere((k) => day.yi.contains(k));
    clauses.add('通勝明載「宜$matchedKeyword」');
  }
  if (zhiXingHit) {
    clauses.add('${day.zhiXing}日利成事');
  }
  if (elementMatch) {
    clauses.add('${activity.element}氣旺，同你相親');
  }

  // 3 個信號全冧唔中通常代表呢日對呢個活動嚟講其實普通（甚至偏忌），
  // 唔應該講「平順」呢類正面字眼誤導用戶——改用中性講法。
  final body = clauses.isEmpty
      ? '今日冇特別命中，${activity.name}僅供參考'
      : clauses.join('，');

  return '🔮 $body。';
}

/// 短版通知文案（spec §9.7：「內容 = copywriter 短版」，例子：
/// 「今日丙戌日・命理分 42・宜祈福靜修，忌簽約。避開申時落大決定。」）。
/// 淨係攞頭 2 個宜、頭 2 個忌（多過就截，全空就寫「無」），
/// deterministic（純 [reading] 做 input，冇 Random/DateTime.now()）。
/// 畀 widget「中」size 同（之後先起嘅）通知排程共用。
String buildNotificationText(DayReading reading) {
  // .take(2) 假設 yi/ji 已經 matchesUser-first 排好（見 almanac.dart 嘅
  // _personalize，經 day_reading_engine.dart 嘅 personalizedYi/personalizedJi
  // 傳落嚟）——呢個 function 只負責截頭 2 個，唔會自己再排一次。
  final yiPart = reading.yi.isEmpty
      ? '無'
      : reading.yi.take(2).map((e) => e.label).join('、');
  final jiPart = reading.ji.isEmpty
      ? '無'
      : reading.ji.take(2).map((e) => e.label).join('、');
  final avoidPart =
      reading.avoidHour != null ? '避開${reading.avoidHour}落大決定。' : '';
  return '今日${reading.ganzhiDay}日・命理分${reading.fortuneScore}・'
      '宜$yiPart，忌$jiPart。$avoidPart';
}
