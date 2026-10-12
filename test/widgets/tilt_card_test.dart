import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xuanli/widgets/tilt_card.dart';

void main() {
  Widget wrap(Widget c) => MaterialApp(home: Scaffold(body: Center(child: c)));

  Matrix4 transformOf(WidgetTester t) =>
      t.widget<Transform>(find.byKey(TiltCard.transformKey)).transform;

  testWidgets('初始冇傾斜', (tester) async {
    await tester.pumpWidget(wrap(const TiltCard(child: SizedBox(width: 200, height: 120))));
    expect(transformOf(tester).entry(0, 2), 0);
  });

  testWidgets('拖去右邊 → 繞 Y 轉；放手回正', (tester) async {
    await tester.pumpWidget(wrap(const TiltCard(child: SizedBox(width: 200, height: 120))));
    final center = tester.getCenter(find.byType(TiltCard));
    final g = await tester.startGesture(center);
    await g.moveTo(center + const Offset(90, 0));
    await tester.pump();
    expect(transformOf(tester).entry(0, 2), isNot(0));
    await g.up();
    await tester.pumpAndSettle();
    expect(transformOf(tester).entry(0, 2), closeTo(0, 1e-6));
  });

  testWidgets('child 照常顯示', (tester) async {
    await tester.pumpWidget(wrap(const TiltCard(child: Text('組合'))));
    expect(find.text('組合'), findsOneWidget);
  });

  testWidgets('喺卡上面垂直拖，外面嘅 scroll view 照樣 scroll（唔搶手勢）', (tester) async {
    final controller = ScrollController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          controller: controller,
          child: const Column(children: [
            TiltCard(child: SizedBox(width: 300, height: 300)),
            SizedBox(height: 2000),
          ]),
        ),
      ),
    ));
    await tester.drag(find.byType(TiltCard), const Offset(0, -200));
    await tester.pumpAndSettle();
    expect(controller.offset, greaterThan(100));
  });

  testWidgets('減少動態效果：放手即刻回正，唔使等動畫', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: MediaQuery(
        data: MediaQueryData(disableAnimations: true),
        child: Scaffold(body: Center(child: TiltCard(child: SizedBox(width: 200, height: 120)))),
      ),
    ));
    final center = tester.getCenter(find.byType(TiltCard));
    final g = await tester.startGesture(center);
    await g.moveTo(center + const Offset(90, 0));
    await tester.pump();
    expect(transformOf(tester).entry(0, 2), isNot(0));
    await g.up();
    await tester.pump();
    expect(transformOf(tester).entry(0, 2), 0);
    expect(tester.hasRunningAnimations, isFalse);
  });
}
