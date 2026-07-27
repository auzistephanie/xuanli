import 'package:test/test.dart';
import 'package:xuanli/models/profile.dart';
import 'package:xuanli/models/day_reading.dart';

void main() {
  test('Profile toJson/fromJson round-trip', () {
    final profile = Profile(
      id: 'p1',
      name: '阿玄',
      birthDate: DateTime(1999, 9, 20),
      birthHour: 9,
      birthPlace: '香港',
      mbti: 'ISFP',
      pillars: ['己卯', '癸酉', '乙亥', '辛巳'],
      wuxing: {'木': 22, '火': 11, '土': 11, '金': 33, '水': 23},
      favorable: ['水', '木'],
      unfavorable: ['金', '土'],
      dayMaster: '乙木',
      ziweiStar: '太陰',
      zodiac: '兔',
    );
    final json = profile.toJson();
    final restored = Profile.fromJson(json);
    expect(restored.name, '阿玄');
    expect(restored.pillars, profile.pillars);
    expect(restored.birthDate, profile.birthDate);
    expect(restored.birthHour, 9);
  });

  test('Profile birthHour null（缺時辰）round-trip', () {
    final profile = Profile(
      id: 'p1', name: '我', birthDate: DateTime(1999, 9, 20), birthHour: null,
      birthPlace: '香港', mbti: 'ISFP', pillars: ['己卯', '癸酉', '乙亥'],
      wuxing: {'木': 20, '火': 20, '土': 20, '金': 20, '水': 20},
      favorable: ['水', '木'], unfavorable: ['金', '土'], dayMaster: '乙木',
      ziweiStar: '太陰', zodiac: '兔',
    );
    expect(Profile.fromJson(profile.toJson()).birthHour, isNull);
  });

  test('YjItem 有 label 同 matchesUser', () {
    const item = YjItem(label: '祭祀', matchesUser: true);
    expect(item.label, '祭祀');
    expect(item.matchesUser, isTrue);
  });

  test('DayReading 建構', () {
    final reading = DayReading(
      date: DateTime(2026, 7, 11),
      ganzhiDay: '丙戌',
      lunarLabel: '五月廿七',
      zhiXing: '平',
      chong: '沖龍煞北',
      fortuneScore: 42,
      mbtiScore: 60,
      band: '平',
      yi: const [YjItem(label: '祭祀', matchesUser: false)],
      ji: const [YjItem(label: '諸事不宜', matchesUser: false)],
      advice: '今日宜靜不宜動。',
      clashWarning: null,
      avoidHour: null,
    );
    expect(reading.band, '平');
    expect(reading.yi.first.label, '祭祀');
  });
}
