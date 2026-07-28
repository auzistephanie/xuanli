import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xuanli/screens/onboarding/birth_data_step.dart';
import 'package:xuanli/theme/xuanli_theme.dart';

void main() {
  // `theme:` matters here, not just cosmetics — every onboarding widget
  // reads `context.xuanliColors`, which requires XuanLiTheme's
  // ThemeExtension to be present on the ambient theme (same as main.dart
  // always provides it). Without this, the very first themed widget
  // throws a null-check failure before any test assertion runs.
  Widget wrap(Widget child) =>
      MaterialApp(theme: XuanLiTheme.light(), home: Scaffold(body: child));

  testWidgets('顯示標題、預設地點「香港」，下一步預設可撳', (tester) async {
    var nextCalled = false;
    await tester.pumpWidget(wrap(BirthDataStep(
      isLunar: false,
      birthDate: DateTime(1999, 9, 20),
      birthHour: 9,
      birthMinute: 30,
      birthTimeUnknown: false,
      birthPlace: '香港',
      onChanged: (_) {},
      onNext: () => nextCalled = true,
    )));

    expect(find.text('你嘅出生一刻'), findsOneWidget);
    expect(find.text('香港'), findsOneWidget);

    await tester.tap(find.text('下一步'));
    await tester.pump();
    expect(nextCalled, isTrue);
  });

  testWidgets('顯示時辰中文名（09:30 -> 巳時）', (tester) async {
    await tester.pumpWidget(wrap(BirthDataStep(
      isLunar: false,
      birthDate: DateTime(1999, 9, 20),
      birthHour: 9,
      birthMinute: 30,
      birthTimeUnknown: false,
      birthPlace: '香港',
      onChanged: (_) {},
      onNext: () {},
    )));

    expect(find.textContaining('巳時'), findsOneWidget);
  });

  testWidgets('撳「我唔清楚出生時間」toggle 會通知 onChanged(birthTimeUnknown: true)', (tester) async {
    BirthDataState? changed;
    await tester.pumpWidget(wrap(BirthDataStep(
      isLunar: false,
      birthDate: DateTime(1999, 9, 20),
      birthHour: 9,
      birthMinute: 30,
      birthTimeUnknown: false,
      birthPlace: '香港',
      onChanged: (s) => changed = s,
      onNext: () {},
    )));

    await tester.tap(find.text('我唔清楚出生時間'));
    await tester.pump();

    expect(changed, isNotNull);
    expect(changed!.birthTimeUnknown, isTrue);
  });

  testWidgets('撳「農曆」segmented toggle 會通知 onChanged(isLunar: true)', (tester) async {
    BirthDataState? changed;
    await tester.pumpWidget(wrap(BirthDataStep(
      isLunar: false,
      birthDate: DateTime(1999, 9, 20),
      birthHour: 9,
      birthMinute: 30,
      birthTimeUnknown: false,
      birthPlace: '香港',
      onChanged: (s) => changed = s,
      onNext: () {},
    )));

    await tester.tap(find.text('農曆'));
    await tester.pump();

    expect(changed, isNotNull);
    expect(changed!.isLunar, isTrue);
  });

  testWidgets('撳出生地點 -> 對話框輸入新地點 -> 確定 會通知 onChanged(birthPlace: 新值)', (tester) async {
    BirthDataState? changed;
    await tester.pumpWidget(wrap(BirthDataStep(
      isLunar: false,
      birthDate: DateTime(1999, 9, 20),
      birthHour: 9,
      birthMinute: 30,
      birthTimeUnknown: false,
      birthPlace: '香港',
      onChanged: (s) => changed = s,
      onNext: () {},
    )));

    await tester.tap(find.text('香港'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), '台北');
    await tester.tap(find.text('確定'));
    await tester.pumpAndSettle();

    expect(changed, isNotNull);
    expect(changed!.birthPlace, '台北');
  });
}
