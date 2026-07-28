import 'dart:convert';
import 'activity.dart';
import 'almanac.dart';

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
    clauses.add('通勝明載「宜${activity.hitKeywords.first}」');
  }
  if (zhiXingHit) {
    clauses.add('${day.zhiXing}日利成事');
  }
  if (elementMatch) {
    clauses.add('${activity.element}氣旺，同你相親');
  }

  final body = clauses.isEmpty
      ? '今日整體平順，適合${activity.name}'
      : clauses.join('，');

  return '🔮 $body。';
}
