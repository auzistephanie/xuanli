import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:xuanli/services/storage_service.dart';
import 'package:xuanli/screens/onboarding/profile_card_step.dart';
import 'package:xuanli/theme/xuanli_theme.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  // See birth_data_step_test.dart's wrap() for why `theme:` is required
  // here, not optional — context.xuanliColors needs it present.
  Widget wrap(Widget child) =>
      MaterialApp(theme: XuanLiTheme.light(), home: Scaffold(body: child));

  testWidgets('用阿玄嘅出生資料起檔案卡：顯示日主/MBTI/五行/完整度', (tester) async {
    await tester.pumpWidget(wrap(ProfileCardStep(
      name: '阿玄',
      birthDate: DateTime(1999, 9, 20),
      birthHour: 9,
      birthMinute: 30,
      birthPlace: '香港',
      mbti: 'ISFP',
      onSaved: () {},
    )));
    await tester.pumpAndSettle();

    expect(find.text('阿玄'), findsOneWidget);
    expect(find.textContaining('ISFP'), findsOneWidget);
    expect(find.textContaining('乙木'), findsWidgets);
    expect(find.textContaining('100%'), findsOneWidget);
  });

  testWidgets('撳「開始睇今日」會存 profile 落 StorageService 並 call onSaved', (tester) async {
    var savedCalled = false;
    await tester.pumpWidget(wrap(ProfileCardStep(
      name: '阿玄',
      birthDate: DateTime(1999, 9, 20),
      birthHour: 9,
      birthMinute: 30,
      birthPlace: '香港',
      mbti: 'ISFP',
      onSaved: () => savedCalled = true,
    )));
    await tester.pumpAndSettle();

    await tester.tap(find.text('開始睇今日'));
    await tester.pumpAndSettle();

    expect(savedCalled, isTrue);
    final saved = await StorageService().loadPrimaryProfile();
    expect(saved, isNotNull);
    expect(saved!.name, '阿玄');
    expect(saved.mbti, 'ISFP');
    expect(saved.dayMaster, '乙木');
  });

  testWidgets('連續快速撳兩下「開始睇今日」，onSaved 淨係 call 一次', (tester) async {
    var savedCount = 0;
    await tester.pumpWidget(wrap(ProfileCardStep(
      name: '阿玄',
      birthDate: DateTime(1999, 9, 20),
      birthHour: 9,
      birthMinute: 30,
      birthPlace: '香港',
      mbti: 'ISFP',
      onSaved: () => savedCount++,
    )));
    await tester.pumpAndSettle();

    // 兩下 tap 之間冇 pump()，模擬喺 _saving=true 生效前嘅第二下撳。
    await tester.tap(find.text('開始睇今日'));
    await tester.tap(find.text('開始睇今日'));
    await tester.pumpAndSettle();

    expect(savedCount, 1);
  });

  testWidgets('冇時辰（降級模式）：完整度顯示 80%', (tester) async {
    await tester.pumpWidget(wrap(ProfileCardStep(
      name: '阿玄',
      birthDate: DateTime(1999, 9, 20),
      birthHour: null,
      birthMinute: 0,
      birthPlace: '香港',
      mbti: 'ISFP',
      onSaved: () {},
    )));
    await tester.pumpAndSettle();

    expect(find.textContaining('80%'), findsOneWidget);
  });
}
