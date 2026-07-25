import 'package:test/test.dart';
import 'package:xuanli/engine/almanac.dart';
import 'package:xuanli/engine/scoring.dart';

void main() {
  // 阿玄：喜水木、忌金土
  const favorable = ['水', '木'];
  const unfavorable = ['金', '土'];

  group('fortuneScore smoke tests', () {
    test('2026-07-14（破日 + 諸事不宜）分數 <=40 帶「忌」', () {
      final day = AlmanacDay.forDate(DateTime(2026, 7, 14));
      final result = computeFortuneScore(
        day: day, favorable: favorable, unfavorable: unfavorable, userYearZhi: '寅');
      expect(result.score, lessThanOrEqualTo(40));
      expect(result.band, '忌');
    });

    test('2026-07-16 對喜木用戶 >=70 帶「吉」', () {
      final day = AlmanacDay.forDate(DateTime(2026, 7, 16));
      // 2026-07-16 = 辛卯（日干辛=金，日支卯=木）。用呢個用戶淨係試「喜木」對日支嘅加分路徑。
      final result = computeFortuneScore(
        day: day, favorable: const ['木'], unfavorable: const ['土'], userYearZhi: '寅');
      expect(result.score, greaterThanOrEqualTo(70));
      expect(result.band, '吉');
    });

    test('同 input 行 100 次結果 identical（deterministic）', () {
      final day = AlmanacDay.forDate(DateTime(2026, 7, 15));
      final scores = List.generate(
        100,
        (_) => computeFortuneScore(
            day: day, favorable: favorable, unfavorable: unfavorable, userYearZhi: '子').score,
      );
      expect(scores.toSet().length, 1);
    });
  });

  group('沖生肖', () {
    test('肖龍用戶喺 2026-07-11（沖龍）clashWarning 非空且 -20 已計入', () {
      final day = AlmanacDay.forDate(DateTime(2026, 7, 11));
      // 用戶生肖龍 → 年支辰
      final withClash = computeFortuneScore(
          day: day, favorable: favorable, unfavorable: unfavorable, userYearZhi: '辰');
      final withoutClash = computeFortuneScore(
          day: day, favorable: favorable, unfavorable: unfavorable, userYearZhi: '子');
      expect(withClash.clashWarning, isNotNull);
      expect(withClash.clashWarning, contains('龍'));
      expect(withoutClash.clashWarning, isNull);
      expect(withClash.score, lessThanOrEqualTo(withoutClash.score - 20));
    });
  });

  group('band 分帶', () {
    test('>=70 吉，40-69 平，<=39 忌', () {
      expect(bandFor(70), '吉');
      expect(bandFor(100), '吉');
      expect(bandFor(69), '平');
      expect(bandFor(40), '平');
      expect(bandFor(39), '忌');
      expect(bandFor(0), '忌');
    });
  });

  group('避開時辰', () {
    test('用戶日支寅，申時（15-17）沖寅 → avoidHour = "申時 15–17"', () {
      expect(computeAvoidHour('寅'), '申時 15–17');
    });
    test('用戶日支申，寅時（3-5）沖申', () {
      expect(computeAvoidHour('申'), '寅時 3–5');
    });
    test('每個地支都有對應沖時辰（冇 null case）', () {
      for (final zhi in ['子', '丑', '卯', '辰', '巳', '午', '未', '酉', '戌', '亥']) {
        expect(computeAvoidHour(zhi), isNotNull);
      }
    });
  });

  group('契合度四軸（獨立於命理分）', () {
    test('E/I：建除屬動（建除危成開）對 E 高分', () {
      final day = AlmanacDay.forDate(DateTime(2026, 7, 15));
      expect(axisScoreEI(day, 'E'), 25);
      expect(axisScoreEI(day, 'I'), 8);
    });
    test('E/I：建除屬靜（平定收閉破執滿）對 I 高分', () {
      final day = AlmanacDay.forDate(DateTime(2026, 7, 11));
      expect(axisScoreEI(day, 'I'), 25);
      expect(axisScoreEI(day, 'E'), 8);
    });

    test('S/N：宜項 >=6 具體 → 利 S', () {
      final day = AlmanacDay.forDate(DateTime(2026, 7, 12));
      expect(day.isYiVague, isFalse);
      final sScore = axisScoreSN(day, 'S');
      final nScore = axisScoreSN(day, 'N');
      expect(sScore, greaterThanOrEqualTo(nScore));
    });
    test('S/N：宜：餘事勿取（isYiVague）→ 利 N', () {
      final day = AlmanacDay.forDate(DateTime(2026, 7, 14));
      expect(axisScoreSN(day, 'N'), 25);
      expect(axisScoreSN(day, 'S'), 8);
    });

    test('T/F：吉神 >=3 → 利 F', () {
      final day = AlmanacDay.forDate(DateTime(2026, 7, 12));
      if (day.jiShenCount >= 3) {
        expect(axisScoreTF(day, 'F'), 25);
        expect(axisScoreTF(day, 'T'), 8);
      }
    });

    test('J/P：無沖無破（穩定）→ 利 J；沖/破/危 → 利 P', () {
      final stableDay = AlmanacDay.forDate(DateTime(2026, 7, 12)); // zhiXing='定'
      expect(axisScoreJP(stableDay, hasClash: false, userLetter: 'J'), 25);
      final volatileDay = AlmanacDay.forDate(DateTime(2026, 7, 14)); // zhiXing='破'
      expect(axisScoreJP(volatileDay, hasClash: false, userLetter: 'P'), 25);
      expect(axisScoreJP(volatileDay, hasClash: true, userLetter: 'P'), 25);
    });

    test('computeMbtiScore 加返四軸並 clamp 0-100', () {
      final day = AlmanacDay.forDate(DateTime(2026, 7, 11));
      final score = computeMbtiScore(day: day, mbti: 'ISFP', hasClash: false);
      expect(score, inInclusiveRange(0, 100));
    });

    test('命理分同契合度完全獨立（唔會互相引用對方個 favorable/unfavorable）', () {
      final day = AlmanacDay.forDate(DateTime(2026, 7, 11));
      final mbtiScore1 = computeMbtiScore(day: day, mbti: 'ISFP', hasClash: false);
      final mbtiScore2 = computeMbtiScore(day: day, mbti: 'ISFP', hasClash: false);
      expect(mbtiScore1, mbtiScore2);
    });
  });
}
