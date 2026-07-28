import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xuanli/engine/almanac.dart';
import 'package:xuanli/engine/copywriter.dart';
import 'package:xuanli/engine/profile_builder.dart';
import 'package:xuanli/screens/calendar/calendar_screen.dart';
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
}
