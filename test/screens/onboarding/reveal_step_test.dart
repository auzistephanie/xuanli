import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xuanli/engine/profile_builder.dart';
import 'package:xuanli/models/combo.dart';
import 'package:xuanli/screens/onboarding/reveal_step.dart';
import 'package:xuanli/theme/xuanli_theme.dart';

void main() {
  setUpAll(() {
    initCombos(File('lib/data/combos.json').readAsStringSync());
  });

  final profile = buildProfile(
    id: 'p1',
    name: '阿玄',
    birthDate: DateTime(1999, 9, 20),
    birthHour: 9,
    birthMinute: 30,
    birthPlace: '香港',
    mbti: 'ISFP',
  );

  Widget wrap({
    VoidCallback? onContinue,
    VoidCallback? onShare,
    bool disableAnimations = false,
  }) {
    return MaterialApp(
      theme: XuanLiTheme.light(),
      home: MediaQuery(
        data: MediaQueryData(disableAnimations: disableAnimations),
        child: Scaffold(
          body: RevealStep(
            profile: profile,
            onContinue: onContinue ?? () {},
            onShare: onShare ?? () {},
          ),
        ),
      ),
    );
  }

  double opacityOf(WidgetTester tester, Finder f) => tester
      .widget<Opacity>(find.ancestor(of: f, matching: find.byType(Opacity)).first)
      .opacity;

  testWidgets('動畫行完：組合名逐字、motto、稀有度、兩粒掣都出晒', (tester) async {
    await tester.pumpWidget(wrap());
    await tester.pumpAndSettle();

    for (final ch in ['林', '間', '清', '泉']) {
      expect(find.text(ch), findsOneWidget);
    }
    expect(find.text('乙木日主'), findsOneWidget);
    expect(find.textContaining('柔韌有光'), findsOneWidget);
    expect(find.text('每 114 人先有一個'), findsOneWidget);
    expect(find.text('估算約 0.88%'), findsOneWidget);
    expect(find.text('分享我嘅組合'), findsOneWidget);
    expect(find.text('睇我嘅命理檔案'), findsOneWidget);
  });

  testWidgets('開頭組合名未出現，掣未撳得', (tester) async {
    var continued = false;
    await tester.pumpWidget(wrap(onContinue: () => continued = true));
    await tester.pump(const Duration(milliseconds: 200));

    expect(opacityOf(tester, find.text('林')), 0);
    await tester.tap(find.text('睇我嘅命理檔案'), warnIfMissed: false);
    expect(continued, isFalse);
  });

  testWidgets('撳畫面任何位置會跳到最後', (tester) async {
    await tester.pumpWidget(wrap());
    await tester.pump(const Duration(milliseconds: 300));

    await tester.tapAt(const Offset(200, 100));
    await tester.pump();

    expect(opacityOf(tester, find.text('泉')), 1);
    expect(opacityOf(tester, find.text('分享我嘅組合')), 1);
  });

  testWidgets('減少動態效果：一開始就係最後畫面', (tester) async {
    await tester.pumpWidget(wrap(disableAnimations: true));
    await tester.pump();

    expect(opacityOf(tester, find.text('林')), 1);
    expect(opacityOf(tester, find.text('睇我嘅命理檔案')), 1);
  });

  testWidgets('兩粒掣分別觸發 onShare／onContinue', (tester) async {
    var shared = false;
    var continued = false;
    await tester.pumpWidget(wrap(
      onShare: () => shared = true,
      onContinue: () => continued = true,
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.text('分享我嘅組合'));
    expect(shared, isTrue);
    await tester.tap(find.text('睇我嘅命理檔案'));
    expect(continued, isTrue);
  });
}
