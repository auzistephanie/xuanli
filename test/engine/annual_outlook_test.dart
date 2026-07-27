import 'package:test/test.dart';
import 'package:xuanli/engine/annual_outlook.dart';

void main() {
  group('computeAnnualOutlook', () {
    test('2026 年（丙午）對肖兔用戶（年支卯）：唔沖太歲', () {
      final outlook = computeAnnualOutlook(
        date: DateTime(2026, 7, 11),
        userYearZhi: '卯',
      );

      expect(outlook.yearGanZhi, '丙午');
      expect(outlook.isZodiacClash, isFalse);
      expect(outlook.summary, contains('丙午流年'));
      expect(outlook.summary, contains('平順'));
    });

    test('2026 年（丙午）對肖鼠用戶（年支子）：沖太歲（子午相沖）', () {
      final outlook = computeAnnualOutlook(
        date: DateTime(2026, 7, 11),
        userYearZhi: '子',
      );

      expect(outlook.yearGanZhi, '丙午');
      expect(outlook.isZodiacClash, isTrue);
      expect(outlook.summary, contains('沖太歲'));
    });

    test('yearGanZhi 一定係天干+地支兩個字', () {
      final outlook = computeAnnualOutlook(
        date: DateTime(2025, 1, 1),
        userYearZhi: '卯',
      );
      expect(outlook.yearGanZhi.length, 2);
    });
  });
}
