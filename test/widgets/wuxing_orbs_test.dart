import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xuanli/widgets/wuxing_orbs.dart';

void main() {
  testWidgets('五個晶球按木火土金水排，顯示百分比，大細跟比例', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(body: WuxingOrbs(wuxing: {'木': 40, '火': 10, '土': 20, '金': 10, '水': 20})),
    ));
    for (final e in ['木', '火', '土', '金', '水']) {
      expect(find.text(e), findsOneWidget);
    }
    expect(find.text('40%'), findsOneWidget);
    final wood = tester.getSize(find.byKey(const ValueKey('orb-木')));
    final fire = tester.getSize(find.byKey(const ValueKey('orb-火')));
    expect(wood.width, greaterThan(fire.width));
    expect(tester.getCenter(find.text('木')).dx, lessThan(tester.getCenter(find.text('水')).dx));
  });

  testWidgets('缺咗某行當 0%', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: Scaffold(body: WuxingOrbs(wuxing: {'木': 100}))));
    expect(find.text('0%'), findsNWidgets(4));
  });
}
