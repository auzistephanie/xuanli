import 'package:test/test.dart';
import 'package:xuanli/engine/activity.dart';
import 'package:xuanli/engine/almanac.dart';

void main() {
  group('反向擇日', () {
    test('14 個活動全部載入到', () {
      expect(loadActivities().length, 14);
      expect(loadActivities().map((a) => a.name), contains('睇醫生'));
    });

    test('活動出現喺忌關鍵字 → 淘汰', () {
      final day = AlmanacDay.forDate(DateTime(2026, 7, 12));
      final activity = loadActivities().firstWhere((a) => a.name == '剪髮');
      final score = scoreActivityForDay(activity: activity, day: day, favorable: const [], fortuneScore: 50);
      expect(score, isNull, reason: '忌關鍵字命中即淘汰');
    });

    test('安全線：睇醫生永遠有結果，唔會俾淘汰', () {
      for (var d = 11; d <= 17; d++) {
        final day = AlmanacDay.forDate(DateTime(2026, 7, d));
        final activity = loadActivities().firstWhere((a) => a.name == '睇醫生');
        final score = scoreActivityForDay(activity: activity, day: day, favorable: const [], fortuneScore: 50);
        expect(score, isNotNull, reason: '2026-07-$d 睇醫生唔可以俾淘汰');
      }
    });

    test('rankActivities 喺範圍內排序取頭 5，星級 1-5', () {
      final dates = List.generate(7, (i) => DateTime(2026, 7, 11 + i));
      final results = rankActivities(
        activityName: '搬屋',
        dates: dates,
        favorable: const ['土'],
        fortuneScoreOf: (d) => AlmanacDay.forDate(d).zhiXing == '定' ? 80 : 50,
      );
      expect(results.length, lessThanOrEqualTo(5));
      for (final r in results) {
        expect(r.stars, inInclusiveRange(1, 5));
      }
      for (var i = 1; i < results.length; i++) {
        expect(results[i - 1].score, greaterThanOrEqualTo(results[i].score));
      }
    });
  });
}
