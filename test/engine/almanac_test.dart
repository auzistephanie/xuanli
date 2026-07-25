import 'package:test/test.dart';
import 'package:xuanli/engine/almanac.dart';

void main() {
  group('AlmanacDay golden fixtures (2026-07)', () {
    final fixtures = [
      _Fixture(2026, 7, 11, lunarLabel: '五月廿七', ganzhiDay: '丙戌', zhiXing: '平', chong: '沖龍煞北'),
      _Fixture(2026, 7, 12, lunarLabel: '五月廿八', ganzhiDay: '丁亥', zhiXing: '定', chong: '沖蛇煞西'),
      _Fixture(2026, 7, 13, lunarLabel: '五月廿九', ganzhiDay: '戊子', zhiXing: '執', chong: '沖馬煞南'),
      _Fixture(2026, 7, 14, lunarLabel: '六月初一', ganzhiDay: '己丑', zhiXing: '破', chong: '沖羊煞東'),
      _Fixture(2026, 7, 15, lunarLabel: '六月初二', ganzhiDay: '庚寅', zhiXing: '危', chong: '沖猴煞北'),
      _Fixture(2026, 7, 16, lunarLabel: '六月初三', ganzhiDay: '辛卯', zhiXing: '成', chong: '沖雞煞西'),
      _Fixture(2026, 7, 17, lunarLabel: '六月初四', ganzhiDay: '壬辰', zhiXing: '收', chong: '沖狗煞南'),
    ];

    for (final f in fixtures) {
      test('${f.year}-${f.month}-${f.day}', () {
        final day = AlmanacDay.forDate(DateTime(f.year, f.month, f.day));
        expect(day.lunarLabel, f.lunarLabel, reason: 'lunarLabel');
        expect(day.ganzhiDay, f.ganzhiDay, reason: 'ganzhiDay');
        expect(day.zhiXing, f.zhiXing, reason: 'zhiXing');
        expect(day.chong, f.chong, reason: 'chong');
      });
    }

    test('月界：2026-07-14 係六月初一', () {
      final day = AlmanacDay.forDate(DateTime(2026, 7, 14));
      expect(day.lunarLabel, '六月初一');
    });
  });

  group('宜/忌繁體化', () {
    test('2026-07-11 宜含「祭祀」「餘事勿取」，忌「諸事不宜」', () {
      final day = AlmanacDay.forDate(DateTime(2026, 7, 11));
      expect(day.yi, contains('祭祀'));
      expect(day.yi, contains('餘事勿取'));
      expect(day.ji, contains('諸事不宜'));
      // 冇簡體字漏網
      for (final item in [...day.yi, ...day.ji]) {
        expect(item.contains('诸'), isFalse, reason: '$item 唔應該有簡體字');
        expect(item.contains('余'), isFalse, reason: '$item 唔應該有簡體字');
      }
    });

    test('2026-07-12 宜含「入宅」，忌含「理髮」（唔係簡體「理发」）', () {
      final day = AlmanacDay.forDate(DateTime(2026, 7, 12));
      expect(day.yi, contains('入宅'));
      expect(day.ji, contains('理髮'));
    });
  });

  group('jiShenCount / xiongShaCount', () {
    test('2026-07-15（`lunar` package 原始 getDayJiShen/getDayXiongSha 回傳 [\'无\']）jiShenCount = 0, xiongShaCount = 0', () {
      final day = AlmanacDay.forDate(DateTime(2026, 7, 15));
      expect(day.jiShenCount, 0, reason: '「无」係 placeholder，唔應該計做 1');
      expect(day.xiongShaCount, 0, reason: '「无」係 placeholder，唔應該計做 1');
    });

    test('2026-07-11（`lunar` package 有真實吉神/凶煞資料）jiShenCount / xiongShaCount > 0', () {
      final day = AlmanacDay.forDate(DateTime(2026, 7, 11));
      expect(day.jiShenCount, 2, reason: '原始 getDayJiShen() = [要安, 青龙]');
      expect(day.xiongShaCount, 6, reason: '原始 getDayXiongSha() 有 6 項');
    });
  });

  group('dayGan / dayZhi', () {
    test('2026-07-11（ganzhiDay = 丙戌）dayGan = 丙, dayZhi = 戌', () {
      final day = AlmanacDay.forDate(DateTime(2026, 7, 11));
      expect(day.dayGan, '丙');
      expect(day.dayZhi, '戌');
    });
  });

  group('isJiSevere / isYiVague', () {
    test('2026-07-11（忌：諸事不宜）isJiSevere = true', () {
      final day = AlmanacDay.forDate(DateTime(2026, 7, 11));
      expect(day.isJiSevere, isTrue);
    });
    test('2026-07-12（忌唔係諸事不宜）isJiSevere = false', () {
      final day = AlmanacDay.forDate(DateTime(2026, 7, 12));
      expect(day.isJiSevere, isFalse);
    });
    test('2026-07-14（宜：餘事勿取）isYiVague = true', () {
      final day = AlmanacDay.forDate(DateTime(2026, 7, 14));
      expect(day.isYiVague, isTrue);
    });
    test('2026-07-12（宜有具體項目）isYiVague = false', () {
      final day = AlmanacDay.forDate(DateTime(2026, 7, 12));
      expect(day.isYiVague, isFalse);
    });
  });
}

class _Fixture {
  final int year, month, day;
  final String lunarLabel, ganzhiDay, zhiXing, chong;
  _Fixture(this.year, this.month, this.day,
      {required this.lunarLabel, required this.ganzhiDay, required this.zhiXing, required this.chong});
}
