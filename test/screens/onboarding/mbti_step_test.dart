import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xuanli/screens/onboarding/mbti_step.dart';
import 'package:xuanli/theme/xuanli_theme.dart';

void main() {
  // See birth_data_step_test.dart's wrap() for why `theme:` is required
  // here, not optional — context.xuanliColors needs it present.
  Widget wrap(Widget child) =>
      MaterialApp(theme: XuanLiTheme.light(), home: Scaffold(body: child));

  testWidgets('16 宮格模式：撳一個型別再撳下一步，callback 攞返嗰個型別', (tester) async {
    String? result;
    await tester.pumpWidget(wrap(MbtiStep(onDone: (mbti) => result = mbti)));

    expect(find.text('你嘅性格底色'), findsOneWidget);
    // 16 宮格 + 標題等內容喺預設 800x600 test viewport 高過個 viewport，
    // 同真機一樣要靠嗰層 SingleChildScrollView 先睇到落面嘅選項——所以
    // tap 之前要 ensureVisible() 幫手 scroll 埋去，先撳得中。
    await tester.ensureVisible(find.text('ISFP'));
    await tester.tap(find.text('ISFP'));
    await tester.pump();
    await tester.ensureVisible(find.text('下一步'));
    await tester.tap(find.text('下一步'));
    await tester.pump();

    expect(result, 'ISFP');
  });

  testWidgets('切去快速測驗模式，答晒 8 題之後自動計出型別', (tester) async {
    String? result;
    await tester.pumpWidget(wrap(MbtiStep(onDone: (mbti) => result = mbti)));

    await tester.tap(find.text('快速測驗（8題）'));
    await tester.pump();
    expect(find.textContaining('第 1 / 8 題'), findsOneWidget);

    // 答晒 8 題，每次揀第一個選項（optionA）。
    for (var i = 0; i < 8; i++) {
      // 揀本題嘅 optionA：用 ValueKey 揾住兩個選項入面第一個（optionA 喺上面）。
      await tester.tap(find.byKey(const ValueKey('mbti-quiz-option-a')));
      await tester.pump();
    }

    expect(result, isNotNull);
    expect(result!.length, 4);
  });
}
