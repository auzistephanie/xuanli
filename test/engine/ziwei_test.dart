import 'package:test/test.dart';
import 'package:xuanli/engine/ziwei.dart';

void main() {
  group('簡化紫微主星（日支對照，全模式同降級模式共用）', () {
    test('阿玄（日支亥）→ 太陰', () {
      expect(ziweiStarForDayZhi('亥'), '太陰');
    });
    test('十二地支都有對應主星（冇 null case）', () {
      const allZhi = ['子', '丑', '寅', '卯', '辰', '巳', '午', '未', '申', '酉', '戌', '亥'];
      for (final zhi in allZhi) {
        expect(ziweiStarForDayZhi(zhi), isNotNull);
        expect(ziweiStarForDayZhi(zhi), isNotEmpty);
      }
    });
    test('deterministic：同一個地支永遠攞返同一個主星', () {
      expect(ziweiStarForDayZhi('子'), ziweiStarForDayZhi('子'));
    });
  });
}
