import 'dart:convert';
import 'dart:io';

class Combo {
  final String name;
  final String motto;
  final String description;
  final List<String> strengths;
  final List<String> watchouts;
  final String howToWin;

  Combo({
    required this.name,
    required this.motto,
    required this.description,
    required this.strengths,
    required this.watchouts,
    required this.howToWin,
  });

  factory Combo.fromJson(Map<String, dynamic> json) => Combo(
        name: json['name'] as String,
        motto: json['motto'] as String,
        description: json['description'] as String,
        strengths: List<String>.from(json['strengths'] as List),
        watchouts: List<String>.from(json['watchouts'] as List),
        howToWin: json['howToWin'] as String,
      );
}

Map<String, Combo>? _cache;

/// 載入 lib/data/combos.json（160 個組合，key = "日主天干_MBTI"）。
Map<String, Combo> loadCombos() {
  if (_cache != null) return _cache!;
  final file = File('lib/data/combos.json');
  final jsonMap = json.decode(file.readAsStringSync()) as Map<String, dynamic>;
  _cache = jsonMap.map((k, v) => MapEntry(k, Combo.fromJson(v as Map<String, dynamic>)));
  return _cache!;
}

Combo getCombo({required String dayGan, required String mbti}) {
  return loadCombos()['${dayGan}_$mbti']!;
}
