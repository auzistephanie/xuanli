import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xuanli/widgets/flip_reveal.dart';

void main() {
  Widget wrap(Widget c) => MaterialApp(home: Scaffold(body: Center(child: c)));

  testWidgets('開始顯示背面，翻完顯示正面', (tester) async {
    await tester.pumpWidget(wrap(const FlipReveal(back: Text('背'), front: Text('正'))));
    expect(find.text('背'), findsOneWidget);
    expect(find.text('正'), findsNothing);
    await tester.pumpAndSettle();
    expect(find.text('正'), findsOneWidget);
    expect(find.text('背'), findsNothing);
  });

  testWidgets('減少動態效果 → 即刻正面', (tester) async {
    await tester.pumpWidget(wrap(const MediaQuery(
      data: MediaQueryData(disableAnimations: true),
      child: FlipReveal(back: Text('背'), front: Text('正')),
    )));
    expect(find.text('正'), findsOneWidget);
  });
}
