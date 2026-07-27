import 'package:test/test.dart';
import 'package:xuanli/models/combo.dart';

void main() {
  group('160 組合 loader', () {
    test('全部 160 個 key 齊全（10 日主 × 16 MBTI）', () {
      final combos = loadCombos();
      expect(combos.length, 160);

      const dayMasters = ['甲', '乙', '丙', '丁', '戊', '己', '庚', '辛', '壬', '癸'];
      const mbtiTypes = [
        'INTJ', 'INTP', 'ENTJ', 'ENTP', 'INFJ', 'INFP', 'ENFJ', 'ENFP',
        'ISTJ', 'ISFJ', 'ESTJ', 'ESFJ', 'ISTP', 'ISFP', 'ESTP', 'ESFP',
      ];
      for (final dm in dayMasters) {
        for (final mbti in mbtiTypes) {
          expect(combos.containsKey('${dm}_$mbti'), isTrue, reason: '缺 ${dm}_$mbti');
        }
      }
    });

    test('每個 combo 有齊 name/motto/description/strengths[3]/watchouts[3]/howToWin', () {
      final combos = loadCombos();
      final sample = combos['甲_INTJ']!;
      expect(sample.name, isNotEmpty);
      expect(sample.motto, isNotEmpty);
      expect(sample.description.length, inInclusiveRange(80, 130));
      expect(sample.strengths.length, 3);
      expect(sample.watchouts.length, 3);
      expect(sample.howToWin, isNotEmpty);
    });

    test('getCombo(dayMaster, mbti) 方便查詢', () {
      final combo = getCombo(dayGan: '甲', mbti: 'INTJ');
      expect(combo.name, '雪嶺孤松');
    });
  });
}
