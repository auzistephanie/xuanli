import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xuanli/engine/almanac.dart';
import 'package:xuanli/engine/copywriter.dart';
import 'package:xuanli/engine/profile_builder.dart';
import 'package:xuanli/screens/today/today_screen.dart';
import 'package:xuanli/theme/xuanli_theme.dart';
import 'package:xuanli/widgets/orrery.dart';

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

  testWidgets('顯示 2026-07-11（丙戌平日）golden fixture 嘅日期/干支/雙環/宜忌', (tester) async {
    await tester.pumpWidget(
      wrap(TodayScreen(profile: profile, initialDate: DateTime(2026, 7, 11))),
    );

    expect(find.textContaining('7月11日'), findsOneWidget);
    expect(find.textContaining('五月廿七'), findsOneWidget);
    expect(find.textContaining('丙戌'), findsWidgets);
    expect(find.textContaining('沖龍煞北'), findsOneWidget);
    expect(find.text('祭祀'), findsOneWidget);
  });

  testWidgets('撳未來七日條入面第二日，畫面內容轉去嗰日', (tester) async {
    await tester.pumpWidget(
      wrap(TodayScreen(profile: profile, initialDate: DateTime(2026, 7, 11))),
    );

    expect(find.textContaining('7月11日'), findsOneWidget);

    // 今日一籤卡令七日條推低咗，先 scroll 入畫面先撳得中。
    await tester.ensureVisible(find.text('12'));
    await tester.tap(find.text('12'));
    await tester.pumpAndSettle();

    expect(find.textContaining('7月12日'), findsOneWidget);
    expect(find.textContaining('五月廿八'), findsOneWidget);
  });

  testWidgets('今日頁：天體儀中心顯示命理分，旁邊細環顯示契合度，header 有 Kairo', (tester) async {
    await tester.pumpWidget(
      wrap(TodayScreen(profile: profile, initialDate: DateTime(2026, 7, 20))),
    );
    await tester.pumpAndSettle();
    expect(find.byType(Orrery), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(Orrery),
        matching: find.textContaining('命理分'),
      ),
      findsOneWidget,
    );
    expect(find.textContaining('狀態契合'), findsOneWidget);
    expect(find.text('Kairo'), findsOneWidget);
  });

  testWidgets('今日頁 360×640 唔 overflow', (tester) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      wrap(TodayScreen(profile: profile, initialDate: DateTime(2026, 7, 20))),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
