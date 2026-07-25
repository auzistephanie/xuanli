import 'package:test/test.dart';
import 'package:xuanli/engine/bazi.dart';
import 'package:xuanli/engine/day_reading_engine.dart';
import 'package:xuanli/models/profile.dart';

void main() {
  test('buildDayReading(阿玄, 2026-07-11) 產出完整 DayReading', () {
    final bazi = computeBazi(birthDate: DateTime(1999, 9, 20), birthHour: 9, birthMinute: 30);
    final profile = Profile(
      id: 'p1', name: '阿玄', birthDate: DateTime(1999, 9, 20), birthHour: 9,
      birthPlace: '香港', mbti: 'ISFP',
      pillars: bazi.pillars, wuxing: bazi.wuxing,
      favorable: bazi.favorable, unfavorable: bazi.unfavorable,
      dayMaster: bazi.dayMaster, ziweiStar: '太陰', zodiac: '兔',
    );

    final reading = buildDayReading(profile: profile, date: DateTime(2026, 7, 11));

    expect(reading.ganzhiDay, '丙戌');
    expect(reading.lunarLabel, '五月廿七');
    expect(reading.zhiXing, '平');
    expect(reading.fortuneScore, inInclusiveRange(0, 100));
    expect(reading.mbtiScore, inInclusiveRange(0, 100));
    expect(['吉', '平', '忌'], contains(reading.band));
    expect(reading.advice, isNotEmpty);
    expect(reading.yi, isNotEmpty);
  });

  test('deterministic：同 input 行兩次result一樣', () {
    final bazi = computeBazi(birthDate: DateTime(1999, 9, 20), birthHour: 9, birthMinute: 30);
    final profile = Profile(
      id: 'p1', name: '阿玄', birthDate: DateTime(1999, 9, 20), birthHour: 9,
      birthPlace: '香港', mbti: 'ISFP',
      pillars: bazi.pillars, wuxing: bazi.wuxing,
      favorable: bazi.favorable, unfavorable: bazi.unfavorable,
      dayMaster: bazi.dayMaster, ziweiStar: '太陰', zodiac: '兔',
    );
    final r1 = buildDayReading(profile: profile, date: DateTime(2026, 7, 11));
    final r2 = buildDayReading(profile: profile, date: DateTime(2026, 7, 11));
    expect(r1.fortuneScore, r2.fortuneScore);
    expect(r1.advice, r2.advice);
  });
}
