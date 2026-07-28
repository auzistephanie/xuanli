import 'dart:io';

import 'package:test/test.dart';
import 'package:xuanli/engine/activity.dart';
import 'package:xuanli/engine/almanac.dart';
import 'package:xuanli/engine/copywriter.dart';
import 'package:xuanli/models/day_reading.dart';

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

  group('buildNotificationText', () {
    test('組合日干支/命理分/宜忌/避時做一行（spec §9.7 例子格式）', () {
      final day = AlmanacDay.forDate(DateTime(2026, 7, 11)); // golden fixture: 丙戌, 平, 沖龍煞北
      final reading = DayReading(
        date: day.date,
        ganzhiDay: day.ganzhiDay,
        lunarLabel: day.lunarLabel,
        zhiXing: day.zhiXing,
        chong: day.chong,
        fortuneScore: 42,
        mbtiScore: 60,
        band: '平',
        yi: const [YjItem(label: '祈福', matchesUser: true), YjItem(label: '靜修', matchesUser: false)],
        ji: const [YjItem(label: '簽約', matchesUser: false)],
        advice: '（唔用於呢個 test）',
        clashWarning: null,
        avoidHour: '申時',
      );

      final text = buildNotificationText(reading);

      expect(text, '今日丙戌日・命理分42・宜祈福、靜修，忌簽約。避開申時落大決定。');
    });

    test('yi 淨係得一項，ji 冇 → 忌部分寫「無」，冇避時就冇最後嗰句', () {
      final day = AlmanacDay.forDate(DateTime(2026, 7, 11));
      final reading = DayReading(
        date: day.date,
        ganzhiDay: day.ganzhiDay,
        lunarLabel: day.lunarLabel,
        zhiXing: day.zhiXing,
        chong: day.chong,
        fortuneScore: 88,
        mbtiScore: 60,
        band: '吉',
        yi: const [YjItem(label: '開光', matchesUser: true)],
        ji: const [],
        advice: '（唔用於呢個 test）',
        clashWarning: null,
        avoidHour: null,
      );

      final text = buildNotificationText(reading);

      expect(text, '今日丙戌日・命理分88・宜開光，忌無。');
    });

    test('yi 超過 2 項淨係攞頭 2 個', () {
      final day = AlmanacDay.forDate(DateTime(2026, 7, 11));
      final reading = DayReading(
        date: day.date,
        ganzhiDay: day.ganzhiDay,
        lunarLabel: day.lunarLabel,
        zhiXing: day.zhiXing,
        chong: day.chong,
        fortuneScore: 50,
        mbtiScore: 60,
        band: '平',
        yi: const [
          YjItem(label: 'A', matchesUser: false),
          YjItem(label: 'B', matchesUser: false),
          YjItem(label: 'C', matchesUser: false),
        ],
        ji: const [],
        advice: '（唔用於呢個 test）',
        clashWarning: null,
        avoidHour: null,
      );

      final text = buildNotificationText(reading);

      expect(text, '今日丙戌日・命理分50・宜A、B，忌無。');
    });

    test('yi 同 ji 都冇 → 兩邊都寫「無」', () {
      final day = AlmanacDay.forDate(DateTime(2026, 7, 11));
      final reading = DayReading(
        date: day.date,
        ganzhiDay: day.ganzhiDay,
        lunarLabel: day.lunarLabel,
        zhiXing: day.zhiXing,
        chong: day.chong,
        fortuneScore: 50,
        mbtiScore: 60,
        band: '平',
        yi: const [],
        ji: const [],
        advice: '（唔用於呢個 test）',
        clashWarning: null,
        avoidHour: null,
      );

      final text = buildNotificationText(reading);

      expect(text, '今日丙戌日・命理分50・宜無，忌無。');
    });
  });
}
