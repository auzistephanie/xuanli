// test/theme/motion_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xuanli/theme/motion.dart';

void main() {
  tearDown(() => Motion.ambientEnabled = false);

  Future<bool> ambientIn(WidgetTester tester, {required bool disable}) async {
    late bool result;
    await tester.pumpWidget(MediaQuery(
      data: MediaQueryData(disableAnimations: disable),
      child: Builder(builder: (c) {
        result = Motion.ambient(c);
        return const SizedBox();
      }),
    ));
    return result;
  }

  testWidgets('測試環境預設關環境動畫（flutter_test_config）', (tester) async {
    expect(Motion.ambientEnabled, isFalse);
    expect(await ambientIn(tester, disable: false), isFalse);
  });

  testWidgets('開咗 ambientEnabled、冇減少動態 → true', (tester) async {
    Motion.ambientEnabled = true;
    expect(await ambientIn(tester, disable: false), isTrue);
  });

  testWidgets('系統減少動態效果 → 永遠 false', (tester) async {
    Motion.ambientEnabled = true;
    expect(await ambientIn(tester, disable: true), isFalse);
  });
}
