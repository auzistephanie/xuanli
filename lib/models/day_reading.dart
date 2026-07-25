/// 單一宜/忌項目，附是否同用戶命理相關（用嚟高亮）。
class YjItem {
  final String label;
  final bool matchesUser;
  const YjItem({required this.label, required this.matchesUser});
}

/// 單日個人化運程結果（傳統通勝 + 命理分 + MBTI 契合度，spec §5）。
class DayReading {
  final DateTime date;
  final String ganzhiDay;
  final String lunarLabel;
  final String zhiXing;
  final String chong;
  final int fortuneScore;
  final int mbtiScore;
  final String band; // "吉"|"平"|"忌"
  final List<YjItem> yi;
  final List<YjItem> ji;
  final String advice;
  final String? clashWarning;
  final String? avoidHour;

  DayReading({
    required this.date,
    required this.ganzhiDay,
    required this.lunarLabel,
    required this.zhiXing,
    required this.chong,
    required this.fortuneScore,
    required this.mbtiScore,
    required this.band,
    required this.yi,
    required this.ji,
    required this.advice,
    required this.clashWarning,
    required this.avoidHour,
  });
}
