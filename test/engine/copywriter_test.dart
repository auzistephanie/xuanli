import 'dart:io';

import 'package:test/test.dart';
import 'package:xuanli/engine/activity.dart';
import 'package:xuanli/engine/almanac.dart';
import 'package:xuanli/engine/copywriter.dart';

void main() {
  setUpAll(() {
    initMbtiTones(File('lib/data/mbti_tones.json').readAsStringSync());
    initActivities(File('lib/data/activities.json').readAsStringSync());
  });

  group('今日貼身建議模板引擎', () {
    test('拼接命理段 + MBTI 段（有紫微段可省略）', () {
      final day = AlmanacDay.forDate(DateTime(2026, 7, 11));
      final advice = buildAdvice(
        day: day,
        favorable: const ['水', '木'],
        unfavorable: const ['金', '土'],
        mbti: 'ISFP',
        ziweiStar: null,
        avoidHour: '申時 15–17',
      );
      expect(advice, isNotEmpty);
      expect(advice, contains('避開申時'));
    });

    test('template 輪換用 dayOfYear % length，deterministic', () {
      final day = AlmanacDay.forDate(DateTime(2026, 7, 11));
      final advice1 = buildAdvice(
        day: day, favorable: const ['水'], unfavorable: const ['金'],
        mbti: 'ISFP', ziweiStar: null, avoidHour: null,
      );
      final advice2 = buildAdvice(
        day: day, favorable: const ['水'], unfavorable: const ['金'],
        mbti: 'ISFP', ziweiStar: null, avoidHour: null,
      );
      expect(advice1, advice2);
    });

    test('唔同 dayOfYear 揀唔同 MBTI 語氣句（起碼喺 2 型入面有變化）', () {
      final day1 = AlmanacDay.forDate(DateTime(2026, 1, 1));
      final day2 = AlmanacDay.forDate(DateTime(2026, 1, 2));
      final advice1 = buildAdvice(
        day: day1, favorable: const [], unfavorable: const [],
        mbti: 'ISFP', ziweiStar: null, avoidHour: null,
      );
      final advice2 = buildAdvice(
        day: day2, favorable: const [], unfavorable: const [],
        mbti: 'ISFP', ziweiStar: null, avoidHour: null,
      );
      expect(advice1, isNotEmpty);
      expect(advice2, isNotEmpty);
    });

    test('冇 avoidHour 就唔會出現「避開」字眼', () {
      final day = AlmanacDay.forDate(DateTime(2026, 7, 12));
      final advice = buildAdvice(
        day: day, favorable: const [], unfavorable: const [],
        mbti: 'ISFJ', ziweiStar: '天機', avoidHour: null,
      );
      expect(advice.contains('避開'), isFalse);
    });
  });

  group('buildActivityReason', () {
    test('三個信號全中：2026-07-13（戊子執日）剪髮 + 喜木', () {
      final day = AlmanacDay.forDate(DateTime(2026, 7, 13));
      final activity = loadActivities().firstWhere((a) => a.name == '剪髮');

      final reason = buildActivityReason(
        activity: activity,
        day: day,
        favorable: const ['木'],
      );

      expect(reason, startsWith('🔮'));
      expect(reason, contains('理髮'));
      expect(reason, contains('執'));
      expect(reason, contains('木'));
    });

    test('全部唔中：2026-07-11（丙戌平日）剪髮 + 喜金 -> 用返 fallback 句', () {
      final day = AlmanacDay.forDate(DateTime(2026, 7, 11));
      final activity = loadActivities().firstWhere((a) => a.name == '剪髮');

      final reason = buildActivityReason(
        activity: activity,
        day: day,
        favorable: const ['金'],
      );

      expect(reason, startsWith('🔮'));
      expect(reason, contains('剪髮'));
    });
  });
}
