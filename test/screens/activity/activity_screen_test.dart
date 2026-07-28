import 'dart:io';

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
}
