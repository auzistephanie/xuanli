import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:xuanli/engine/activity.dart';
import 'package:xuanli/engine/copywriter.dart';
import 'package:xuanli/engine/almanac.dart';
import 'package:xuanli/screens/onboarding/onboarding_flow.dart';
import 'package:xuanli/screens/tab_shell.dart';
import 'package:xuanli/theme/xuanli_theme.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // 行完呢個 flow 會落地喺 TabShell，佢 index 0/1 分別掛真嘅
  // TodayScreen（2c 起）同 ActivityScreen（2d 起）——同
  // tab_shell_test.dart 一樣要提前初始化呢三個 JSON-backed cache，
  // 否則最後一步 build TabShell（IndexedStack 會連 index 1 都一齊
  // build）就會 throw StateError。
  setUpAll(() {
    initMbtiTones(File('lib/data/mbti_tones.json').readAsStringSync());
    initActivityCategories(
      File('lib/data/activity_categories.json').readAsStringSync(),
    );
    initActivities(File('lib/data/activities.json').readAsStringSync());
  });

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('行完 3 步（用預設出生資料 + 16 宮格揀 ISFP）會跳去 TabShell', (tester) async {
    // `theme:` required — see birth_data_step_test.dart's wrap() note;
    // every step OnboardingFlow renders needs context.xuanliColors present.
    await tester.pumpWidget(MaterialApp(theme: XuanLiTheme.light(), home: const OnboardingFlow()));

    // Step 1: 出生資料，用晒預設值直接下一步。
    expect(find.text('你嘅出生一刻'), findsOneWidget);
    await tester.tap(find.text('下一步'));
    await tester.pumpAndSettle();

    // Step 2: MBTI，16 宮格揀 ISFP。
    expect(find.text('你嘅性格底色'), findsOneWidget);
    // 16 宮格 + 標題等內容喺預設 800x600 test viewport 高過個 viewport
    // （同 mbti_step_test.dart 個 wrap() 註解講嘅一樣），要靠嗰層
    // SingleChildScrollView 先睇到落面嘅選項——所以 tap 之前要
    // ensureVisible() 幫手 scroll 埋去，先撳得中。冇呢兩行嘅話兩下 tap
    // 都會 "not hit test"（offset 喺 viewport 外），揀選同下一步都冧唔到，
    // 跟住 Step 3 嗰句 expect 就會搵唔到「你嘅命理檔案」。
    await tester.ensureVisible(find.text('ISFP'));
    await tester.tap(find.text('ISFP'));
    await tester.pump();
    await tester.ensureVisible(find.text('下一步'));
    await tester.tap(find.text('下一步'));
    await tester.pumpAndSettle();

    // Step 3: 檔案卡，撳「開始睇今日」。
    expect(find.text('你嘅命理檔案'), findsOneWidget);
    await tester.tap(find.text('開始睇今日'));
    await tester.pumpAndSettle();

    expect(find.byType(TabShell), findsOneWidget);
  });
}
