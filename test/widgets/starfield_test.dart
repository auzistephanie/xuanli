import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xuanli/theme/motion.dart';
import 'package:xuanli/widgets/starfield.dart';

void main() {
  tearDown(() => Motion.ambientEnabled = false);

  test('starSpecs deterministic，位置喺 0–1', () {
    final a = starSpecs(46);
    final b = starSpecs(46);
    expect(a.length, 46);
    for (var i = 0; i < a.length; i++) {
      expect(a[i].x, b[i].x);
      expect(a[i].y, b[i].y);
      expect(a[i].x, inInclusiveRange(0, 1));
      expect(a[i].y, inInclusiveRange(0, 1));
    }
  });

  testWidgets('環境動畫關咗 → 靜止，冇 running animation', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: Starfield()));
    expect(find.byType(Starfield), findsOneWidget);
    expect(tester.hasRunningAnimations, isFalse);
  });

  testWidgets('環境動畫開咗 → 會閃', (tester) async {
    Motion.ambientEnabled = true;
    await tester.pumpWidget(const MaterialApp(home: Starfield()));
    await tester.pump(const Duration(milliseconds: 100));
    expect(tester.hasRunningAnimations, isTrue);
    await tester.pumpWidget(const SizedBox()); // dispose ticker
  });
}
