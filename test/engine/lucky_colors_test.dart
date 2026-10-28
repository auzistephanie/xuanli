import 'package:flutter_test/flutter_test.dart';
import 'package:xuanli/engine/lucky_colors.dart';
import 'package:xuanli/models/profile.dart';

Profile profileWithElements(List<String> favorable) => Profile(
  id: 'test',
  name: 'Test',
  birthDate: DateTime(2000, 1, 1),
  birthHour: null,
  birthPlace: '香港',
  mbti: 'ESTJ',
  pillars: ['庚辰', '戊子', '甲子'],
  wuxing: {},
  favorable: favorable,
  unfavorable: [],
  dayMaster: '甲木',
  ziweiStar: '',
  zodiac: '龍',
);

void main() {
  test('stable traditional colors follow favorable element order', () {
    expect(luckyColorsForProfile(profileWithElements(['火', '水'])),
        ['紅色', '橙色', '黑色', '深藍色']);
  });
  test('unknown elements are safely skipped', () {
    expect(luckyColorsForProfile(profileWithElements(['unknown'])), isEmpty);
  });
  test('daily stem matching changes color priority', () {
    final profile = profileWithElements(['火', '水']);
    expect(luckyColorsForDay(profile: profile, ganzhiDay: '壬子'),
        ['黑色', '深藍色', '紅色', '橙色']);
    expect(luckyColorsForDay(profile: profile, ganzhiDay: '丙午'),
        ['紅色', '橙色', '黑色', '深藍色']);
  });
  test('non-matching day falls back to profile priority', () {
    expect(luckyColorsForDay(profile: profileWithElements(['火', '水']), ganzhiDay: '甲寅'),
        ['紅色', '橙色', '黑色', '深藍色']);
  });
  test('invalid ganzhi is rejected', () {
    expect(() => luckyColorsForDay(profile: profileWithElements(['火']), ganzhiDay: 'xx'),
        throwsArgumentError);
  });
  test('duplicate elements do not duplicate colors', () {
    expect(luckyColorsForProfile(profileWithElements(['木', '木'])),
        ['綠色', '青色']);
  });
}
