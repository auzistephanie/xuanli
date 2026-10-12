import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xuanli/engine/almanac.dart';
import 'package:xuanli/engine/copywriter.dart';
import 'package:xuanli/engine/profile_builder.dart';
import 'package:xuanli/services/widget_data_bridge.dart';

const _channel = MethodChannel('home_widget');

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    initMbtiTones(File('lib/data/mbti_tones.json').readAsStringSync());
    initActivityCategories(
      File('lib/data/activity_categories.json').readAsStringSync(),
    );
  });

  void mockChannel(Future<dynamic> Function(MethodCall call) handler) {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_channel, handler);
  }

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_channel, null);
  });

  final profile = buildProfile(
    id: 'p1',
    name: '阿玄',
    birthDate: DateTime(1999, 9, 20),
    birthHour: 9,
    birthMinute: 30,
    birthPlace: '香港',
    mbti: 'ISFP',
  );

  group('WidgetDataBridge — 冇 platform channel implementation（呢部 Mac 嘅真實情況）', () {
    test('refreshNext7Days() 唔會 throw，靜靜完成（冇註冊 handler = MissingPluginException）', () async {
      final bridge = WidgetDataBridge();
      await bridge.refreshNext7Days(profile, today: DateTime(2026, 7, 11));
      // 冇 assertion 爆 = 冇 throw，就係呢個 test 想證明嘅嘢。
    });
  });

  group('WidgetDataBridge — mocked platform channel', () {
    test('refreshNext7Days() 設 App Group、傳 7 日 JSON，再更新 iOS／兩個 Android widget', () async {
      String? savedId;
      String? savedData;
      String? groupId;
      final updated = <Map>[];

      mockChannel((call) async {
        switch (call.method) {
          case 'setAppGroupId':
            groupId = (call.arguments as Map)['groupId'] as String;
            return true;
          case 'saveWidgetData':
            final args = call.arguments as Map;
            savedId = args['id'] as String;
            savedData = args['data'] as String;
            return true;
          case 'updateWidget':
            updated.add(call.arguments as Map);
            return true;
          default:
            return null;
        }
      });

      final bridge = WidgetDataBridge();
      await bridge.refreshNext7Days(profile, today: DateTime(2026, 7, 11));

      // 原生 widget 靠呢三個名認返出嚟（Swift／Kotlin／entitlements 要一致）。
      expect(groupId, WidgetDataBridge.appGroupId);
      expect(WidgetDataBridge.appGroupId, 'group.com.xuanli.xuanli');
      expect(savedId, 'xuanli_week_readings');
      expect(updated.map((u) => u['android']).toSet(), {
        'XuanLiWidgetProvider',
        'XuanLiWidgetMediumProvider',
      });
      expect(updated.every((u) => u['ios'] == 'XuanLiWidget'), isTrue);

      final decoded = json.decode(savedData!) as List;
      expect(decoded.length, 7);

      final first = decoded.first as Map<String, dynamic>;
      expect(first['date'], '2026-07-11');
      expect(first['ganzhiDay'], '丙戌');
      expect(first['band'], isA<String>());
      expect(first['fortuneScore'], isA<int>());

      // 2026-07-11（first）真實 yi/ji 數量本身已經 ≤ cap，唔夠力證
      // 明真係有 truncate 咗；2026-07-12（decoded[1]）真實數量係
      // yi=5／ji=4，確實超過 take(3)/take(2) 個 cap，用呢日先可以
      // 真正驗到 truncation 發生咗（唔係「啱啱好喺 cap 之下」）。
      final second = decoded[1] as Map<String, dynamic>;
      expect(second['yi'] as List, hasLength(3));
      expect(second['ji'] as List, hasLength(2));

      final last = decoded.last as Map<String, dynamic>;
      expect(last['date'], '2026-07-17'); // today + 6 days
    });

    test('saveWidgetData 失敗（channel throw）都唔會令成個 method 爆', () async {
      mockChannel((call) async {
        throw PlatformException(code: 'ERR', message: 'boom');
      });

      final bridge = WidgetDataBridge();
      // 唔應該 throw ——refreshNext7Days 係 best-effort background refresh，
      // native widget 側可能仲未存在（呢個 plan 冇起 native extension）。
      await bridge.refreshNext7Days(profile, today: DateTime(2026, 7, 11));
    });
  });

  group('原生 widget 讀嘅 JSON 合約', () {
    test('每日物件剛好包 Swift／Kotlin 讀嘅欄位，冇多（keep 細）', () async {
      String? savedData;
      mockChannel((call) async {
        if (call.method == 'saveWidgetData') {
          savedData = (call.arguments as Map)['data'] as String;
        }
        return true;
      });
      await WidgetDataBridge().refreshNext7Days(profile, today: DateTime(2026, 7, 11));

      final day = (json.decode(savedData!) as List).first as Map<String, dynamic>;
      expect(day.keys.toSet(), {
        'date', 'ganzhiDay', 'lunarLabel', 'fortuneScore', 'band', 'yi', 'ji', 'avoidHour',
      });
      expect(day['date'], matches(RegExp(r'^\d{4}-\d{2}-\d{2}$')));
      expect(['吉', '平', '忌'], contains(day['band']));
      expect(day['fortuneScore'], inInclusiveRange(0, 100));
    });

    test('宜欄唔會出現「餘事勿取」（通勝術語，widget 一眼睇冇意思）', () async {
      String? savedData;
      mockChannel((call) async {
        if (call.method == 'saveWidgetData') {
          savedData = (call.arguments as Map)['data'] as String;
        }
        return true;
      });
      // 2026-07-11 丙戌日：通勝「宜」係 祭祀、解除、餘事勿取。
      await WidgetDataBridge().refreshNext7Days(profile, today: DateTime(2026, 7, 11));

      final days = json.decode(savedData!) as List;
      for (final d in days) {
        expect((d as Map)['yi'] as List, isNot(contains('餘事勿取')));
      }
      expect((days.first as Map)['yi'], ['祭祀', '解除']);
    });

    test('冇任何個人資料／備註跟埋出去（姓名、出生日期、MBTI）', () async {
      String? savedData;
      mockChannel((call) async {
        if (call.method == 'saveWidgetData') {
          savedData = (call.arguments as Map)['data'] as String;
        }
        return true;
      });
      await WidgetDataBridge().refreshNext7Days(profile, today: DateTime(2026, 7, 11));

      for (final secret in ['阿玄', '1999', 'ISFP', '香港', 'birthDate']) {
        expect(savedData!.contains(secret), isFalse, reason: secret);
      }
    });
  });
}
