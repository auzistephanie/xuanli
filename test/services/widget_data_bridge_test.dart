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
    test('refreshNext7Days() 傳 7 日 JSON 去 saveWidgetData，再 call updateWidget', () async {
      String? savedId;
      String? savedData;
      var updateWidgetCalled = false;

      mockChannel((call) async {
        switch (call.method) {
          case 'saveWidgetData':
            final args = call.arguments as Map;
            savedId = args['id'] as String;
            savedData = args['data'] as String;
            return true;
          case 'updateWidget':
            updateWidgetCalled = true;
            return true;
          default:
            return null;
        }
      });

      final bridge = WidgetDataBridge();
      await bridge.refreshNext7Days(profile, today: DateTime(2026, 7, 11));

      expect(savedId, isNotNull);
      expect(updateWidgetCalled, isTrue);

      final decoded = json.decode(savedData!) as List;
      expect(decoded.length, 7);

      final first = decoded.first as Map<String, dynamic>;
      expect(first['date'], '2026-07-11');
      expect(first['ganzhiDay'], '丙戌');
      expect(first['band'], isA<String>());
      expect(first['fortuneScore'], isA<int>());
      expect((first['yi'] as List).length, lessThanOrEqualTo(3));
      expect((first['ji'] as List).length, lessThanOrEqualTo(2));

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
}
