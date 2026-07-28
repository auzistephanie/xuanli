import 'dart:convert';
import 'dart:io';

import 'package:device_calendar/device_calendar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xuanli/engine/activity.dart';
import 'package:xuanli/engine/almanac.dart';
import 'package:xuanli/engine/copywriter.dart';
import 'package:xuanli/engine/profile_builder.dart';
import 'package:xuanli/screens/activity/activity_screen.dart';
import 'package:xuanli/theme/xuanli_theme.dart';

void main() {
  setUpAll(() {
    initActivities(File('lib/data/activities.json').readAsStringSync());
    initActivityCategories(
      File('lib/data/activity_categories.json').readAsStringSync(),
    );
    initMbtiTones(File('lib/data/mbti_tones.json').readAsStringSync());
  });

  // 包一層 Scaffold（同真實 app 一致——ActivityScreen 喺 TabShell 入面
  // 一定有 Scaffold 祖先）：新加嘅日曆按鈕會 call
  // `ScaffoldMessenger.of(context).showSnackBar`，冇 Scaffold 祖先會
  // assert 爆（"no descendant Scaffolds to present to"）。舊有 5 個
  // test 冇用到 SnackBar，包多層 Scaffold 唔會影響佢哋嘅行為。
  Widget wrap(Widget child) =>
      MaterialApp(theme: XuanLiTheme.light(), home: Scaffold(body: child));

  final profile = buildProfile(
    id: 'p1',
    name: '阿玄',
    birthDate: DateTime(1999, 9, 20),
    birthHour: 9,
    birthMinute: 30,
    birthPlace: '香港',
    mbti: 'ISFP',
  );

  testWidgets('預設揀第一個活動＋未來一個月，顯示結果卡（有頭卡先有日曆按鈕）', (tester) async {
    await tester.pumpWidget(wrap(ActivityScreen(
      profile: profile,
      today: DateTime(2026, 7, 11),
    )));

    expect(find.text('我想做⋯'), findsOneWidget);
    expect(find.textContaining('★'), findsWidgets);
    expect(find.text('＋ 加入我嘅日曆'), findsOneWidget);
  });

  testWidgets('撳第二個活動 chip，結果卡會跟住轉', (tester) async {
    await tester.pumpWidget(wrap(ActivityScreen(
      profile: profile,
      today: DateTime(2026, 7, 11),
    )));

    final activities = loadActivities();
    await tester.tap(find.text(activities[1].name));
    await tester.pumpAndSettle();

    // 轉咗活動之後，個殼（標題/日曆按鈕）仲要喺度，唔會爆嘢。
    expect(find.text('我想做⋯'), findsOneWidget);
  });

  testWidgets('揀「睇醫生」呢個冧安全線嘅活動，唔會冧到冇結果', (tester) async {
    await tester.pumpWidget(wrap(ActivityScreen(
      profile: profile,
      today: DateTime(2026, 7, 11),
    )));

    // 「睇醫生」排喺 activities.json 第 7 個，喺橫向 scroll 嘅 chip
    // 列表入面可能唔喺預設 800px test viewport 嘅可見範圍——同 Phase 2c
    // MBTI 16 宮格個 test 一樣嘅風險，用 ensureVisible 先撳，唔好假設
    // 一定喺可見範圍。
    await tester.ensureVisible(find.text('睇醫生'));
    await tester.tap(find.text('睇醫生'));
    await tester.pumpAndSettle();

    expect(find.textContaining('★'), findsWidgets);
  });

  testWidgets('撳「三個月」範圍，個殼仲喺度，唔會爆嘢或者卡住', (tester) async {
    await tester.pumpWidget(wrap(ActivityScreen(
      profile: profile,
      today: DateTime(2026, 7, 11),
    )));

    await tester.tap(find.text('三個月'));
    await tester.pumpAndSettle();

    expect(find.text('我想做⋯'), findsOneWidget);
    expect(find.textContaining('★'), findsWidgets);
  });

  testWidgets('預設「剪髮」+ 未來一個月：2026-07-12（丁亥）忌理髮，顯示「已為你避開」', (tester) async {
    await tester.pumpWidget(wrap(ActivityScreen(
      profile: profile,
      today: DateTime(2026, 7, 11),
    )));

    // 剪髮嘅 avoidKeywords=[理髮]；2026-07-12（丁亥定日）通勝忌理髮，
    // 啱啱好喺 today+1，喺任何掃描窗口入面都應該搵到。
    expect(find.textContaining('已為你避開'), findsOneWidget);
    expect(find.textContaining('7月12日'), findsOneWidget);
  });

  group('ActivityScreen — 日曆整合（mocked platform channel）', () {
    tearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(DeviceCalendarPlugin.channel, null);
    });

    // 呢兩個 test 原本打算完全冇 mock platform channel（模擬呢部 Mac
    // 冇 simulator 嘅真實情況，同 `CalendarSyncService` 自己嘅 unit
    // test 一致）。但實測發現：喺 `testWidgets()`（唔係普通 `test()`）
    // 入面，一個完全冇註冊 handler 嘅 platform channel call 會永遠
    // hang 住（唔會好似普通 `test()` context 咁即刻拎到
    // MissingPluginException 靜靜轉做 false）——用一個獨立嘅
    // `testWidgets` reproduction 確認咗呢個 hang 係環境本身嘅行為，
    // 唔係呢個 screen 嘅 code 有 bug。改為明確 mock 個 channel 令
    // hasPermissions/requestPermissions 返 false，同
    // `test/screens/calendar/calendar_screen_test.dart` 嘅
    // 「冇日曆權限」test（第 185 行）用緊一模一樣嘅做法。
    testWidgets('撳「＋ 加入我嘅日曆」：冇日曆權限 → 顯示提示 SnackBar', (tester) async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(DeviceCalendarPlugin.channel, (call) async {
        if (call.method == 'hasPermissions' || call.method == 'requestPermissions') {
          return false;
        }
        return null;
      });

      await tester.pumpWidget(wrap(ActivityScreen(
        profile: profile,
        today: DateTime(2026, 7, 11),
      )));

      await tester.tap(find.text('＋ 加入我嘅日曆'));
      await tester.pumpAndSettle();

      expect(find.textContaining('需要日曆權限'), findsOneWidget);
    });

    testWidgets('撳「當日行程 ›」：冇日曆權限 → dialog 顯示提示文字', (tester) async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(DeviceCalendarPlugin.channel, (call) async {
        if (call.method == 'hasPermissions' || call.method == 'requestPermissions') {
          return false;
        }
        return null;
      });

      await tester.pumpWidget(wrap(ActivityScreen(
        profile: profile,
        today: DateTime(2026, 7, 11),
      )));

      await tester.tap(find.text('當日行程 ›'));
      await tester.pumpAndSettle();

      expect(find.textContaining('冇搵到行程'), findsOneWidget);

      await tester.tap(find.text('知道喇'));
      await tester.pumpAndSettle();
      expect(find.textContaining('冇搵到行程'), findsNothing);
    });

    testWidgets('撳「＋ 加入我嘅日曆」：有權限、有可寫日曆 → 建 event 成功、顯示成功 SnackBar', (tester) async {
      Map<dynamic, dynamic>? sentArgs;
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
          case 'createOrUpdateEvent':
            sentArgs = call.arguments as Map<dynamic, dynamic>;
            return 'new-event-id';
          default:
            return null;
        }
      });

      await tester.pumpWidget(wrap(ActivityScreen(
        profile: profile,
        today: DateTime(2026, 7, 11),
      )));

      await tester.tap(find.text('＋ 加入我嘅日曆'));
      await tester.pumpAndSettle();

      expect(find.textContaining('已加入你嘅日曆'), findsOneWidget);
      expect(sentArgs, isNotNull);
      expect(sentArgs!['eventAllDay'], isTrue);
      expect((sentArgs!['eventTitle'] as String).contains('（玄曆吉日）'), isTrue);
    });
  });
}
