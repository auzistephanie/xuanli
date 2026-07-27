// ignore_for_file: avoid_print
import 'dart:io';

import 'package:xuanli/engine/almanac.dart';
import 'package:xuanli/engine/copywriter.dart';
import 'package:xuanli/engine/day_reading_engine.dart';
import 'package:xuanli/engine/profile_builder.dart';

/// Usage: `dart run tool/demo.dart <YYYY-MM-DD> [HH:MM] <MBTI>`
void main(List<String> args) {
  initMbtiTones(File('lib/data/mbti_tones.json').readAsStringSync());
  initActivityCategories(
    File('lib/data/activity_categories.json').readAsStringSync(),
  );

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

  final profile = buildProfile(
    id: 'demo',
    name: '我',
    birthDate: birthDate,
    birthHour: birthHour,
    birthMinute: birthMinute,
    birthPlace: '香港',
    mbti: mbti,
  );

  final today = DateTime.now();
  final reading = buildDayReading(profile: profile, date: DateTime(today.year, today.month, today.day));

  print('=== 玄曆 Demo ===');
  print('四柱：${profile.pillars.join(' ')}');
  print('日主：${profile.dayMaster}　肖：${profile.zodiac}　完整度：${profile.completeness}%');
  print('喜：${profile.favorable.join('')}　忌：${profile.unfavorable.join('')}');
  print('---');
  print('${reading.lunarLabel}　${reading.ganzhiDay}　${reading.zhiXing}日　${reading.chong}');
  print('命理分：${reading.fortuneScore}（${reading.band}）　契合度：${reading.mbtiScore}');
  print('宜：${reading.yi.map((e) => e.label).join('、')}');
  print('忌：${reading.ji.map((e) => e.label).join('、')}');
  if (reading.clashWarning != null) print('⚠️ ${reading.clashWarning}');
  print('🔮 ${reading.advice}');
}
