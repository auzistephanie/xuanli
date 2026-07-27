/// 用戶命理檔案：八字/五行/紫微/MBTI 個人化基礎數據（spec §5）。
class Profile {
  final String id;
  final String name;
  final DateTime birthDate;
  final int? birthHour; // null = 唔知時辰
  final String birthPlace;
  final String mbti;
  final List<String> pillars;
  final Map<String, int> wuxing;
  final List<String> favorable;
  final List<String> unfavorable;
  final String dayMaster;
  final String ziweiStar;
  final String zodiac;

  Profile({
    required this.id,
    required this.name,
    required this.birthDate,
    required this.birthHour,
    required this.birthPlace,
    required this.mbti,
    required this.pillars,
    required this.wuxing,
    required this.favorable,
    required this.unfavorable,
    required this.dayMaster,
    required this.ziweiStar,
    required this.zodiac,
  });

  /// 檔案完整度：有時辰 = 100%，冇時辰（三柱降級模式）= 80%。
  int get completeness => birthHour == null ? 80 : 100;

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'birthDate': birthDate.toIso8601String(),
        'birthHour': birthHour,
        'birthPlace': birthPlace,
        'mbti': mbti,
        'pillars': pillars,
        'wuxing': wuxing,
        'favorable': favorable,
        'unfavorable': unfavorable,
        'dayMaster': dayMaster,
        'ziweiStar': ziweiStar,
        'zodiac': zodiac,
      };

  factory Profile.fromJson(Map<String, dynamic> json) => Profile(
        id: json['id'] as String,
        name: json['name'] as String,
        birthDate: DateTime.parse(json['birthDate'] as String),
        birthHour: json['birthHour'] as int?,
        birthPlace: json['birthPlace'] as String,
        mbti: json['mbti'] as String,
        pillars: List<String>.from(json['pillars'] as List),
        wuxing: Map<String, int>.from(json['wuxing'] as Map),
        favorable: List<String>.from(json['favorable'] as List),
        unfavorable: List<String>.from(json['unfavorable'] as List),
        dayMaster: json['dayMaster'] as String,
        ziweiStar: json['ziweiStar'] as String,
        zodiac: json['zodiac'] as String,
      );
}
