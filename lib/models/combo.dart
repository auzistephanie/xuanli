import 'dart:convert';

class Combo {
  final String name;
  final String palaceTitle;
  final String roleLine;
  final String plainLine;
  final String thisIsYou;
  final List<String> daily;
  final String blindSpot;
  final List<String> jobs;
  final String bestMatchKey;
  final String bestMatchWhy;

  /// 靜態一句。引擎沒有按月替換文案的入口，所以不寫月柱，過了戊戌月仍可用。
  final String reminder;
  final String luckyColor;
  final String luckyNumber;
  final String luckyDirection;
  final String shareLine;

  Combo({
    required this.name,
    required this.palaceTitle,
    required this.roleLine,
    required this.plainLine,
    required this.thisIsYou,
    required this.daily,
    required this.blindSpot,
    required this.jobs,
    required this.bestMatchKey,
    required this.bestMatchWhy,
    required this.reminder,
    required this.luckyColor,
    required this.luckyNumber,
    required this.luckyDirection,
    required this.shareLine,
  });

  String get luckyText => '$luckyColor，數字 $luckyNumber，面朝$luckyDirection。';

  /// 「癸水命・御前顧問（INFJ）。水生木，……」
  String bestMatchDisplay() {
    final other = loadCombos()[bestMatchKey];
    if (other == null) return bestMatchWhy;
    final mbti = bestMatchKey.split('_').last;
    final head = other.name.split('｜').first;
    return '$head（$mbti）。$bestMatchWhy';
  }

  factory Combo.fromJson(Map<String, dynamic> json) => Combo(
        name: json['name'] as String,
        palaceTitle: json['palaceTitle'] as String,
        roleLine: json['roleLine'] as String,
        plainLine: json['plainLine'] as String,
        thisIsYou: json['thisIsYou'] as String,
        daily: List<String>.from(json['daily'] as List),
        blindSpot: json['blindSpot'] as String,
        jobs: List<String>.from(json['jobs'] as List),
        bestMatchKey: json['bestMatchKey'] as String,
        bestMatchWhy: json['bestMatchWhy'] as String,
        reminder: json['reminder'] as String,
        luckyColor: json['luckyColor'] as String,
        luckyNumber: json['luckyNumber'] as String,
        luckyDirection: json['luckyDirection'] as String,
        shareLine: json['shareLine'] as String,
      );
}

Map<String, Combo>? _cache;

void initCombos(String jsonStr) {
  final jsonMap = json.decode(jsonStr) as Map<String, dynamic>;
  _cache = jsonMap.map((k, v) => MapEntry(k, Combo.fromJson(v as Map<String, dynamic>)));
}

/// 載入 lib/data/combos.json（160 個組合，key = "日主天干_MBTI"）。
/// 要喺 app 啟動時 call 過 [initCombos] 先可以用。
Map<String, Combo> loadCombos() {
  final cache = _cache;
  if (cache == null) {
    throw StateError(
      'initCombos() must be called before loadCombos() — call it once at '
      'app startup (or in test setUpAll) with lib/data/combos.json\'s contents.',
    );
  }
  return cache;
}

Combo getCombo({required String dayGan, required String mbti}) {
  return loadCombos()['${dayGan}_$mbti']!;
}
