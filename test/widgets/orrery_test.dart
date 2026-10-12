import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xuanli/theme/motion.dart';
import 'package:xuanli/widgets/orrery.dart';

void main() {
  tearDown(() => Motion.ambientEnabled = false);
  Widget wrap(Widget c) => MaterialApp(home: Scaffold(body: Center(child: c)));

  testWidgets('尺寸跟 size；核心 child 顯示喺中間', (tester) async {
    await tester.pumpWidget(wrap(const Orrery(size: 220, core: Text('86'))));
    expect(tester.getSize(find.byType(Orrery)), const Size(220, 220));
    expect(find.text('86'), findsOneWidget);
    expect(tester.getCenter(find.text('86')).dx,
        closeTo(tester.getCenter(find.byType(Orrery)).dx, 1));
  });

  testWidgets('冇 core 都 render 到（開機畫面用）', (tester) async {
    await tester.pumpWidget(wrap(const Orrery(size: 160)));
    expect(find.byType(Orrery), findsOneWidget);
  });

  testWidgets('環境動畫關咗：靜止', (tester) async {
    await tester.pumpWidget(wrap(const Orrery()));
    expect(tester.hasRunningAnimations, isFalse);
  });

  testWidgets('環境動畫開咗：轉緊', (tester) async {
    Motion.ambientEnabled = true;
    await tester.pumpWidget(wrap(const Orrery()));
    await tester.pump(const Duration(milliseconds: 200));
    expect(tester.hasRunningAnimations, isTrue);
    await tester.pumpWidget(const SizedBox());
  });
}
