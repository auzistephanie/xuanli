import 'dart:io';

import 'package:test/test.dart';
import 'package:xuanli/models/combo.dart';

String _stemName(String stem) {
  const element = {
    '甲': '木', '乙': '木', '丙': '火', '丁': '火', '戊': '土',
    '己': '土', '庚': '金', '辛': '金', '壬': '水', '癸': '水',
  };
  return '$stem${element[stem]}';
}

void main() {
  setUpAll(() {
    initCombos(File('lib/data/combos.json').readAsStringSync());
  });

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

    test('每個 combo 有宮職、這就是你、分享句，而且唔叫朋友做測驗', () {
      final combos = loadCombos();
      final titles = <String>{};
      for (final entry in combos.entries) {
        final combo = entry.value;
        final parts = entry.key.split('_');
        expect(combo.palaceTitle, isNotEmpty);
        expect(titles.add(combo.palaceTitle), isTrue, reason: combo.palaceTitle);
        expect(combo.name, '${_stemName(parts[0])}命・${combo.palaceTitle}｜${parts[1]}');
        expect(combo.roleLine, startsWith('${combo.palaceTitle}：'));
        expect(combo.thisIsYou, isNotEmpty);
        expect(combo.daily.length, inInclusiveRange(2, 3));
        expect(combo.jobs.length, inInclusiveRange(3, 4));
        expect(
          combo.shareLine,
          startsWith('${_stemName(parts[0])}命・${combo.palaceTitle}｜適合當'),
        );
        expect(combo.shareLine.contains('你呢'), isFalse);
        expect(combos.containsKey(combo.bestMatchKey), isTrue);
        expect(combo.reminder.contains('戊戌'), isFalse);
      }
      expect(combos['甲_INTJ']!.palaceTitle, '軍師');
      expect(combos['乙_ISFP']!.palaceTitle, '御用畫師');
      expect(combos['庚_ESTJ']!.shareLine, '庚金命・大將軍｜適合當專案經理');
    });

    test('getCombo(dayMaster, mbti) 方便查詢', () {
      final combo = getCombo(dayGan: '甲', mbti: 'INTJ');
      expect(combo.name, '甲木命・軍師｜INTJ');
      expect(combo.palaceTitle, '軍師');
    });
  });
}
