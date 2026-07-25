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

  group('宜忌個人化排序', () {
    test('personalizedYi 將 matchesUser 嘅項目排前面，並標記 matchesUser', () {
      final day = AlmanacDay.forDate(DateTime(2026, 7, 12));
      final items = day.personalizedYi(favorable: const ['土']);
      final matched = items.where((i) => i.matchesUser).toList();
      expect(matched, isNotEmpty);
      expect(items.indexOf(matched.first), lessThan(items.length - matched.length + 1));
    });

    test('personalizedJi 同樣邏輯', () {
      final day = AlmanacDay.forDate(DateTime(2026, 7, 12));
      final items = day.personalizedJi(favorable: const ['木']);
      expect(items.any((i) => i.label == '理髮' && i.matchesUser), isTrue);
    });

    test('宜取頭 3-5、忌取頭 2-4', () {
      final day = AlmanacDay.forDate(DateTime(2026, 7, 12));
      final yi = day.personalizedYi(favorable: const []);
      final ji = day.personalizedJi(favorable: const []);
      expect(yi.length, inInclusiveRange(1, 5));
      expect(ji.length, inInclusiveRange(1, 4));
    });
  });

  _regressionSweep();
}

class _Fixture {
  final int year, month, day;
  final String lunarLabel, ganzhiDay, zhiXing, chong;
  _Fixture(this.year, this.month, this.day,
      {required this.lunarLabel, required this.ganzhiDay, required this.zhiXing, required this.chong});
}

/// 常見簡體字（跟 [_simplifiedToTraditional] 本身無關，獨立列出）——用嚟
/// regression-guard `traditionalize()` 對表隨時間擴充時冇漏字。呢個唔係
/// 窮舉全部簡化字表，淨係揀：(a) 呢次 bug 揾到嘅字、(b) 對表入面本身已經
/// 有嘅字、(c) 幾個常見到爆嘅簡體字（雖然未必會喺通勝詞彙出現，但作為
/// 額外保險）。**刻意剔除**：灶／床／雇——教育部《國語辭典》定義呢幾個字
/// 本身就係正字（唔係簡體），唔應該被繁體化。
const _knownSimplifiedChars = <String>{
  // 呢次 bug fix 新增（2026-07-25 review）
  '无', '机', '桥', '渔', '猎', '猪', '盖', '竖', '经', '绘', '络', '艺',
  '蚁', '补', '讼', '词', '车', '针', '问', '饰', '习', '厕', '墙', '帐',
  '庙', '归', '扫', '断', '纳', '佣', '涂', '宁', '筑',
  // 對表原有 golden-fixture 字
  '发', '马', '龙', '风', '鸡', '开', '闭', '满', '执', '诸', '订',
  '坏', '医', '种', '丧', '坟', '产', '斋', '门', '学', '仓', '货', '财',
  '养', '启', '钻', '谢', '进', '寿', '结', '网', '殓', '东',
  // 額外保險：常見到爆嘅簡體字（未必出現喺通勝詞彙，純粹加強 regression net）
  '国', '会', '这', '来', '为', '时', '对', '现', '实', '业', '专', '关',
  '万', '与', '书', '义', '乐', '争', '亲', '仅', '价', '众',
};

void _assertNoSimplifiedLeak(List<String> items, DateTime date) {
  for (final item in items) {
    for (final ch in item.split('')) {
      expect(
        _knownSimplifiedChars.contains(ch),
        isFalse,
        reason: '$date：「$item」入面嘅「$ch」係簡體字，未經 traditionalize() 對表轉繁體',
      );
    }
  }
}

void _regressionSweep() {
  group('簡體字繁體化 regression sweep（2024-2028，脫離 7 日 fixture 範圍）', () {
    test('yi/ji/chong/zhiXing 全部日子都冇已知簡體字漏網', () {
      var d = DateTime(2024, 1, 1);
      final end = DateTime(2028, 12, 31);
      var checked = 0;
      while (!d.isAfter(end)) {
        final day = AlmanacDay.forDate(d);
        _assertNoSimplifiedLeak(day.yi, d);
        _assertNoSimplifiedLeak(day.ji, d);
        _assertNoSimplifiedLeak([day.chong], d);
        _assertNoSimplifiedLeak([day.zhiXing], d);
        checked++;
        d = d.add(const Duration(days: 1));
      }
      expect(checked, greaterThan(1800), reason: '確保真係掃咗成 5 年，唔係得幾日');
    });
  });
}
