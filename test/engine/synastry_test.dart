import 'package:test/test.dart';
import 'package:xuanli/engine/profile_builder.dart';
import 'package:xuanli/engine/synastry.dart';
import 'package:xuanli/models/profile.dart';

/// 直接砌一個 Profile，唔經 bazi 計算——合盤只睇日主、日支、五行、喜神、MBTI。
Profile fake({
  required String dayPillar,
  String mbti = 'ISFP',
  Map<String, int> wuxing = const {'木': 20, '火': 20, '土': 20, '金': 20, '水': 20},
  List<String> favorable = const ['木', '水'],
}) {
  return Profile(
    id: 'x',
    name: 'x',
    birthDate: DateTime(2000, 1, 1),
    birthHour: 9,
    birthPlace: '香港',
    mbti: mbti,
    pillars: ['甲子', '甲子', dayPillar, '甲子'],
    wuxing: wuxing,
    favorable: favorable,
    unfavorable: const ['金', '土'],
    dayMaster: '${dayPillar.substring(0, 1)}木', // 同真 profile 一樣係「乙木」呢類顯示字串
    ziweiStar: '紫微',
    zodiac: '鼠',
  );
}

void main() {
  const gans = ['甲', '乙', '丙', '丁', '戊', '己', '庚', '辛', '壬', '癸'];
  const elements = ['木', '火', '土', '金', '水'];
  const elementGan = {'木': '甲', '火': '丙', '土': '戊', '金': '庚', '水': '壬'};

  group('日主五行關係', () {
    test('同五行 → 比和（唔同天干都係）', () {
      expect(computeSynastry(fake(dayPillar: '甲子'), fake(dayPillar: '乙丑')).stemRelation,
          StemRelation.same);
    });

    test('相生：木火、火土、土金、金水、水木（雙向都係相生）', () {
      for (final pair in [
        ['木', '火'], ['火', '土'], ['土', '金'], ['金', '水'], ['水', '木'],
      ]) {
        final a = fake(dayPillar: '${elementGan[pair[0]]}子');
        final b = fake(dayPillar: '${elementGan[pair[1]]}子');
        expect(computeSynastry(a, b).stemRelation, StemRelation.generates, reason: pair.join());
        expect(computeSynastry(b, a).stemRelation, StemRelation.generates, reason: pair.join());
      }
    });

    test('相剋：木土、土水、水火、火金、金木', () {
      for (final pair in [
        ['木', '土'], ['土', '水'], ['水', '火'], ['火', '金'], ['金', '木'],
      ]) {
        final a = fake(dayPillar: '${elementGan[pair[0]]}子');
        final b = fake(dayPillar: '${elementGan[pair[1]]}子');
        expect(computeSynastry(a, b).stemRelation, StemRelation.controls, reason: pair.join());
      }
    });
  });

  group('日支關係', () {
    test('六合：子丑、寅亥、卯戌、辰酉、巳申、午未', () {
      for (final pair in [
        ['子', '丑'], ['寅', '亥'], ['卯', '戌'], ['辰', '酉'], ['巳', '申'], ['午', '未'],
      ]) {
        final r = computeSynastry(fake(dayPillar: '甲${pair[0]}'), fake(dayPillar: '乙${pair[1]}'));
        expect(r.branchRelation, BranchRelation.combine, reason: pair.join());
      }
    });

    test('六沖：子午、丑未、寅申、卯酉、辰戌、巳亥', () {
      for (final pair in [
        ['子', '午'], ['丑', '未'], ['寅', '申'], ['卯', '酉'], ['辰', '戌'], ['巳', '亥'],
      ]) {
        final r = computeSynastry(fake(dayPillar: '甲${pair[0]}'), fake(dayPillar: '乙${pair[1]}'));
        expect(r.branchRelation, BranchRelation.clash, reason: pair.join());
      }
    });

    test('同支 / 其他', () {
      expect(computeSynastry(fake(dayPillar: '甲子'), fake(dayPillar: '丙子')).branchRelation,
          BranchRelation.same);
      expect(computeSynastry(fake(dayPillar: '甲子'), fake(dayPillar: '丙寅')).branchRelation,
          BranchRelation.none);
    });
  });

  group('喜用神互補', () {
    final strongWater = {'木': 10, '火': 10, '土': 10, '金': 10, '水': 60};
    final strongWood = {'木': 60, '火': 10, '土': 10, '金': 10, '水': 10};
    final flat = {'木': 20, '火': 20, '土': 20, '金': 20, '水': 20};

    test('雙向互補 = 2', () {
      final a = fake(dayPillar: '甲子', wuxing: strongWood, favorable: ['水']);
      final b = fake(dayPillar: '壬子', wuxing: strongWater, favorable: ['木']);
      expect(computeSynastry(a, b).complement, 2);
    });

    test('單向 = 1', () {
      final a = fake(dayPillar: '甲子', wuxing: flat, favorable: ['水']);
      final b = fake(dayPillar: '壬子', wuxing: strongWater, favorable: ['火']);
      expect(computeSynastry(a, b).complement, 1);
    });

    test('冇互補 = 0', () {
      final a = fake(dayPillar: '甲子', wuxing: flat, favorable: ['水']);
      final b = fake(dayPillar: '壬子', wuxing: flat, favorable: ['木']);
      expect(computeSynastry(a, b).complement, 0);
    });
  });

  group('MBTI 關係（只影響文案，唔入分數）', () {
    test('相同字母數 4/3/2/1/0', () {
      int shared(String x, String y) =>
          computeSynastry(fake(dayPillar: '甲子', mbti: x), fake(dayPillar: '甲子', mbti: y))
              .mbtiShared;
      expect(shared('ISFP', 'ISFP'), 4);
      expect(shared('ISFP', 'ESFP'), 3);
      expect(shared('ISFP', 'INFJ'), 2);
      expect(shared('ISFP', 'ENTJ'), 0);
      expect(shared('ISFP', 'ENFJ'), 1);
    });

    test('改 MBTI 唔會改分數，但會改文案', () {
      final a = fake(dayPillar: '甲子', mbti: 'ISFP');
      final r1 = computeSynastry(a, fake(dayPillar: '丙寅', mbti: 'ISFP'));
      final r2 = computeSynastry(a, fake(dayPillar: '丙寅', mbti: 'ENTJ'));
      expect(r1.score, r2.score);
      expect(r1.mbtiLabel, isNot(r2.mbtiLabel));
      expect(r1.tips, isNot(r2.tips));
    });
  });

  group('分數、關係名、文案', () {
    test('15 個五行配對各有唔同嘅四字關係名', () {
      final names = <String>{};
      for (var i = 0; i < elements.length; i++) {
        for (var j = i; j < elements.length; j++) {
          final r = computeSynastry(
            fake(dayPillar: '${elementGan[elements[i]]}子'),
            fake(dayPillar: '${elementGan[elements[j]]}子'),
          );
          expect(r.name.runes.length, 4, reason: r.name);
          names.add(r.name);
        }
      }
      expect(names.length, 15);
    });

    test('對稱：交換 A、B 結果完全一樣', () {
      for (final x in gans) {
        for (final y in gans) {
          final a = fake(dayPillar: '$x寅', mbti: 'INFP', favorable: ['木', '火']);
          final b = fake(dayPillar: '$y午', mbti: 'ESTJ', favorable: ['土']);
          final r1 = computeSynastry(a, b);
          final r2 = computeSynastry(b, a);
          expect(r1.score, r2.score);
          expect(r1.name, r2.name);
          expect(r1.description, r2.description);
          expect(r1.tips, r2.tips);
        }
      }
    });

    test('分數範圍 61–99（文案一律正面，冇低分）', () {
      var min = 100, max = 0;
      const zhis = ['子', '丑', '寅', '卯', '辰', '巳', '午', '未', '申', '酉', '戌', '亥'];
      const flats = [
        {'木': 20, '火': 20, '土': 20, '金': 20, '水': 20},
        {'木': 60, '火': 10, '土': 10, '金': 10, '水': 10},
        {'木': 10, '火': 10, '土': 10, '金': 10, '水': 60},
      ];
      for (final x in gans) {
        for (final zx in zhis) {
          for (final zy in zhis) {
            for (final wx in flats) {
              for (final fav in [<String>['木'], <String>['水'], <String>['火', '土']]) {
                final a = fake(dayPillar: '$x$zx', wuxing: wx, favorable: fav);
                final b = fake(dayPillar: '甲$zy', wuxing: flats[1], favorable: ['水']);
                final s = computeSynastry(a, b).score;
                if (s < min) min = s;
                if (s > max) max = s;
              }
            }
          }
        }
      }
      expect(min, greaterThanOrEqualTo(61));
      expect(max, lessThanOrEqualTo(99));
      expect(max, greaterThan(min));
    });

    test('分數同標題：高分更好，標題正面', () {
      final best = computeSynastry(
        fake(dayPillar: '甲子', wuxing: {'木': 60, '火': 10, '土': 10, '金': 10, '水': 10}, favorable: ['水']),
        fake(dayPillar: '壬丑', wuxing: {'木': 10, '火': 10, '土': 10, '金': 10, '水': 60}, favorable: ['木']),
      );
      expect(best.stemRelation, StemRelation.generates);
      expect(best.branchRelation, BranchRelation.combine);
      expect(best.complement, 2);
      expect(best.score, 99);
      expect(best.scoreTitle, '天作之合');
    });

    test('每個結果都有文案同三條相處之道，而且冇負面字眼', () {
      const banned = ['唔夾', '唔配', '分手', '孽緣', '剋夫', '剋妻', '大凶', '犯沖', '災'];
      for (final x in gans) {
        for (final y in gans) {
          for (final zy in ['子', '午', '丑', '寅']) {
            final r = computeSynastry(
              fake(dayPillar: '$x子', mbti: 'INFJ'),
              fake(dayPillar: '$y$zy', mbti: 'ESTP'),
            );
            expect(r.description, isNotEmpty);
            expect(r.tips.length, 3);
            final all = [r.name, r.scoreTitle, r.description, r.mbtiLabel, r.mbtiNote, ...r.tips].join();
            for (final w in banned) {
              expect(all.contains(w), isFalse, reason: '$w in ${r.name}');
            }
          }
        }
      }
    });

    test('deterministic：同樣輸入跑 100 次結果一樣', () {
      final a = buildProfile(
        id: 'a', name: 'a', birthDate: DateTime(1999, 9, 20), birthHour: 9,
        birthMinute: 30, birthPlace: '香港', mbti: 'ISFP',
      );
      final b = buildProfile(
        id: 'b', name: 'b', birthDate: DateTime(2000, 1, 7), birthHour: 9,
        birthMinute: 30, birthPlace: '香港', mbti: 'INTJ',
      );
      final first = computeSynastry(a, b);
      for (var i = 0; i < 100; i++) {
        final r = computeSynastry(a, b);
        expect(r.score, first.score);
        expect(r.name, first.name);
        expect(r.description, first.description);
      }
    });

    test('真實 profile：阿玄（乙亥日）× 甲子日 INTJ', () {
      final a = buildProfile(
        id: 'a', name: 'a', birthDate: DateTime(1999, 9, 20), birthHour: 9,
        birthMinute: 30, birthPlace: '香港', mbti: 'ISFP',
      );
      final b = buildProfile(
        id: 'b', name: 'b', birthDate: DateTime(2000, 1, 7), birthHour: 9,
        birthMinute: 30, birthPlace: '香港', mbti: 'INTJ',
      );
      final r = computeSynastry(a, b);
      // 阿玄日主乙木（日支亥）；2000-01-07 日主甲木 → 同五行比和。
      expect(a.pillars[2].substring(0, 1), '乙');
      expect(b.pillars[2].substring(0, 1), '甲');
      expect(r.stemRelation, StemRelation.same);
      expect(r.name, '同林共蔭');
      expect(r.score, inInclusiveRange(61, 99));
    });
  });
}
