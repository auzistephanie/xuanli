import 'package:test/test.dart';
import 'package:xuanli/engine/daily_stick.dart';
import 'package:xuanli/models/day_reading.dart';
import 'package:xuanli/models/profile.dart';

Profile fakeProfile({String id = 'p', List<String>? pillars, String mbti = 'ISFP'}) => Profile(
  id: id,
  name: 'x',
  birthDate: DateTime(1999, 9, 20),
  birthHour: 9,
  birthPlace: '香港',
  mbti: mbti,
  pillars: pillars ?? ['己卯', '癸酉', '乙亥', '辛巳'],
  wuxing: const {'木': 22, '火': 11, '土': 11, '金': 34, '水': 22},
  favorable: const ['水', '木'],
  unfavorable: const ['金', '土'],
  dayMaster: '乙木',
  ziweiStar: '紫微',
  zodiac: '兔',
);

DayReading fakeReading({
  required DateTime date,
  int score = 75,
  List<String> yi = const ['祈福', '祭祀'],
}) => DayReading(
  date: date,
  ganzhiDay: '丙戌',
  lunarLabel: '五月廿七',
  zhiXing: '平',
  chong: '沖龍煞北',
  fortuneScore: score,
  mbtiScore: 60,
  band: score >= 70 ? '吉' : (score <= 40 ? '忌' : '平'),
  yi: [for (final y in yi) YjItem(label: y, matchesUser: false)],
  ji: const [],
  advice: 'x',
  clashWarning: null,
  avoidHour: null,
);

void main() {
  final p = fakeProfile();
  final d = DateTime(2026, 7, 11);

  group('籤級按命理分', () {
    test('邊界：85 / 70 / 55 / 40', () {
      StickLevel at(int score) => drawDailyStick(profile: p, reading: fakeReading(date: d, score: score)).level;
      expect(at(100), StickLevel.supreme);
      expect(at(85), StickLevel.supreme);
      expect(at(84), StickLevel.good);
      expect(at(70), StickLevel.good);
      expect(at(69), StickLevel.middle);
      expect(at(55), StickLevel.middle);
      expect(at(54), StickLevel.small);
      expect(at(40), StickLevel.small);
      expect(at(39), StickLevel.quiet);
      expect(at(0), StickLevel.quiet);
    });

    test('籤級名一律正面／中性，冇「凶」「下下」', () {
      for (final level in StickLevel.values) {
        final name = stickLevelName(level);
        expect(name.endsWith('籤'), isTrue);
        for (final bad in ['凶', '下下', '禍', '厄']) {
          expect(name.contains(bad), isFalse, reason: name);
        }
      }
    });
  });

  group('籤號', () {
    test('1–60，同一人同一日永遠一樣（deterministic，跑 100 次）', () {
      final first = drawDailyStick(profile: p, reading: fakeReading(date: d));
      expect(first.number, inInclusiveRange(1, 60));
      for (var i = 0; i < 100; i++) {
        final r = drawDailyStick(profile: p, reading: fakeReading(date: d));
        expect(r.number, first.number);
        expect(r.verse, first.verse);
        expect(r.interpretation, first.interpretation);
      }
    });

    test('唔同日子、唔同人會抽到唔同嘅號（分佈合理）', () {
      final days = <int>{};
      for (var i = 0; i < 60; i++) {
        days.add(drawDailyStick(profile: p, reading: fakeReading(date: d.add(Duration(days: i)))).number);
      }
      expect(days.length, greaterThan(30));

      final people = <int>{};
      for (var i = 0; i < 60; i++) {
        final person = fakeProfile(id: '$i', pillars: ['甲子', '丙寅', '${'甲乙丙丁戊己庚辛壬癸'[i % 10]}${'子丑寅卯辰巳午未申酉戌亥'[i % 12]}', '甲子']);
        people.add(drawDailyStick(profile: person, reading: fakeReading(date: d)).number);
      }
      expect(people.length, greaterThan(20));
    });

    test('numberLabel：第N籤，用中文數字', () {
      expect(stickNumberLabel(1), '第一籤');
      expect(stickNumberLabel(10), '第十籤');
      expect(stickNumberLabel(11), '第十一籤');
      expect(stickNumberLabel(20), '第二十籤');
      expect(stickNumberLabel(37), '第三十七籤');
      expect(stickNumberLabel(60), '第六十籤');
    });
  });

  group('籤詩', () {
    test('每級最少 3 首，每首 4 句、每句 7 字', () {
      for (final level in StickLevel.values) {
        final verses = stickVerses[level]!;
        expect(verses.length, greaterThanOrEqualTo(3), reason: '$level');
        for (final v in verses) {
          expect(v.length, 4, reason: v.join());
          for (final line in v) {
            expect(line.runes.length, 7, reason: line);
          }
        }
      }
    });

    test('籤詩文字冇負面／醫療／投資字眼（安全線）', () {
      const banned = ['凶', '死', '病', '災', '禍', '厄', '破財', '血', '藥', '醫', '股', '買入', '賣出', '投資'];
      for (final verses in stickVerses.values) {
        for (final v in verses) {
          final text = v.join();
          for (final w in banned) {
            expect(text.contains(w), isFalse, reason: '$w in $text');
          }
        }
      }
    });

    test('冇重複嘅籤詩', () {
      final all = [for (final vs in stickVerses.values) for (final v in vs) v.join()];
      expect(all.toSet().length, all.length);
    });

    test('抽到嘅籤詩屬於該籤級', () {
      for (final score in [95, 75, 60, 45, 20]) {
        final r = drawDailyStick(profile: p, reading: fakeReading(date: d, score: score));
        expect(stickVerses[r.level]!.any((v) => v.join() == r.verse.join()), isTrue);
      }
    });
  });

  group('解曰', () {
    test('帶今日干支同第一個合適嘅宜', () {
      final r = drawDailyStick(profile: p, reading: fakeReading(date: d, yi: ['祈福', '祭祀']));
      expect(r.interpretation, contains('丙戌日'));
      expect(r.interpretation, contains('宜祈福'));
    });

    test('跳過「餘事勿取」同喪葬類項目', () {
      final r = drawDailyStick(
        profile: p,
        reading: fakeReading(date: d, yi: ['餘事勿取', '安葬', '破屋', '入殮', '開市']),
      );
      expect(r.interpretation, contains('宜開市'));
      for (final skipped in ['餘事勿取', '安葬', '破屋', '入殮']) {
        expect(r.interpretation.contains(skipped), isFalse, reason: skipped);
      }
    });

    test('冇合適嘅宜就講宜靜守，唔會空', () {
      final r = drawDailyStick(profile: p, reading: fakeReading(date: d, yi: ['餘事勿取']));
      expect(r.interpretation, contains('宜靜守'));
    });

    test('優先攞合你（matchesUser）嘅宜', () {
      final reading = DayReading(
        date: d, ganzhiDay: '丙戌', lunarLabel: '', zhiXing: '平', chong: '', fortuneScore: 75,
        mbtiScore: 60, band: '吉', ji: const [], advice: '', clashWarning: null, avoidHour: null,
        yi: const [
          YjItem(label: '祭祀', matchesUser: false),
          YjItem(label: '開市', matchesUser: true),
        ],
      );
      expect(drawDailyStick(profile: p, reading: reading).interpretation, contains('宜開市'));
    });
  });
}
