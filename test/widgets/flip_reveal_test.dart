import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xuanli/widgets/flip_reveal.dart';

void main() {
  Widget wrap(Widget c) => MaterialApp(home: Scaffold(body: Center(child: c)));

  testWidgets('開始顯示背面，翻完顯示正面', (tester) async {
    // 正面一直都 layout（尺寸跟正面），未翻到之前用 Opacity 0 收埋。
    double frontOpacity() => tester
        .widget<Opacity>(find.ancestor(of: find.text('正'), matching: find.byType(Opacity)).first)
        .opacity;

    await tester.pumpWidget(wrap(const FlipReveal(back: Text('背'), front: Text('正'))));
    expect(find.text('背'), findsOneWidget);
    expect(frontOpacity(), 0);
    await tester.pumpAndSettle();
    expect(frontOpacity(), 1);
    expect(find.text('背'), findsNothing);
  });

  testWidgets('減少動態效果 → 即刻正面', (tester) async {
    await tester.pumpWidget(wrap(const MediaQuery(
      data: MediaQueryData(disableAnimations: true),
      child: FlipReveal(back: Text('背'), front: Text('正')),
    )));
    expect(find.text('背'), findsNothing);
    expect(find.text('正'), findsOneWidget);
  });

  testWidgets('翻卡期間尺寸一直等於正面', (tester) async {
    const front = SizedBox(width: 200, height: 300, child: Text('正'));
    await tester.pumpWidget(wrap(const FlipReveal(back: SizedBox(width: 10, height: 10), front: front)));
    expect(tester.getSize(find.byType(FlipReveal)), const Size(200, 300));
    await tester.pump(const Duration(milliseconds: 450));
    expect(tester.getSize(find.byType(FlipReveal)), const Size(200, 300));
    await tester.pumpAndSettle();
  });
}
