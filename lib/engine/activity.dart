import 'dart:convert';
import 'almanac.dart';

class Activity {
  final String name;
  final List<String> hitKeywords;
  final List<String> goodZhiXing;
  final String element;
  final List<String> avoidKeywords;

  Activity({
    required this.name,
    required this.hitKeywords,
    required this.goodZhiXing,
    required this.element,
    required this.avoidKeywords,
  });

  factory Activity.fromJson(Map<String, dynamic> json) => Activity(
        name: json['name'] as String,
        hitKeywords: List<String>.from(json['hitKeywords'] as List),
        goodZhiXing: List<String>.from(json['goodZhiXing'] as List),
        element: json['element'] as String,
        avoidKeywords: List<String>.from(json['avoidKeywords'] as List),
      );
}

class ActivityDayResult {
  final DateTime date;
  final int score;
  final int stars; // 1-5
  ActivityDayResult({required this.date, required this.score, required this.stars});
}

List<Activity>? _activitiesCache;

void initActivities(String jsonStr) {
  final list = json.decode(jsonStr) as List;
  _activitiesCache =
      list.map((e) => Activity.fromJson(e as Map<String, dynamic>)).toList();
}

List<Activity> loadActivities() {
  final cache = _activitiesCache;
  if (cache == null) {
    throw StateError(
      'initActivities() must be called before loadActivities() — call it '
      'once at app startup (or in test setUpAll) with '
      'lib/data/activities.json\'s contents.',
    );
  }
  return cache;
}

/// 評分 = 活動分（關鍵字+建除命中）40% + 命理分 40% + 五行親和 20%。
/// [activity] 嘅 avoidKeywords 命中 [day] 嘅忌 → null（淘汰），**除非 avoidKeywords 為空**
/// （例如「睇醫生」設計上冇忌關鍵字，永遠唔會俾呢條規則淘汰——安全線見 spec §7）。
int? scoreActivityForDay({
  required Activity activity,
  required AlmanacDay day,
  required List<String> favorable,
  required int fortuneScore,
}) {
  if (activity.avoidKeywords.isNotEmpty &&
      activity.avoidKeywords.any((k) => day.ji.contains(k))) {
    return null;
  }

  final keywordHit = activity.hitKeywords.any((k) => day.yi.contains(k));
  final zhiXingHit = activity.goodZhiXing.contains(day.zhiXing);
  var activityScore = 0;
  if (keywordHit) activityScore += 60;
  if (zhiXingHit) activityScore += 40;
  activityScore = activityScore.clamp(0, 100);

  final elementBonus = favorable.contains(activity.element) ? 100 : 0;

  final total =
      (activityScore * 0.4 + fortuneScore * 0.4 + elementBonus * 0.2).round();
  return total.clamp(0, 100);
}

/// 喺 [dates] 範圍內幫 [activityName] 呢個活動排序，取分數最高頭 5 日。
/// [fortuneScoreOf] 由 caller 傳入（scoring.dart 嘅 computeFortuneScore 已經要 favorable/userYearZhi，
/// 呢度用 callback 避免 activity.dart 同 scoring.dart 互相 import 出現循環依賴）。
List<ActivityDayResult> rankActivities({
  required String activityName,
  required List<DateTime> dates,
  required List<String> favorable,
  required int Function(DateTime date) fortuneScoreOf,
}) {
  final activity = loadActivities().firstWhere((a) => a.name == activityName);
  final results = <ActivityDayResult>[];
  for (final date in dates) {
    final day = AlmanacDay.forDate(date);
    final fortuneScore = fortuneScoreOf(date);
    final score = scoreActivityForDay(
        activity: activity, day: day, favorable: favorable, fortuneScore: fortuneScore);
    if (score != null) {
      results.add(ActivityDayResult(date: date, score: score, stars: _starsFor(score)));
    }
  }
  results.sort((a, b) => b.score.compareTo(a.score));
  return results.take(5).toList();
}

int _starsFor(int score) {
  // 分數五等分：0-20→1, 21-40→2, 41-60→3, 61-80→4, 81-100→5
  final stars = (score / 20).ceil();
  return stars.clamp(1, 5);
}
