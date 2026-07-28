import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xuanli/engine/almanac.dart';
import 'package:xuanli/engine/copywriter.dart';
import 'package:xuanli/engine/profile_builder.dart';
import 'package:xuanli/models/settings.dart';
import 'package:xuanli/services/notification_scheduler.dart';

const _notifChannel = MethodChannel('dexterous.com/flutter/local_notifications');
const _tzChannel = MethodChannel('flutter_timezone');

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    initMbtiTones(File('lib/data/mbti_tones.json').readAsStringSync());
    initActivityCategories(File('lib/data/activity_categories.json').readAsStringSync());
  });

  void mockNotifChannel(Future<dynamic> Function(MethodCall call) handler) {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_notifChannel, handler);
  }

  void mockTzChannel(Future<dynamic> Function(MethodCall call) handler) {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_tzChannel, handler);
  }

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_notifChannel, null);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_tzChannel, null);
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

  group('NotificationScheduler — 冇 platform channel implementation（呢部 Mac 嘅真實情況）', () {
    test('refreshNext7Days() 唔會 throw，靜靜完成', () async {
      final scheduler = NotificationScheduler();
      await scheduler.refreshNext7Days(
        profile: profile,
        settings: AppSettings.defaults,
        today: DateTime(2026, 7, 11),
      );
      // 冇 assertion 爆 = 冇 throw，就係呢個 test 想證明嘅嘢。
    });
  });

  group('NotificationScheduler — mocked platform channel', () {
    test('notificationsEnabled=false → 淨係 cancel 晒 7 個 id，唔會 zonedSchedule', () async {
      final cancelledIds = <int>[];
      var zonedScheduleCalled = false;

      mockTzChannel((call) async => 'Asia/Hong_Kong');
      mockNotifChannel((call) async {
        switch (call.method) {
          case 'initialize':
            return true;
          case 'cancel':
            // 喺 `flutter test` 底下 defaultTargetPlatform 恆定係
            // android（見 flutter/src/foundation/_platform_io.dart 嘅
            // FLUTTER_TEST env var override），所以呢度行嘅係
            // AndroidFlutterLocalNotificationsPlugin.cancel，佢傳嘅
            // arguments 係 `{'id': id, 'tag': tag}` 呢個 Map，唔係
            // 一個裸 int。
            final args = call.arguments as Map;
            cancelledIds.add(args['id'] as int);
            return null;
          case 'zonedSchedule':
            zonedScheduleCalled = true;
            return null;
          default:
            return null;
        }
      });

      final scheduler = NotificationScheduler();
      await scheduler.refreshNext7Days(
        profile: profile,
        settings: AppSettings.defaults.copyWith(notificationsEnabled: false),
        today: DateTime(2026, 7, 11),
      );

      expect(cancelledIds.toSet(), {1000, 1001, 1002, 1003, 1004, 1005, 1006});
      expect(zonedScheduleCalled, isFalse);
    });

    test('notificationsEnabled=true → cancel 晒之後，排晒未來嗰幾日，傳啱 id/title/body', () async {
      final scheduledCalls = <Map<dynamic, dynamic>>[];

      mockTzChannel((call) async => 'Asia/Hong_Kong');
      mockNotifChannel((call) async {
        switch (call.method) {
          case 'initialize':
            return true;
          case 'cancel':
            return null;
          case 'zonedSchedule':
            scheduledCalls.add(call.arguments as Map<dynamic, dynamic>);
            return null;
          default:
            return null;
        }
      });

      final scheduler = NotificationScheduler();
      // "today" 用未來日子（相對於 test 執行嗰刻），確保 7 日全部都
      // 未過去，7 個 zonedSchedule call 全部都應該真係發生。用
      // DateTime.now() 加 30 日，避免呢個 test 隨時間推移而失效。
      final farFuture = DateTime.now().add(const Duration(days: 30));
      await scheduler.refreshNext7Days(
        profile: profile,
        settings: AppSettings.defaults,
        today: DateTime(farFuture.year, farFuture.month, farFuture.day),
      );

      expect(scheduledCalls.length, 7);
      final ids = scheduledCalls.map((c) => c['id'] as int).toSet();
      expect(ids, {1000, 1001, 1002, 1003, 1004, 1005, 1006});
      for (final call in scheduledCalls) {
        expect(call['title'], '玄曆');
        expect((call['body'] as String).startsWith('今日'), isTrue);
      }
    });

    test('today 淨係得過去嘅時間（例如 07:30 已經過咗）→ 嗰一日唔會 zonedSchedule，但唔會 throw', () async {
      var zonedScheduleCount = 0;

      mockTzChannel((call) async => 'Asia/Hong_Kong');
      mockNotifChannel((call) async {
        switch (call.method) {
          case 'initialize':
            return true;
          case 'cancel':
            return null;
          case 'zonedSchedule':
            zonedScheduleCount++;
            return null;
          default:
            return null;
        }
      });

      final scheduler = NotificationScheduler();
      // "today" 用好耐之前嘅日子，settings 嘅時間（07:30）實一定已經
      // 過咗（相對於 test 真實執行嘅 wall clock）——7 日全部都應該
      // 俾 validateDateIsInTheFuture 邏輯跳過，唔會 call zonedSchedule，
      // 但都唔應該 throw。
      await scheduler.refreshNext7Days(
        profile: profile,
        settings: AppSettings.defaults,
        today: DateTime(2020, 1, 1),
      );

      expect(zonedScheduleCount, 0);
    });

    test('timezone detection 失敗都唔會令成個 refresh 爆', () async {
      mockTzChannel((call) async {
        throw PlatformException(code: 'ERR', message: 'boom');
      });
      mockNotifChannel((call) async => call.method == 'initialize' ? true : null);

      final scheduler = NotificationScheduler();
      await scheduler.refreshNext7Days(
        profile: profile,
        settings: AppSettings.defaults,
        today: DateTime(2026, 7, 11),
      );
      // 冇 throw 就已經證明咗呢個 test 想要嘅嘢。
    });
  });
}
