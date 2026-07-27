// ignore_for_file: avoid_print
import 'package:xuanli/engine/bazi.dart';
import 'package:xuanli/engine/day_reading_engine.dart';
import 'package:xuanli/engine/ziwei.dart';
import 'package:xuanli/models/profile.dart';

const _zhiToZodiac = {
  '子': '鼠', '丑': '牛', '寅': '虎', '卯': '兔', '辰': '龍', '巳': '蛇',
  '午': '馬', '未': '羊', '申': '猴', '酉': '雞', '戌': '狗', '亥': '豬',
};

/// Usage: `dart run tool/demo.dart <YYYY-MM-DD> [HH:MM] <MBTI>`
void main(List<String> args) {
  if (args.length < 2) {
    print('Usage: dart run tool/demo.dart <YYYY-MM-DD> [HH:MM] <MBTI>');
    return;
  }

  final dateParts = args[0].split('-').map(int.parse).toList();
  final birthDate = DateTime(dateParts[0], dateParts[1], dateParts[2]);

  int? birthHour;
  int birthMinute = 0;
  String mbti;
  if (args.length == 3) {
    final timeParts = args[1].split(':').map(int.parse).toList();
    birthHour = timeParts[0];
    birthMinute = timeParts[1];
    mbti = args[2];
  } else {
    mbti = args[1];
  }

  final bazi = computeBazi(birthDate: birthDate, birthHour: birthHour, birthMinute: birthMinute);
  final userYearZhi = bazi.pillars[0].substring(1);
  final userDayZhi = bazi.pillars[2].substring(1);

  final profile = Profile(
    id: 'demo',
    name: '我',
    birthDate: birthDate,
    birthHour: birthHour,
    birthPlace: '香港',
    mbti: mbti,
    pillars: bazi.pillars,
    wuxing: bazi.wuxing,
    favorable: bazi.favorable,
    unfavorable: bazi.unfavorable,
    dayMaster: bazi.dayMaster,
    ziweiStar: ziweiStarForDayZhi(userDayZhi),
    zodiac: _zhiToZodiac[userYearZhi]!,
  );

  final today = DateTime.now();
  final reading = buildDayReading(profile: profile, date: DateTime(today.year, today.month, today.day));

  print('=== 玄曆 Demo ===');
  print('四柱：${bazi.pillars.join(' ')}');
  print('日主：${bazi.dayMaster}　肖：${profile.zodiac}　完整度：${profile.completeness}%');
  print('喜：${bazi.favorable.join('')}　忌：${bazi.unfavorable.join('')}');
  print('---');
  print('${reading.lunarLabel}　${reading.ganzhiDay}　${reading.zhiXing}日　${reading.chong}');
  print('命理分：${reading.fortuneScore}（${reading.band}）　契合度：${reading.mbtiScore}');
  print('宜：${reading.yi.map((e) => e.label).join('、')}');
  print('忌：${reading.ji.map((e) => e.label).join('、')}');
  if (reading.clashWarning != null) print('⚠️ ${reading.clashWarning}');
  print('🔮 ${reading.advice}');
}
