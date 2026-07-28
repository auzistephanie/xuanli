import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:xuanli/models/combo.dart';
import 'package:xuanli/screens/combo/combo_screen.dart';
import 'package:xuanli/services/storage_service.dart';
import 'package:xuanli/screens/onboarding/profile_card_step.dart';
import 'package:xuanli/theme/xuanli_theme.dart';

/// 淨係數 [Navigator.push] call 咗幾多次，用嚟直接、無歧義咁證明
/// 「撳兩下」有冇真係 push 咗兩次 route——唔靠 find.byType() 個 count
/// （Flutter 嘅 Overlay 淨係即時 build/mount 最頂嗰個 route，就算 Navigator
/// 個 history 入面真係有兩條 route，喺兩下 push 之間冇 pump() 嘅情況下，
/// find.byType(ComboDetailScreen) 都可能一直得返 1，直到之後有嘢逼佢
/// build 第二個先會現形——呢個 observer 就冇呢個 timing 巧合問題）。
class _CountingNavigatorObserver extends NavigatorObserver {
  int pushCount = 0;

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    pushCount++;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  // See birth_data_step_test.dart's wrap() for why `theme:` is required
  // here, not optional — context.xuanliColors needs it present.
  Widget wrap(Widget child) => MaterialApp(
    theme: XuanLiTheme.light(),
    home: Scaffold(body: child),
  );

  testWidgets('用阿玄嘅出生資料起檔案卡：顯示日主/MBTI/五行/完整度', (tester) async {
    await tester.pumpWidget(
      wrap(
        ProfileCardStep(
          name: '阿玄',
          birthDate: DateTime(1999, 9, 20),
          birthHour: 9,
          birthMinute: 30,
          birthPlace: '香港',
          mbti: 'ISFP',
          onSaved: () {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('阿玄'), findsOneWidget);
    expect(find.textContaining('ISFP'), findsOneWidget);
    expect(find.textContaining('乙木'), findsWidgets);
    expect(find.textContaining('100%'), findsOneWidget);
  });

  testWidgets('撳「開始睇今日」會存 profile 落 StorageService 並 call onSaved', (
    tester,
  ) async {
    var savedCalled = false;
    await tester.pumpWidget(
      wrap(
        ProfileCardStep(
          name: '阿玄',
          birthDate: DateTime(1999, 9, 20),
          birthHour: 9,
          birthMinute: 30,
          birthPlace: '香港',
          mbti: 'ISFP',
          onSaved: () => savedCalled = true,
        ),
      ),
    );
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
    await tester.pumpWidget(
      wrap(
        ProfileCardStep(
          name: '阿玄',
          birthDate: DateTime(1999, 9, 20),
          birthHour: 9,
          birthMinute: 30,
          birthPlace: '香港',
          mbti: 'ISFP',
          onSaved: () => savedCount++,
        ),
      ),
    );
    await tester.pumpAndSettle();

    // 兩下 tap 之間冇 pump()，模擬喺 _saving=true 生效前嘅第二下撳。
    await tester.tap(find.text('開始睇今日'));
    await tester.tap(find.text('開始睇今日'));
    await tester.pumpAndSettle();

    expect(savedCount, 1);
  });

  testWidgets('冇時辰（降級模式）：完整度顯示 80%', (tester) async {
    await tester.pumpWidget(
      wrap(
        ProfileCardStep(
          name: '阿玄',
          birthDate: DateTime(1999, 9, 20),
          birthHour: null,
          birthMinute: 0,
          birthPlace: '香港',
          mbti: 'ISFP',
          onSaved: () {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('80%'), findsOneWidget);
  });

  group('撳檔案卡入組合詳解頁', () {
    setUpAll(() {
      initCombos(File('lib/data/combos.json').readAsStringSync());
    });

    testWidgets('撳個命理檔案卡會 push ComboDetailScreen，顯示返嗰個組合', (tester) async {
      await tester.pumpWidget(
        wrap(
          ProfileCardStep(
            name: '阿玄',
            birthDate: DateTime(1999, 9, 20),
            birthHour: 9,
            birthMinute: 30,
            birthPlace: '香港',
            mbti: 'ISFP',
            onSaved: () {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('阿玄'));
      await tester.pumpAndSettle();

      expect(find.byType(ComboDetailScreen), findsOneWidget);
      expect(find.text('林間清泉'), findsOneWidget);
    });

    testWidgets('連續快速撳兩下檔案卡，淨係 push 一次 ComboDetailScreen', (tester) async {
      // 呢個 test 需要一個 NavigatorObserver 嚟直接數 push 次數，所以唔用
      // 得成個 file 共用嗰個 wrap()，自己起多個 MaterialApp。
      final observer = _CountingNavigatorObserver();
      await tester.pumpWidget(
        MaterialApp(
          theme: XuanLiTheme.light(),
          navigatorObservers: [observer],
          home: Scaffold(
            body: ProfileCardStep(
              name: '阿玄',
              birthDate: DateTime(1999, 9, 20),
              birthHour: 9,
              birthMinute: 30,
              birthPlace: '香港',
              mbti: 'ISFP',
              onSaved: () {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      // Observer 喺 app 起身嗰下已經會收到一次 didPush（初始個 route），
      // 所以要記低呢個 baseline，之後淨係計撳張卡之後新增嘅 push 次數。
      final baselinePushCount = observer.pushCount;

      // 呢張卡包咗 Material+InkWell（唔係其他掣用嗰種裸 GestureDetector），
      // tester.tap() 連續兩下冇 pump() 之間喺呢種 widget 度唔靠得住——第二
      // 下 tap 會因為中間嗰下 push 令 hit-test 對唔正個 widget，俾 Flutter
      // 靜靜哋 warn 走，根本冇再撳中 onTap（試過用 tester.tap() 兩次，就算
      // 攞走 _navigatingToCombo 個 guard 都仲係得一個 ComboDetailScreen，
      // 即係話個 test 冇真係測到嘢）。所以呢度唔靠 hit-test，直接搵住張
      // 卡個 InkWell，兩次直接 call 佢個 onTap callback，先至真係模擬到
      // 「第二下撳發生喺第一下 push 完成之前」嗰個 race。
      final cardInkWellFinder = find.ancestor(
        of: find.text('阿玄'),
        matching: find.byType(InkWell),
      );
      expect(cardInkWellFinder, findsOneWidget);
      final cardInkWell = tester.widget<InkWell>(cardInkWellFinder);
      cardInkWell.onTap!();
      cardInkWell.onTap!();
      await tester.pumpAndSettle();

      // 呢度先係真正嘅斷言：直接數 observer.pushCount，唔靠
      // find.byType(ComboDetailScreen) 個 count（Flutter 嘅 Overlay 淨係
      // 即時 build/mount 最頂嗰個 route，就算 Navigator 個 history 入面
      // 真係有兩條 route，喺呢個時間點 find.byType 都可能一直得返 1，
      // 呢個 timing 巧合會令個 test 睇落 pass 但其實冇測到嘢）。
      expect(
        observer.pushCount - baselinePushCount,
        1,
        reason: 'onTap 兩次連續 call（中間冇畀 push 完成），應該淨係真正 '
            'push 咗一次 ComboDetailScreen；如果呢度係 2，即係 _navigatingToCombo '
            '個 guard 冇擋到 race。',
      );
      expect(find.byType(ComboDetailScreen), findsOneWidget);
      expect(find.text('林間清泉'), findsOneWidget);

      // ComboDetailScreen 用自己畫嘅 '‹' 返回鍵，唔係標準 AppBar back
      // button，所以直接撳嗰個 widget（唔用 tester.pageBack()）。
      await tester.tap(find.text('‹'));
      await tester.pumpAndSettle();

      expect(find.byType(ComboDetailScreen), findsNothing);
      expect(find.text('阿玄'), findsOneWidget);
    });

    testWidgets('檔案卡有提示用戶可以撳入組合詳解頁嘅文字', (tester) async {
      await tester.pumpWidget(
        wrap(
          ProfileCardStep(
            name: '阿玄',
            birthDate: DateTime(1999, 9, 20),
            birthHour: 9,
            birthMinute: 30,
            birthPlace: '香港',
            mbti: 'ISFP',
            onSaved: () {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('組合詳解'), findsOneWidget);
    });
  });
}
