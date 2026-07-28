import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xuanli/engine/profile_builder.dart';
import 'package:xuanli/models/combo.dart';
import 'package:xuanli/screens/combo/combo_screen.dart';
import 'package:xuanli/theme/xuanli_theme.dart';

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
  // 對應 combos.json 嘅 '甲_INTJ'：name='雪嶺孤松', motto='立志如山・落子無聲'。
  final profile2 = buildProfile(
    id: 'p2',
    name: '阿甲',
    birthDate: DateTime(2000, 1, 7),
    birthHour: 9,
    birthMinute: 30,
    birthPlace: '香港',
    mbti: 'INTJ',
  );

  testWidgets('顯示乙_ISFP嘅組合內容：組合名/motto/優勢/留意位/點樣發力/稀有度佔位', (tester) async {
    await tester.pumpWidget(wrap(ComboDetailScreen(profile: profile)));

    expect(find.text('我嘅組合'), findsOneWidget);
    expect(find.textContaining('乙木日主'), findsOneWidget);
    expect(find.textContaining('ISFP'), findsWidgets);
    expect(find.text('林間清泉'), findsOneWidget);
    expect(find.textContaining('柔韌有光'), findsOneWidget);
    expect(find.textContaining('審美同直覺俱佳'), findsOneWidget);
    expect(find.textContaining('諗多過講'), findsOneWidget);
    expect(find.textContaining('水木旺嘅日子'), findsOneWidget);
    expect(find.textContaining('即將推出'), findsOneWidget);
  });

  testWidgets('顯示甲_INTJ嘅組合內容：唔同 dayGan/MBTI 都要揀返啱嘅組合（防 lookup key bug）', (tester) async {
    await tester.pumpWidget(wrap(ComboDetailScreen(profile: profile2)));

    expect(find.text('我嘅組合'), findsOneWidget);
    expect(find.textContaining('甲木日主'), findsOneWidget);
    expect(find.textContaining('INTJ'), findsWidgets);
    expect(find.text('雪嶺孤松'), findsOneWidget);
    expect(find.textContaining('立志如山・落子無聲'), findsOneWidget);
  });

  testWidgets('撳返、撳分享 icon：返會 pop，分享會顯示 stub SnackBar', (tester) async {
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
    expect(find.text('林間清泉'), findsOneWidget);

    await tester.tap(find.text('⇪'));
    await tester.pump();
    expect(find.textContaining('第二版先做'), findsOneWidget);

    await tester.tap(find.text('‹'));
    await tester.pumpAndSettle();
    expect(find.text('open'), findsOneWidget);
    expect(find.text('林間清泉'), findsNothing);
  });
}
