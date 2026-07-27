import 'package:test/test.dart';
import 'package:xuanli/engine/profile_builder.dart';

void main() {
  group('buildProfile', () {
    test('阿玄（1999-09-20 09:30 香港 ISFP）— spec §11 golden fixture', () {
      final profile = buildProfile(
        id: 'p1',
        name: '阿玄',
        birthDate: DateTime(1999, 9, 20),
        birthHour: 9,
        birthMinute: 30,
        birthPlace: '香港',
        mbti: 'ISFP',
      );

      expect(profile.pillars, ['己卯', '癸酉', '乙亥', '辛巳']);
      expect(profile.dayMaster, '乙木');
      expect(profile.zodiac, '兔');
      expect(profile.favorable, ['水', '木']);
      expect(profile.unfavorable, ['金', '土']);
      expect(profile.ziweiStar, '太陰');
      expect(profile.completeness, 100);
      expect(profile.name, '阿玄');
      expect(profile.mbti, 'ISFP');
      expect(profile.birthPlace, '香港');
    });

    test('冇時辰（降級模式）：三柱 + 完整度 80%', () {
      final profile = buildProfile(
        id: 'p2',
        name: '無時辰用戶',
        birthDate: DateTime(1999, 9, 20),
        birthHour: null,
        birthPlace: '香港',
        mbti: 'ISFP',
      );

      expect(profile.pillars.length, 3);
      expect(profile.completeness, 80);
      expect(profile.ziweiStar, isNotEmpty);
      expect(profile.zodiac, isNotEmpty);
    });
  });
}
