import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xuanli/engine/profile_builder.dart';
import 'package:xuanli/models/combo.dart';
import 'package:xuanli/screens/combo/combo_screen.dart';
import 'package:xuanli/theme/xuanli_theme.dart';
import 'package:xuanli/widgets/tilt_card.dart';
import 'package:xuanli/widgets/wuxing_orbs.dart';

void main() {
  setUpAll(() {
    initCombos(File('lib/data/combos.json').readAsStringSync());
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

  // 第二個 fixture：驗證另一個 dayGan_MBTI 組合鍵，避免 lookup bug（錯柱/錯 substring）
  // 剛好都撞中「乙_ISFP」都仍然過。1999-09-20 09:30 已知 dayGan=乙；
  // 2000-01-07 09:30 已驗證 dayGan=甲（見 pillars[2]/dayMaster），配 mbti=INTJ
  // 對應 combos.json 嘅 '甲_INTJ'：宮職「軍師」。
  final profile2 = buildProfile(
    id: 'p2',
    name: '阿甲',
    birthDate: DateTime(2000, 1, 7),
    birthHour: 9,
    birthMinute: 30,
    birthPlace: '香港',
    mbti: 'INTJ',
  );

  testWidgets('顯示乙_ISFP嘅組合內容：組合名/motto/優勢/留意位/點樣發力/稀有度', (tester) async {
    await tester.pumpWidget(wrap(ComboDetailScreen(profile: profile)));

    expect(find.text('我嘅組合'), findsOneWidget);
    expect(find.textContaining('乙木日主'), findsOneWidget);
    expect(find.textContaining('ISFP'), findsWidgets);
    expect(find.text('御用畫師'), findsOneWidget);
    expect(find.textContaining('看顏色、質地和細節'), findsOneWidget);
    expect(find.textContaining('同一件衣服'), findsOneWidget);
    expect(find.text('日常寫照'), findsOneWidget);
    expect(find.text('你的盲點'), findsOneWidget);
    expect(find.textContaining('視覺設計師'), findsOneWidget);
    expect(find.textContaining('御前顧問'), findsOneWidget);
    expect(find.text('約 0.88%'), findsOneWidget);
    expect(find.textContaining('每 114 人'), findsOneWidget);
    expect(find.textContaining('估算'), findsOneWidget);
    expect(find.textContaining('即將推出'), findsNothing);
  });

  testWidgets('顯示甲_INTJ嘅組合內容：唔同 dayGan/MBTI 都要揀返啱嘅組合（防 lookup key bug）', (tester) async {
    await tester.pumpWidget(wrap(ComboDetailScreen(profile: profile2)));

    expect(find.text('我嘅組合'), findsOneWidget);
    expect(find.textContaining('甲木日主'), findsOneWidget);
    expect(find.textContaining('INTJ'), findsWidgets);
    expect(find.text('軍師'), findsOneWidget);
    expect(find.textContaining('看長遠的棋'), findsOneWidget);
    expect(find.textContaining('兩年後這件事還成不成立'), findsOneWidget);
  });

  testWidgets('撳返、撳分享 icon：返會 pop，分享會開分享卡預覽頁', (tester) async {
    await tester.pumpWidget(wrap(Builder(builder: (context) {
      return Scaffold(
        body: Center(
          child: ElevatedButton(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => ComboDetailScreen(profile: profile)),
            ),
            child: const Text('open'),
          ),
        ),
      );
    })));

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.text('御用畫師'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.ios_share));
    await tester.pump();
    await tester.pumpAndSettle();
    expect(find.text('分享我嘅組合'), findsOneWidget);
    expect(find.text('分享'), findsOneWidget);

    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.tap(find.text('‹'));
    await tester.pumpAndSettle();
    expect(find.text('open'), findsOneWidget);
    expect(find.text('御用畫師'), findsNothing);
  });

  testWidgets('組合名卡可傾斜，有五行晶球', (tester) async {
    await tester.pumpWidget(wrap(ComboDetailScreen(profile: profile)));
    expect(find.byType(TiltCard), findsOneWidget);
    expect(find.byType(WuxingOrbs), findsOneWidget);
  });
}
