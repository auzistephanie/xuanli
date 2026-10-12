/// 八字日主 × MBTI 組合稀有度估算（純 Dart、deterministic、零網絡）。
///
/// 估算方法：
/// - 日主：日柱天干按 60 甲子逐日循環，十干各佔 1/10。
/// - MBTI：Myers-Briggs 基金會公佈嘅人口比例估算（美國樣本）。
/// 稀有度 = 10% × MBTI 比例。數據唔係香港本地樣本，UI 一律標「估算」。
library;

const _heavenlyStems = ['甲', '乙', '丙', '丁', '戊', '己', '庚', '辛', '壬', '癸'];

/// 每型佔人口百分比（Myers-Briggs Foundation estimates）。原始數字因四捨五入
/// 合共 100.3，計稀有度時會歸一化，唔改原始數據。
const mbtiPopulationShare = <String, double>{
  'ISTJ': 11.6,
  'ISFJ': 13.8,
  'INFJ': 1.5,
  'INTJ': 2.1,
  'ISTP': 5.4,
  'ISFP': 8.8,
  'INFP': 4.4,
  'INTP': 3.3,
  'ESTP': 4.3,
  'ESFP': 8.5,
  'ENFP': 8.1,
  'ENTP': 3.2,
  'ESTJ': 8.7,
  'ESFJ': 12.3,
  'ENFJ': 2.5,
  'ENTJ': 1.8,
};

/// UI 用嘅來源細字。
const rarityFootnote = '估算：日主各佔十分一 × MBTI 人口比例（Myers-Briggs 基金會美國樣本）';

class ComboRarity {
  /// 佔人口百分比，例如 0.88 代表 0.88%。
  final double percent;

  const ComboRarity(this.percent);

  /// 約每幾多人有一個。
  int get oneIn => (100 / percent).round();

  String get percentLabel => '${percent.toStringAsFixed(2)}%';
}

final _mbtiTotal = mbtiPopulationShare.values.fold<double>(0, (a, b) => a + b);

ComboRarity comboRarity({required String dayGan, required String mbti}) {
  if (!_heavenlyStems.contains(dayGan)) {
    throw ArgumentError.value(dayGan, 'dayGan', '唔係天干');
  }
  final share = mbtiPopulationShare[mbti];
  if (share == null) {
    throw ArgumentError.value(mbti, 'mbti', '唔係 16 型之一');
  }
  return ComboRarity(share / _mbtiTotal * 100 / _heavenlyStems.length);
}
