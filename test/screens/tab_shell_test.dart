import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xuanli/engine/activity.dart';
import 'package:xuanli/engine/copywriter.dart';
import 'package:xuanli/engine/almanac.dart';
import 'package:xuanli/models/profile.dart';
import 'package:xuanli/screens/tab_shell.dart';
import 'package:xuanli/theme/xuanli_theme.dart';

Profile _sampleProfile() => Profile(
      id: 'p1',
      name: '阿玄',
      birthDate: DateTime(1999, 9, 20),
      birthHour: 9,
      birthPlace: '香港',
      mbti: 'ISFP',
      pillars: const ['己卯', '癸酉', '乙亥', '辛巳'],
      wuxing: const {'木': 30, '火': 14, '土': 13, '金': 15, '水': 28},
      favorable: const ['水', '木'],
      unfavorable: const ['金', '土'],
      dayMaster: '乙木',
      ziweiStar: '太陰',
      zodiac: '兔',
    );

void main() {
  // TabShell 現時 index 0/1 分別掛真嘅 TodayScreen（2c 起）同
  // ActivityScreen（2d 起），兩者都會 call 到要求 JSON-backed cache
  // 已初始化嘅 engine function，否則一 build 就 throw StateError（見
  // today_screen_test.dart / activity_screen_test.dart 用緊嘅同一套
  // setUpAll pattern）。initActivities() 係 Tab B 新加嘅一個 —
  // ActivityScreen.build() 會直接 call loadActivities()。
  setUpAll(() {
    initMbtiTones(File('lib/data/mbti_tones.json').readAsStringSync());
    initActivityCategories(
      File('lib/data/activity_categories.json').readAsStringSync(),
    );
    initActivities(File('lib/data/activities.json').readAsStringSync());
  });

  Widget wrap(Widget child) =>
      MaterialApp(theme: XuanLiTheme.light(), home: child);

  testWidgets('預設揀第一個 tab（今日），撳第二個 tab 會切換', (tester) async {
    await tester.pumpWidget(wrap(TabShell(profile: _sampleProfile())));

    expect(find.text('今日'), findsOneWidget);
    expect(find.text('我想做'), findsOneWidget);
    expect(find.text('月曆'), findsOneWidget);

    await tester.tap(find.text('我想做'));
    await tester.pump();

    expect(find.text('我想做⋯'), findsOneWidget);
  });

  testWidgets('撳第三個 tab（月曆）都會切換', (tester) async {
    await tester.pumpWidget(wrap(TabShell(profile: _sampleProfile())));

    await tester.tap(find.text('月曆'));
    await tester.pump();

    expect(find.text('日'), findsWidgets); // CalendarScreen 嘅 weekday header
    expect(find.text('Tab C — 2e 起'), findsNothing); // placeholder 已經真係冧咗
  });

  testWidgets('揀中嘅 tab 用朱紅色+粗體，未揀中嘅用淡墨色', (tester) async {
    await tester.pumpWidget(wrap(TabShell(profile: _sampleProfile())));

    final colors = XuanLiTheme.light().extension<XuanLiColors>()!;

    Text labelText(String label) => tester.widget<Text>(find.text(label));

    expect(labelText('今日').style?.color, colors.red);
    expect(labelText('今日').style?.fontWeight, FontWeight.w700);
    expect(labelText('我想做').style?.color, colors.ink60);
    expect(labelText('我想做').style?.fontWeight, FontWeight.w400);

    await tester.tap(find.text('我想做'));
    await tester.pump();

    expect(labelText('今日').style?.color, colors.ink60);
    expect(labelText('我想做').style?.color, colors.red);
  });
}
