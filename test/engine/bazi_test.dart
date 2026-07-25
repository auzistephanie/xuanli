import 'package:test/test.dart';
import 'package:xuanli/engine/bazi.dart';

void main() {
  group('子時界線（晚子時歸翌日，sect 1）', () {
    test('2026-07-11 23:30 出生 → 日柱丁亥（唔係丙戌）', () {
      final result = computeBazi(
        birthDate: DateTime(2026, 7, 11),
        birthHour: 23,
        birthMinute: 30,
      );
      expect(result.pillars[2], '丁亥', reason: '晚子時（23:00-23:59）日柱歸翌日');
    });
  });

  group('阿玄 golden fixture（1999-09-20 09:30 香港, ISFP）', () {
    late BaziResult result;
    setUp(() {
      result = computeBazi(
        birthDate: DateTime(1999, 9, 20),
        birthHour: 9,
        birthMinute: 30,
      );
    });

    test('四柱 = 己卯 癸酉 乙亥 辛巳', () {
      expect(result.pillars, ['己卯', '癸酉', '乙亥', '辛巳']);
    });

    test('日主 = 乙木', () {
      expect(result.dayMaster, '乙木');
    });

    test('五行分佈 木2 火1 土1 金3 水2（權重制，未歸一）', () {
      expect(result.wuxingWeighted, {'木': 2, '火': 1, '土': 1, '金': 3, '水': 2});
    });

    test('五行百分比總和 = 100', () {
      final sum = result.wuxing.values.fold<int>(0, (a, b) => a + b);
      expect(sum, 100);
    });

    test('同黨 44% < 45% → 身弱', () {
      expect(result.isBodyStrong, isFalse);
    });

    test('身弱 → 喜水木、忌金土', () {
      expect(result.favorable.toSet(), {'水', '木'});
      expect(result.unfavorable.toSet(), {'金', '土'});
    });
  });
}
