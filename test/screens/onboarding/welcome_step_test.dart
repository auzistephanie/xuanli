import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xuanli/screens/onboarding/welcome_step.dart';
import 'package:xuanli/theme/xuanli_theme.dart';

void main() {
  Widget wrap({VoidCallback? onStart, bool disableAnimations = false}) {
    return MaterialApp(
      theme: XuanLiTheme.light(),
      home: MediaQuery(
        data: MediaQueryData(disableAnimations: disableAnimations),
        child: Scaffold(body: WelcomeStep(onStart: onStart ?? () {})),
      ),
    );
  }

  testWidgets('封面講清楚 Kairo 係咩：標題、三個賣點、私隱同免責', (tester) async {
    await tester.pumpWidget(wrap());
    await tester.pumpAndSettle();

    expect(find.text('Kairo'), findsOneWidget);
    expect(find.textContaining('160 個組合'), findsOneWidget);
    expect(find.textContaining('每日宜忌'), findsOneWidget);
    expect(find.textContaining('出生資料唔離你部機'), findsOneWidget);
    expect(find.textContaining('僅供參考'), findsOneWidget);
    expect(find.text('睇我嘅組合'), findsOneWidget);
  });

  testWidgets('撳「睇我嘅組合」觸發 onStart', (tester) async {
    var started = 0;
    await tester.pumpWidget(wrap(onStart: () => started++));
    await tester.pumpAndSettle();

    await tester.tap(find.text('睇我嘅組合'));
    expect(started, 1);
  });

  testWidgets('減少動態效果：一開始就全部顯示', (tester) async {
    await tester.pumpWidget(wrap(disableAnimations: true));
    await tester.pump();

    final opacity = tester.widget<Opacity>(
      find.ancestor(of: find.text('睇我嘅組合'), matching: find.byType(Opacity)).first,
    );
    expect(opacity.opacity, 1);
  });

  testWidgets('矮屏幕（橫向手機）都可以捲動，唔會 overflow', (tester) async {
    tester.view.physicalSize = const Size(800, 360);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(wrap());
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    await tester.scrollUntilVisible(find.text('睇我嘅組合'), 100);
    expect(find.text('睇我嘅組合'), findsOneWidget);
  });
}
