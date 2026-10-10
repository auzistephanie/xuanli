import 'package:test/test.dart';
import 'package:xuanli/engine/rarity.dart';

void main() {
  const gans = ['甲', '乙', '丙', '丁', '戊', '己', '庚', '辛', '壬', '癸'];

  test('MBTI 人口比例 16 型齊全（原始數據四捨五入後約 100%）', () {
    expect(mbtiPopulationShare.length, 16);
    final sum = mbtiPopulationShare.values.fold<double>(0, (a, b) => a + b);
    expect(sum, closeTo(100, 0.5));
  });

  test('160 個組合稀有度加埋 = 100%', () {
    var sum = 0.0;
    for (final gan in gans) {
      for (final mbti in mbtiPopulationShare.keys) {
        sum += comboRarity(dayGan: gan, mbti: mbti).percent;
      }
    }
    expect(sum, closeTo(100, 1e-9));
  });

  test('乙 × ISFP ≈ 0.88%，每 114 人一個', () {
    final r = comboRarity(dayGan: '乙', mbti: 'ISFP');
    expect(r.percent, closeTo(0.877, 0.001));
    expect(r.oneIn, 114);
    expect(r.percentLabel, '0.88%');
  });

  test('INFJ 係最罕有一級：0.15%，每 669 人一個', () {
    final r = comboRarity(dayGan: '甲', mbti: 'INFJ');
    expect(r.percentLabel, '0.15%');
    expect(r.oneIn, 669);
  });

  test('日主唔影響比例（每個天干各佔 1/10）', () {
    for (final gan in gans) {
      expect(comboRarity(dayGan: gan, mbti: 'ISFJ').percentLabel, '1.38%');
    }
  });

  test('無效輸入會 throw', () {
    expect(() => comboRarity(dayGan: '乙', mbti: 'XXXX'), throwsArgumentError);
    expect(() => comboRarity(dayGan: '子', mbti: 'ISFP'), throwsArgumentError);
  });
}
