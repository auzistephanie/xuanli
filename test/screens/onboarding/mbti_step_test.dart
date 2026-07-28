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

  testWidgets('quiz 模式入面連續快速撳兩下同一個選項，唔會令題目跳兩級或計錯型', (
    tester,
  ) async {
    String? result;
    await tester.pumpWidget(wrap(MbtiStep(onDone: (mbti) => result = mbti)));

    await tester.tap(find.text('快速測驗（8題）'));
    await tester.pump();
    expect(find.textContaining('第 1 / 8 題'), findsOneWidget);

    // 連續兩下撳第 1 題嘅 optionA，中間刻意冇 pump——呢個先係真正
    // 模擬到「一 frame 入面嘅快速雙擊」競態：GestureDetector.onTap
    // 嘅 closure 喺 build() 嗰陣就閂咗當時嘅 question/_quizIndex，
    // 冇 pump 之前個 rebuild 都未發生，舊 closure 仲喺度、仲食到
    // 呢下第二撳。如果中間加咗 pump()，個 rebuild 就搶先發生咗，
    // 個 bug 就冧唔返。
    await tester.tap(find.byKey(const ValueKey('mbti-quiz-option-a')));
    await tester.tap(find.byKey(const ValueKey('mbti-quiz-option-a')));
    await tester.pump();

    // 冇 guard 嘅話，雙擊會令 _quizIndex 跳咗兩級，變咗第 3 題；
    // 有 guard 就應該淨係郁咗一級，停喺第 2 題。
    expect(find.textContaining('第 2 / 8 題'), findsOneWidget);
    expect(find.textContaining('第 3 / 8 題'), findsNothing);

    // 剩低 7 題正常一次過答，全部揀 optionA。
    for (var i = 0; i < 7; i++) {
      await tester.tap(find.byKey(const ValueKey('mbti-quiz-option-a')));
      await tester.pump();
    }

    // 8 題全部揀 optionA 應該計出 ISTJ（EI/SN/TF/JP 每軸第一題嘅
    // optionALetter）；如果雙擊令答案同題目錯位，呢個型就會唔啱。
    expect(tester.takeException(), isNull);
    expect(result, 'ISTJ');
  });

  testWidgets('quiz 模式入面喺最後一題連續快速撳兩下，唔會 overshoot 或者 crash', (
    tester,
  ) async {
    String? result;
    await tester.pumpWidget(wrap(MbtiStep(onDone: (mbti) => result = mbti)));

    await tester.tap(find.text('快速測驗（8題）'));
    await tester.pump();

    // 頭 7 題正常一次過答。
    for (var i = 0; i < 7; i++) {
      await tester.tap(find.byKey(const ValueKey('mbti-quiz-option-a')));
      await tester.pump();
    }
    expect(find.textContaining('第 8 / 8 題'), findsOneWidget);

    // 最後一題連續撳兩下，中間冇 pump。冇 guard 嘅話，第二下會令
    // _quizAnswers.length 衝過 9，completion check（== 8）匹配唔到，
    // _quizIndex 郁去 8，落一個 build 讀 mbtiQuizQuestions[8] 就
    // RangeError crash。
    await tester.tap(find.byKey(const ValueKey('mbti-quiz-option-a')));
    await tester.tap(find.byKey(const ValueKey('mbti-quiz-option-a')));
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(result, isNotNull);
    expect(result!.length, 4);
    expect(result, 'ISTJ');
  });

  testWidgets('答緊 quiz 第 1 題之後切去 16 宮格模式再切返，會由第 1 題由頭嚟過', (
    tester,
  ) async {
    String? result;
    await tester.pumpWidget(wrap(MbtiStep(onDone: (mbti) => result = mbti)));

    await tester.tap(find.text('快速測驗（8題）'));
    await tester.pump();
    expect(find.textContaining('第 1 / 8 題'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('mbti-quiz-option-a')));
    await tester.pump();
    expect(find.textContaining('第 2 / 8 題'), findsOneWidget);

    // 切去 16 宮格模式。
    await tester.tap(find.text('我知我嘅類型'));
    await tester.pump();
    expect(find.text('你嘅性格底色'), findsOneWidget);

    // 切返去快速測驗模式。
    await tester.tap(find.text('快速測驗（8題）'));
    await tester.pump();

    // 應該由第 1 題由頭嚟過，唔係停喺切換之前答緊嘅第 2 題——
    // 之前 review flag 咗呢個 mode-switch 重置行為冇測試蓋住。
    expect(find.textContaining('第 1 / 8 題'), findsOneWidget);
    expect(find.textContaining('第 2 / 8 題'), findsNothing);
    expect(result, isNull);
  });
}
