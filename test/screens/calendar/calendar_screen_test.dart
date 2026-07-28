import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:device_calendar/device_calendar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xuanli/engine/almanac.dart';
import 'package:xuanli/engine/copywriter.dart';
import 'package:xuanli/engine/profile_builder.dart';
import 'package:xuanli/screens/calendar/calendar_screen.dart';
import 'package:xuanli/screens/calendar/calendar_widgets.dart';
import 'package:xuanli/theme/xuanli_theme.dart';

void main() {
  setUpAll(() {
    initMbtiTones(File('lib/data/mbti_tones.json').readAsStringSync());
    initActivityCategories(
      File('lib/data/activity_categories.json').readAsStringSync(),
    );
  });

  Widget wrap(Widget child) =>
      MaterialApp(theme: XuanLiTheme.light(), home: child);

  final profile = buildProfile(
    id: 'p1',
    name: '阿玄',
    birthDate: DateTime(1999, 9, 20),
    birthHour: 9,
    birthMinute: 30,
    birthPlace: '香港',
    mbti: 'ISFP',
  );

  testWidgets('顯示 2026 年 7 月，今日（7月11日）預設展開日卡', (tester) async {
    await tester.pumpWidget(wrap(CalendarScreen(
      profile: profile,
      today: DateTime(2026, 7, 11),
    )));

    expect(find.textContaining('2026年7月'), findsOneWidget);
    expect(find.textContaining('丙午年'), findsOneWidget);
    // 今日預設展開，日卡應該顯示緊 7-11 golden fixture 嘅內容。
    expect(find.textContaining('7月11日'), findsOneWidget);
    expect(find.textContaining('丙戌'), findsWidgets);
  });

  testWidgets('撳「›」去下個月，header 會轉，選日狀態reset（冇日卡）', (tester) async {
    await tester.pumpWidget(wrap(CalendarScreen(
      profile: profile,
      today: DateTime(2026, 7, 11),
    )));

    await tester.tap(find.text('›'));
    await tester.pumpAndSettle();

    expect(find.textContaining('2026年8月'), findsOneWidget);
    // 選日狀態要 reset：舊日卡（7月11日）唔應該再存在，成個 DayCard 都冇。
    expect(find.textContaining('7月11日'), findsNothing);
    expect(find.byType(DayCard), findsNothing);
  });

  testWidgets('12月撳「›」去1月，年份要進位', (tester) async {
    await tester.pumpWidget(wrap(CalendarScreen(
      profile: profile,
      today: DateTime(2026, 12, 1),
    )));

    await tester.tap(find.text('›'));
    await tester.pumpAndSettle();

    expect(find.textContaining('2027年1月'), findsOneWidget);
  });

  testWidgets('1900年1月撳「‹」冇反應（clamp）', (tester) async {
    await tester.pumpWidget(wrap(CalendarScreen(
      profile: profile,
      today: DateTime(1900, 1, 15),
    )));

    expect(find.textContaining('1900年1月'), findsOneWidget);

    await tester.tap(find.text('‹'));
    await tester.pumpAndSettle();

    expect(find.textContaining('1900年1月'), findsOneWidget);
  });

  testWidgets('2100年12月撳「›」冇反應（clamp）', (tester) async {
    await tester.pumpWidget(wrap(CalendarScreen(
      profile: profile,
      today: DateTime(2100, 12, 15),
    )));

    expect(find.textContaining('2100年12月'), findsOneWidget);

    await tester.tap(find.text('›'));
    await tester.pumpAndSettle();

    expect(find.textContaining('2100年12月'), findsOneWidget);
  });

  testWidgets('揀 31 號之後跳去短月份（2月），唔會 crash 亦冇殘留舊選擇', (tester) async {
    await tester.pumpWidget(wrap(CalendarScreen(
      profile: profile,
      today: DateTime(2026, 1, 11),
    )));

    await tester.tap(find.text('31'));
    await tester.pumpAndSettle();

    expect(find.textContaining('1月31日'), findsOneWidget);

    await tester.tap(find.text('›'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.textContaining('2026年2月'), findsOneWidget);
    expect(find.textContaining('1月31日'), findsNothing);
    expect(find.byType(DayCard), findsNothing);
  });

  testWidgets('撳月曆入面第 16 日（7月16日），日卡轉去嗰日', (tester) async {
    await tester.pumpWidget(wrap(CalendarScreen(
      profile: profile,
      today: DateTime(2026, 7, 11),
    )));

    await tester.tap(find.text('16'));
    await tester.pumpAndSettle();

    expect(find.textContaining('7月16日'), findsOneWidget);
    expect(find.textContaining('辛卯'), findsWidgets);
  });

  group('CalendarScreen — device_calendar 整合（mocked platform channel）', () {
    tearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(DeviceCalendarPlugin.channel, null);
    });

    testWidgets('有權限＋7月16日有 event：格仔顯示行程橫條，撳開日卡顯示行程列表', (tester) async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(DeviceCalendarPlugin.channel, (call) async {
        switch (call.method) {
          case 'hasPermissions':
          case 'requestPermissions':
            return true;
          case 'retrieveCalendars':
            return json.encode([
              {'id': 'cal1', 'name': 'Personal', 'isReadOnly': false, 'isDefault': true},
            ]);
          case 'retrieveEvents':
            return json.encode([
              {
                'eventId': 'e1',
                'calendarId': 'cal1',
                'eventTitle': '午餐會議',
                'eventStartDate':
                    DateTime.utc(2026, 7, 16, 14, 30).millisecondsSinceEpoch,
                'eventEndDate':
                    DateTime.utc(2026, 7, 16, 15, 30).millisecondsSinceEpoch,
                'eventAllDay': false,
              },
            ]);
          default:
            return null;
        }
      });

      await tester.pumpWidget(wrap(CalendarScreen(
        profile: profile,
        today: DateTime(2026, 7, 11),
      )));
      await tester.pumpAndSettle();

      await tester.tap(find.text('16'));
      await tester.pumpAndSettle();

      expect(find.textContaining('你嘅行程'), findsOneWidget);
      expect(find.text('14:30 午餐會議'), findsOneWidget);
    });

    testWidgets('冇日曆權限：日卡完全冇「你嘅行程」section（同冇 mock 嘅預設情況一致）', (tester) async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(DeviceCalendarPlugin.channel, (call) async {
        if (call.method == 'hasPermissions' || call.method == 'requestPermissions') {
          return false;
        }
        return null;
      });

      await tester.pumpWidget(wrap(CalendarScreen(
        profile: profile,
        today: DateTime(2026, 7, 11),
      )));
      await tester.pumpAndSettle();

      expect(find.textContaining('你嘅行程'), findsNothing);
    });

    testWidgets(
      '快速撳日 5 就撳日 10（日 5 個 request 仲未返到嚟就撳咗日 10）：'
      '就算日 5 個 response 遲過日 10 至返到（out-of-order），都唔應該'
      '用嚟蓋走已經顯示緊嘅日 10 行程（generation-counter guard）',
      (tester) async {
        // day 5／day 10 各自一個 completer，畀測試自己揸主幾時完成，
        // 模擬 platform-channel round-trip 遲返、而且遲到嘅係較舊嗰個
        // request。其他 query（初次 mount 嘅月/日 load）即刻返，唔
        // 阻住 pumpAndSettle。
        final dayCompleters = <int, Completer<String>>{};

        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(DeviceCalendarPlugin.channel, (call) async {
          switch (call.method) {
            case 'hasPermissions':
            case 'requestPermissions':
              return true;
            case 'retrieveCalendars':
              return json.encode([
                {'id': 'cal1', 'name': 'Personal', 'isReadOnly': false, 'isDefault': true},
              ]);
            case 'retrieveEvents':
              final args = Map<String, dynamic>.from(call.arguments as Map);
              final startMs = args['startDate'] as int;
              final endMs = args['endDate'] as int;
              final isDayQuery =
                  endMs - startMs <= const Duration(days: 1).inMilliseconds;
              // 用系統 local time 解碼返（唔好用 isUtc:true）：production
              // code 起 query range 個陣用嘅係普通 `DateTime(y,m,d)`
              // （wall-clock/local），唔係 UTC，所以要用返同一種方式先
              // 解碼得返正確嘅 day（例如喺 UTC+8 機度，用 isUtc:true 讀
              // 會俾差一日）。
              final day = DateTime.fromMillisecondsSinceEpoch(startMs).day;
              if (isDayQuery && (day == 5 || day == 10)) {
                final completer = Completer<String>();
                dayCompleters[day] = completer;
                return completer.future;
              }
              return json.encode([]);
            default:
              return null;
          }
        });

        await tester.pumpWidget(wrap(CalendarScreen(
          profile: profile,
          today: DateTime(2026, 7, 20),
        )));
        await tester.pumpAndSettle();

        // 撳日 5：request 出發，但都未完成（completer 仲未 complete）。
        // hasPermission()／retrieveCalendars() 中間都各自有一層 await，
        // 所以要 pump 多幾次先真正行到 retrieveEvents 嗰步、將個
        // completer 記落 map（單一次 pump 唔夠 flush 晒啲 microtask）。
        await tester.tap(find.text('5'));
        await tester.pump();
        await tester.pump();
        await tester.pump();
        expect(dayCompleters.containsKey(5), isTrue,
            reason: '日 5 個 retrieveEvents request 應該已經出發、但仲未完成');

        // 日 5 個 response 都仲未返，用戶又快手撳咗日 10：又出發多一個
        // request，呢個時候兩個都仲 in-flight。
        await tester.tap(find.text('10'));
        await tester.pump();
        await tester.pump();
        await tester.pump();
        expect(dayCompleters.containsKey(10), isTrue,
            reason: '日 10 個 retrieveEvents request 應該已經出發、但仲未完成');

        // Out-of-order：後出發嘅日 10 request 先完成……
        dayCompleters[10]!.complete(json.encode([
          {
            'eventId': 'e10',
            'calendarId': 'cal1',
            'eventTitle': '十號會議',
            'eventStartDate':
                DateTime.utc(2026, 7, 10, 10, 0).millisecondsSinceEpoch,
            'eventEndDate':
                DateTime.utc(2026, 7, 10, 11, 0).millisecondsSinceEpoch,
            'eventAllDay': false,
          },
        ]));
        await tester.pump();

        // ……先出發嘅日 5 request 遲啲至完成（先出發、遲返嘅典型
        // race scenario）。
        dayCompleters[5]!.complete(json.encode([
          {
            'eventId': 'e5',
            'calendarId': 'cal1',
            'eventTitle': '五號會議',
            'eventStartDate':
                DateTime.utc(2026, 7, 5, 14, 0).millisecondsSinceEpoch,
            'eventEndDate':
                DateTime.utc(2026, 7, 5, 15, 0).millisecondsSinceEpoch,
            'eventAllDay': false,
          },
        ]));
        await tester.pumpAndSettle();

        // 用戶最後撳嗰個係日 10，顯示緊嘅日卡／行程都應該係日 10 嗰單
        // ——唔應該畀遲返到嘅日 5 response 蓋走。
        expect(find.textContaining('7月10日'), findsOneWidget);
        expect(find.text('10:00 十號會議'), findsOneWidget);
        expect(find.text('14:00 五號會議'), findsNothing);
      },
    );

    testWidgets(
      '跨月份未返到嚟嗰陣撳日（cross-method）：月曆 query（8月）仲未有'
      'response、用戶就撳咗日（呢個日 query 即刻返、完成咗），跟住月曆'
      '嗰個遲來但係啱嘅 response 先返到——唔應該畀個日 load 誤傷咗、'
      '個月嘅 event dots 一定要顯示出嚟（regression test：月同日兩個'
      'load method 唔應該共用同一個 generation counter，各自嘅 in-flight'
      'request 淨係應該畀自己 method 嘅新 request 蓋過，唔應該畀另一個'
      'method 嘅 request 玩死）',
      (tester) async {
        final monthCompleter = Completer<String>();

        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(DeviceCalendarPlugin.channel, (call) async {
          switch (call.method) {
            case 'hasPermissions':
            case 'requestPermissions':
              return true;
            case 'retrieveCalendars':
              return json.encode([
                {'id': 'cal1', 'name': 'Personal', 'isReadOnly': false, 'isDefault': true},
              ]);
            case 'retrieveEvents':
              final args = Map<String, dynamic>.from(call.arguments as Map);
              final startMs = args['startDate'] as int;
              final endMs = args['endDate'] as int;
              final isDayQuery =
                  endMs - startMs <= const Duration(days: 1).inMilliseconds;
              final start = DateTime.fromMillisecondsSinceEpoch(startMs);
              // 淨係 8月嘅月曆 query（非日 query）先延遲；其他一律即刻
              // 返（包括初次 mount 嘅 7月月曆／7月11日 day query，同埋
              // 之後撳 16 號嗰個 day query）。
              if (!isDayQuery && start.year == 2026 && start.month == 8) {
                return monthCompleter.future;
              }
              return json.encode([]);
            default:
              return null;
          }
        });

        await tester.pumpWidget(wrap(CalendarScreen(
          profile: profile,
          today: DateTime(2026, 7, 11),
        )));
        await tester.pumpAndSettle();

        // 撳「›」去 8月：觸發 _loadMonthEvents()，個 request 出發咗但
        // 未完成（畀 monthCompleter 揸住）。同上面 day5/day10 個 test
        // 一樣，中間隔咗 hasPermission()／retrieveCalendars() 幾層
        // await，要 pump 幾次先真正行到 retrieveEvents。
        await tester.tap(find.text('›'));
        await tester.pump();
        await tester.pump();
        await tester.pump();
        expect(monthCompleter.isCompleted, isFalse,
            reason: '8月個月曆 request 應該已經出發、但仲未完成');

        // 月曆 response 仲未返，用戶手快撳咗日 16：觸發
        // _loadSelectedDayEvents()，呢個 day query 即刻返、完成咗。
        await tester.tap(find.text('16'));
        await tester.pumpAndSettle();

        // 月曆嘅 response 遲啲至返到——帶住 8月5日嘅一個真實 event。
        monthCompleter.complete(json.encode([
          {
            'eventId': 'e-aug5',
            'calendarId': 'cal1',
            'eventTitle': '八月五號活動',
            'eventStartDate':
                DateTime.utc(2026, 8, 5, 10, 0).millisecondsSinceEpoch,
            'eventEndDate':
                DateTime.utc(2026, 8, 5, 11, 0).millisecondsSinceEpoch,
            'eventAllDay': false,
          },
        ]));
        await tester.pumpAndSettle();

        // 月曆嘅正確 event data 一到，grid 應該即刻顯示 8月5日有行程
        // 橫條——就算中間有個唔相關嘅日 load 完成咗，都唔應該畀個月
        // load 嘅結果畀誤判做「過時」而靜靜咁被捨棄。
        final colors = XuanLiTheme.light().extension<XuanLiColors>()!;
        final eventBarFinder = find.byWidgetPredicate((w) =>
            w is Container &&
            w.constraints?.maxHeight == 2.5 &&
            w.decoration is BoxDecoration &&
            (w.decoration as BoxDecoration).color == colors.ink60);

        final day5Cell = find.ancestor(
          of: find.text('5'),
          matching: find.byType(GestureDetector),
        );

        expect(find.descendant(of: day5Cell, matching: eventBarFinder), findsOneWidget);
      },
    );

    testWidgets(
      '揀第二個月（8月）入面有 event 嗰日：真係經 CalendarScreen → '
      'CalendarSyncService → CalendarGrid 成條路查，grid 格仔會顯示行程橫條'
      '（唔係 widgets-only test 嗰種 hand-construct CalendarCellData）',
      (tester) async {
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(DeviceCalendarPlugin.channel, (call) async {
          switch (call.method) {
            case 'hasPermissions':
            case 'requestPermissions':
              return true;
            case 'retrieveCalendars':
              return json.encode([
                {'id': 'cal1', 'name': 'Personal', 'isReadOnly': false, 'isDefault': true},
              ]);
            case 'retrieveEvents':
              final args = Map<String, dynamic>.from(call.arguments as Map);
              final startMs = args['startDate'] as int;
              final endMs = args['endDate'] as int;
              final start = DateTime.fromMillisecondsSinceEpoch(startMs, isUtc: true);
              final end = DateTime.fromMillisecondsSinceEpoch(endMs, isUtc: true);
              final eventStart = DateTime.utc(2026, 8, 5, 10, 0);
              if (!eventStart.isBefore(start) && eventStart.isBefore(end)) {
                return json.encode([
                  {
                    'eventId': 'e-aug5',
                    'calendarId': 'cal1',
                    'eventTitle': '八月五號活動',
                    'eventStartDate': eventStart.millisecondsSinceEpoch,
                    'eventEndDate':
                        DateTime.utc(2026, 8, 5, 11, 0).millisecondsSinceEpoch,
                    'eventAllDay': false,
                  },
                ]);
              }
              return json.encode([]);
            default:
              return null;
          }
        });

        await tester.pumpWidget(wrap(CalendarScreen(
          profile: profile,
          today: DateTime(2026, 7, 11),
        )));
        await tester.pumpAndSettle();

        await tester.tap(find.text('›'));
        await tester.pumpAndSettle();

        expect(find.textContaining('2026年8月'), findsOneWidget);

        final colors = XuanLiTheme.light().extension<XuanLiColors>()!;
        final eventBarFinder = find.byWidgetPredicate((w) =>
            w is Container &&
            w.constraints?.maxHeight == 2.5 &&
            w.decoration is BoxDecoration &&
            (w.decoration as BoxDecoration).color == colors.ink60);

        final day5Cell = find.ancestor(
          of: find.text('5'),
          matching: find.byType(GestureDetector),
        );
        final day6Cell = find.ancestor(
          of: find.text('6'),
          matching: find.byType(GestureDetector),
        );

        expect(find.descendant(of: day5Cell, matching: eventBarFinder), findsOneWidget);
        expect(find.descendant(of: day6Cell, matching: eventBarFinder), findsNothing);
      },
    );
  });
}
