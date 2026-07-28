import 'dart:convert';

import 'package:device_calendar/device_calendar.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xuanli/services/calendar_sync.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  void mockChannel(Future<dynamic> Function(MethodCall call) handler) {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(DeviceCalendarPlugin.channel, handler);
  }

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(DeviceCalendarPlugin.channel, null);
  });

  group('CalendarSyncService — permission (no channel mock, matches real dev-machine behavior)', () {
    test('hasPermission() 喺冇 platform channel implementation 嗰陣（好似呢部 Mac 冇 simulator）靜靜返 false', () async {
      final service = CalendarSyncService();
      expect(await service.hasPermission(), isFalse);
    });

    test('requestPermission() 同樣情況靜靜返 false，唔會 throw', () async {
      final service = CalendarSyncService();
      expect(await service.requestPermission(), isFalse);
    });
  });

  group('CalendarSyncService — permission (mocked channel)', () {
    test('hasPermission()/requestPermission() 兩者權限已批 → true', () async {
      mockChannel((call) async {
        if (call.method == 'hasPermissions' || call.method == 'requestPermissions') {
          return true;
        }
        return null;
      });

      final service = CalendarSyncService();
      expect(await service.hasPermission(), isTrue);
      expect(await service.requestPermission(), isTrue);
    });

    test('requestPermission() 已經有權限就唔會再 call requestPermissions channel method', () async {
      var requestPermissionsCalls = 0;
      mockChannel((call) async {
        if (call.method == 'hasPermissions') return true;
        if (call.method == 'requestPermissions') {
          requestPermissionsCalls++;
          return true;
        }
        return null;
      });

      final service = CalendarSyncService();
      await service.requestPermission();
      expect(requestPermissionsCalls, 0);
    });

    test('requestPermission() 冇權限、用戶拒絕 → false', () async {
      mockChannel((call) async {
        if (call.method == 'hasPermissions') return false;
        if (call.method == 'requestPermissions') return false;
        return null;
      });

      final service = CalendarSyncService();
      expect(await service.requestPermission(), isFalse);
    });
  });

  group('CalendarSyncService — addAllDayEvent (write)', () {
    test('冇權限 → 唔會建 event，返 false', () async {
      mockChannel((call) async {
        if (call.method == 'hasPermissions' || call.method == 'requestPermissions') {
          return false;
        }
        return null;
      });

      final service = CalendarSyncService();
      final ok = await service.addAllDayEvent(
        date: DateTime(2026, 7, 20),
        title: '剪髮（玄曆吉日）',
        description: '🔮 測試',
      );

      expect(ok, isFalse);
    });

    test('有權限、冇任何可寫日曆 → 返 false', () async {
      mockChannel((call) async {
        if (call.method == 'hasPermissions') return true;
        if (call.method == 'retrieveCalendars') {
          return json.encode([
            {'id': 'ro1', 'name': 'Readonly', 'isReadOnly': true, 'isDefault': false},
          ]);
        }
        return null;
      });

      final service = CalendarSyncService();
      final ok = await service.addAllDayEvent(
        date: DateTime(2026, 7, 20),
        title: '剪髮（玄曆吉日）',
        description: '🔮 測試',
      );

      expect(ok, isFalse);
    });

    test('有權限、有可寫日曆 → 揀 default calendar，建全日 event，傳啱標題/描述/日期', () async {
      Map<dynamic, dynamic>? sentArgs;
      mockChannel((call) async {
        if (call.method == 'hasPermissions') return true;
        if (call.method == 'retrieveCalendars') {
          return json.encode([
            {'id': 'personal', 'name': 'Personal', 'isReadOnly': false, 'isDefault': false},
            {'id': 'work', 'name': 'Work', 'isReadOnly': false, 'isDefault': true},
          ]);
        }
        if (call.method == 'createOrUpdateEvent') {
          sentArgs = call.arguments as Map<dynamic, dynamic>;
          return 'new-event-id';
        }
        return null;
      });

      final service = CalendarSyncService();
      final ok = await service.addAllDayEvent(
        date: DateTime(2026, 7, 20),
        title: '剪髮（玄曆吉日）',
        description: '🔮 通勝宜理髮',
      );

      expect(ok, isTrue);
      expect(sentArgs, isNotNull);
      expect(sentArgs!['calendarId'], 'work'); // 揀咗 isDefault=true 嗰個，唔係第一個
      expect(sentArgs!['eventTitle'], '剪髮（玄曆吉日）');
      expect(sentArgs!['eventDescription'], '🔮 通勝宜理髮');
      expect(sentArgs!['eventAllDay'], isTrue);

      // `sentArgs` 係 device_calendar package 真正嘅 `createOrUpdateEvent`
      // 對 [Event] 做完內部「歸位去午夜」處理之後先傳去 mock channel
      // 嗰個 map（呢個 test 淨係 mock 咗 platform channel 嗰層，冇 mock
      // package 自己嘅 Dart 前處理），所以 `eventStartDate` 呢個斷言
      // 會真係行過 package 嗰段用 host 系統 local time 重新起 UTC
      // instant 嘅邏輯。呢個 instant 代表緊「呢部跑緊 test 嘅機器噚下
      // 自己個 local time 嘅 2026-07-20 00:00」，所以要跟返同一個
      // host-local 解讀方式去計「應該係乜嘢」，唔可以假設任何固定
      // 嘅 UTC offset（唔同機器/CI 跑呢個 test 會有唔同、但一樣啱嘅
      // 結果）。
      final expectedStartMs =
          DateTime(2026, 7, 20, 0, 0, 0).toUtc().millisecondsSinceEpoch;
      expect(sentArgs!['eventStartDate'], expectedStartMs);
    });

    test('有權限、有可寫日曆、但冇 default → 揀第一個可寫嘅', () async {
      Map<dynamic, dynamic>? sentArgs;
      mockChannel((call) async {
        if (call.method == 'hasPermissions') return true;
        if (call.method == 'retrieveCalendars') {
          return json.encode([
            {'id': 'ro1', 'name': 'Readonly', 'isReadOnly': true, 'isDefault': false},
            {'id': 'personal', 'name': 'Personal', 'isReadOnly': false, 'isDefault': false},
          ]);
        }
        if (call.method == 'createOrUpdateEvent') {
          sentArgs = call.arguments as Map<dynamic, dynamic>;
          return 'new-event-id';
        }
        return null;
      });

      final service = CalendarSyncService();
      final ok = await service.addAllDayEvent(
        date: DateTime(2026, 7, 20),
        title: '剪髮（玄曆吉日）',
        description: '🔮 測試',
      );

      expect(ok, isTrue);
      expect(sentArgs!['calendarId'], 'personal');
    });
  });

  group('CalendarSyncService — eventsInRange/eventsOnDay (read)', () {
    test('冇權限 → 靜靜返 []，唔會嘗試彈權限對話框（唔會 call requestPermissions）', () async {
      var requestPermissionsCalls = 0;
      mockChannel((call) async {
        if (call.method == 'hasPermissions') return false;
        if (call.method == 'requestPermissions') {
          requestPermissionsCalls++;
          return true;
        }
        return null;
      });

      final service = CalendarSyncService();
      final events = await service.eventsInRange(
        start: DateTime(2026, 7, 1),
        end: DateTime(2026, 8, 1),
      );

      expect(events, isEmpty);
      expect(requestPermissionsCalls, 0);
    });

    test('有權限、跨兩個 calendar 嘅 events 會合埋一齊，按開始時間排序', () async {
      mockChannel((call) async {
        if (call.method == 'hasPermissions') return true;
        if (call.method == 'retrieveCalendars') {
          return json.encode([
            {'id': 'personal', 'name': 'Personal', 'isReadOnly': false, 'isDefault': true},
            {'id': 'work', 'name': 'Work', 'isReadOnly': false, 'isDefault': false},
          ]);
        }
        if (call.method == 'retrieveEvents') {
          final calendarId = (call.arguments as Map)['calendarId'];
          if (calendarId == 'personal') {
            return json.encode([
              {
                'eventId': 'e1',
                'calendarId': 'personal',
                'eventTitle': '晚飯',
                'eventStartDate':
                    DateTime.utc(2026, 7, 16, 19, 0).millisecondsSinceEpoch,
                'eventEndDate':
                    DateTime.utc(2026, 7, 16, 20, 0).millisecondsSinceEpoch,
                'eventAllDay': false,
              },
            ]);
          }
          if (calendarId == 'work') {
            return json.encode([
              {
                'eventId': 'e2',
                'calendarId': 'work',
                'eventTitle': '早會',
                'eventStartDate':
                    DateTime.utc(2026, 7, 16, 9, 0).millisecondsSinceEpoch,
                'eventEndDate':
                    DateTime.utc(2026, 7, 16, 9, 30).millisecondsSinceEpoch,
                'eventAllDay': false,
              },
            ]);
          }
          return json.encode([]);
        }
        return null;
      });

      final service = CalendarSyncService();
      final events = await service.eventsInRange(
        start: DateTime(2026, 7, 1),
        end: DateTime(2026, 8, 1),
      );

      expect(events.length, 2);
      // 早會 (9:00) 排喺 晚飯 (19:00) 前面，就算 work calendar 喺 API
      // response 入面排第二。
      expect(events[0].title, '早會');
      expect(events[1].title, '晚飯');
    });

    test('event 冇 eventTitle（好似某啲 reminder-style event）會被靜靜跳過，唔會出現喺結果入面', () async {
      mockChannel((call) async {
        if (call.method == 'hasPermissions') return true;
        if (call.method == 'retrieveCalendars') {
          return json.encode([
            {'id': 'personal', 'name': 'Personal', 'isReadOnly': false, 'isDefault': true},
          ]);
        }
        if (call.method == 'retrieveEvents') {
          return json.encode([
            {
              'eventId': 'e1',
              'calendarId': 'personal',
              'eventTitle': '晚飯',
              'eventStartDate':
                  DateTime.utc(2026, 7, 16, 19, 0).millisecondsSinceEpoch,
              'eventEndDate':
                  DateTime.utc(2026, 7, 16, 20, 0).millisecondsSinceEpoch,
              'eventAllDay': false,
            },
            {
              'eventId': 'e2',
              'calendarId': 'personal',
              // 冇 eventTitle key——好似某啲 reminder-style event，冇標題
              'eventStartDate':
                  DateTime.utc(2026, 7, 16, 9, 0).millisecondsSinceEpoch,
              'eventEndDate':
                  DateTime.utc(2026, 7, 16, 9, 30).millisecondsSinceEpoch,
              'eventAllDay': false,
            },
          ]);
        }
        return null;
      });

      final service = CalendarSyncService();
      final events = await service.eventsInRange(
        start: DateTime(2026, 7, 1),
        end: DateTime(2026, 8, 1),
      );

      expect(events.length, 1);
      expect(events[0].title, '晚飯');
    });

    test('eventsOnDay() 傳一個 [day, day+1) 嘅範圍去 retrieveEvents', () async {
      DateTime? sentStart;
      DateTime? sentEnd;
      mockChannel((call) async {
        if (call.method == 'hasPermissions') return true;
        if (call.method == 'retrieveCalendars') {
          return json.encode([
            {'id': 'personal', 'name': 'Personal', 'isReadOnly': false, 'isDefault': true},
          ]);
        }
        if (call.method == 'retrieveEvents') {
          final args = call.arguments as Map;
          sentStart =
              DateTime.fromMillisecondsSinceEpoch(args['startDate'] as int);
          sentEnd = DateTime.fromMillisecondsSinceEpoch(args['endDate'] as int);
          return json.encode([]);
        }
        return null;
      });

      final service = CalendarSyncService();
      await service.eventsOnDay(DateTime(2026, 7, 16, 15, 30));

      expect(sentStart, DateTime(2026, 7, 16));
      expect(sentEnd, DateTime(2026, 7, 17));
    });
  });
}
