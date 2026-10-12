import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:xuanli/engine/almanac.dart';
import 'package:xuanli/engine/copywriter.dart';
import 'package:xuanli/engine/daily_stick.dart';
import 'package:xuanli/engine/profile_builder.dart';
import 'package:xuanli/models/day_reading.dart';
import 'package:xuanli/screens/today/daily_stick_card.dart';
import 'package:xuanli/screens/today/today_screen.dart';
import 'package:xuanli/services/storage_service.dart';
import 'package:xuanli/theme/xuanli_theme.dart';
import 'package:xuanli/widgets/stick_share_card.dart';

void main() {
  setUpAll(() {
    initMbtiTones(File('lib/data/mbti_tones.json').readAsStringSync());
    initActivityCategories(File('lib/data/activity_categories.json').readAsStringSync());
  });

  setUp(() => SharedPreferences.setMockInitialValues({}));

  final profile = buildProfile(
    id: 'p1',
    name: '阿玄',
    birthDate: DateTime(1999, 9, 20),
    birthHour: 9,
    birthMinute: 30,
    birthPlace: '香港',
    mbti: 'ISFP',
  );
  final date = DateTime(2026, 7, 11);

  DayReading reading({int score = 75}) => DayReading(
    date: date, ganzhiDay: '丙戌', lunarLabel: '五月廿七', zhiXing: '平', chong: '沖龍煞北',
    fortuneScore: score, mbtiScore: 60, band: '吉',
    yi: const [YjItem(label: '祈福', matchesUser: false)],
    ji: const [], advice: '', clashWarning: null, avoidHour: null,
  );

  Widget wrap(Widget child, {bool disableAnimations = false}) => MaterialApp(
    theme: XuanLiTheme.light(),
    home: MediaQuery(
      data: MediaQueryData(disableAnimations: disableAnimations),
      child: Scaffold(body: SingleChildScrollView(child: child)),
    ),
  );

  Widget card({bool alreadyDrawn = false, VoidCallback? onDrawn, int score = 75}) {
    return DailyStickCard(
      stick: drawDailyStick(profile: profile, reading: reading(score: score)),
      date: date,
      alreadyDrawn: alreadyDrawn,
      onDrawn: onDrawn ?? () {},
    );
  }

  group('DailyStickCard', () {
    testWidgets('未抽：只見籤筒同「搖籤」，睇唔到籤詩', (tester) async {
      final stick = drawDailyStick(profile: profile, reading: reading());
      await tester.pumpWidget(wrap(card()));

      expect(find.text('今日一籤'), findsOneWidget);
      expect(find.text('搖籤'), findsOneWidget);
      expect(find.text(stick.levelName), findsNothing);
      expect(find.text(stick.verse.first.substring(0, 1)), findsNothing);
    });

    testWidgets('撳搖籤：動畫完先出籤，onDrawn 剛好一次', (tester) async {
      var drawn = 0;
      final stick = drawDailyStick(profile: profile, reading: reading());
      await tester.pumpWidget(wrap(card(onDrawn: () => drawn++)));

      await tester.tap(find.text('搖籤'));
      await tester.pump(const Duration(milliseconds: 600));
      expect(find.text(stick.levelName), findsNothing); // 仲喺度搖
      expect(drawn, 0);

      await tester.pump(const Duration(milliseconds: 1000));
      await tester.pumpAndSettle();

      expect(find.text(stick.levelName), findsOneWidget);
      expect(find.text(stick.numberLabel), findsOneWidget);
      expect(find.textContaining('丙戌日'), findsOneWidget);
      expect(find.text('分享呢支籤'), findsOneWidget);
      expect(drawn, 1);
    });

    testWidgets('搖緊嗰陣連撳幾下都唔會重複觸發', (tester) async {
      var drawn = 0;
      await tester.pumpWidget(wrap(card(onDrawn: () => drawn++)));

      await tester.tap(find.text('搖籤'));
      await tester.pump(const Duration(milliseconds: 100));
      await tester.tap(find.text('搖籤'), warnIfMissed: false);
      await tester.tap(find.text('搖籤'), warnIfMissed: false);
      await tester.pumpAndSettle();

      expect(drawn, 1);
    });

    testWidgets('今日已抽：直接見支籤，唔會再 call onDrawn', (tester) async {
      var drawn = 0;
      final stick = drawDailyStick(profile: profile, reading: reading());
      await tester.pumpWidget(wrap(card(alreadyDrawn: true, onDrawn: () => drawn++)));

      expect(find.text(stick.levelName), findsOneWidget);
      expect(find.text('搖籤'), findsNothing);
      expect(drawn, 0);
    });

    testWidgets('減少動態效果：撳一下即刻出籤', (tester) async {
      var drawn = 0;
      final stick = drawDailyStick(profile: profile, reading: reading());
      await tester.pumpWidget(wrap(card(onDrawn: () => drawn++), disableAnimations: true));

      await tester.tap(find.text('搖籤'));
      await tester.pumpAndSettle();

      expect(find.text(stick.levelName), findsOneWidget);
      expect(drawn, 1);
    });

    testWidgets('5 個籤級都顯示得到，冇 overflow', (tester) async {
      for (final score in [95, 75, 60, 45, 20]) {
        await tester.pumpWidget(wrap(card(alreadyDrawn: true, score: score)));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull, reason: 'score $score');
      }
    });
  });

  group('Tab A 整合', () {
    Widget today({DateTime? initialDate}) => MaterialApp(
      theme: XuanLiTheme.light(),
      home: TodayScreen(profile: profile, initialDate: initialDate ?? date),
    );

    testWidgets('抽完會記低今日已抽；重開今日頁直接見返同一支籤', (tester) async {
      await tester.pumpWidget(today());
      await tester.pumpAndSettle();
      final expected = drawDailyStick(
        profile: profile,
        reading: reading(score: 0), // 級別未知，下面用返 screen 內部結果比對
      );
      expect(expected.number, inInclusiveRange(1, 60));
      await tester.ensureVisible(find.text('搖籤'));
      await tester.tap(find.text('搖籤'));
      await tester.pump(const Duration(milliseconds: 1500));
      await tester.pumpAndSettle();

      expect(find.text('分享呢支籤'), findsOneWidget);
      final shownNumber = tester
          .widgetList<Text>(find.byType(Text))
          .map((t) => t.data ?? '')
          .firstWhere((t) => RegExp(r'^第.+籤$').hasMatch(t));
      expect(await StorageService().loadStickDrawnDate(), '2026-07-11');

      // 重開（新 widget tree）。
      await tester.pumpWidget(const SizedBox());
      await tester.pumpWidget(today());
      await tester.pumpAndSettle();
      expect(find.text('搖籤'), findsNothing);
      expect(find.text(shownNumber), findsOneWidget);
    });

    testWidgets('另一日抽過唔算今日：隔日重新見到「搖籤」', (tester) async {
      SharedPreferences.setMockInitialValues({'xuanli_stick_drawn': '2026-07-10'});
      await tester.pumpWidget(today());
      await tester.pumpAndSettle();
      expect(find.text('搖籤'), findsOneWidget);
    });

    testWidgets('揀未來其他日嗰陣唔顯示今日一籤', (tester) async {
      await tester.pumpWidget(today());
      await tester.pumpAndSettle();
      expect(find.text('今日一籤'), findsOneWidget);

      await tester.ensureVisible(find.text('12'));
      await tester.tap(find.text('12'));
      await tester.pumpAndSettle();
      expect(find.text('今日一籤'), findsNothing);
    });
  });

  group('分享卡', () {
    testWidgets('只有日期、籤、解曰，冇姓名／出生資料／命理分，有 QR', (tester) async {
      final stick = drawDailyStick(profile: profile, reading: reading());
      await tester.pumpWidget(MaterialApp(
        theme: XuanLiTheme.light(),
        home: Scaffold(body: Center(child: StickShareCard(stick: stick, date: date))),
      ));

      expect(find.text(stick.levelName), findsOneWidget);
      expect(find.text(stick.numberLabel), findsOneWidget);
      expect(find.textContaining('2026年7月11日'), findsOneWidget);
      expect(find.text('掃碼抽你嘅今日籤'), findsOneWidget);
      expect(find.bySemanticsLabel('Kairo 網站 QR code'), findsOneWidget);
      for (final secret in ['阿玄', '1999', 'ISFP', '香港', '命理分']) {
        expect(find.textContaining(secret), findsNothing, reason: secret);
      }
    });

    testWidgets('5 個籤級嘅分享卡喺最闊嘅測試字體都唔 overflow', (tester) async {
      for (final score in [95, 75, 60, 45, 20]) {
        final stick = drawDailyStick(profile: profile, reading: reading(score: score));
        await tester.pumpWidget(MaterialApp(
          theme: XuanLiTheme.light(),
          home: Scaffold(body: Center(child: StickShareCard(stick: stick, date: date))),
        ));
        expect(tester.takeException(), isNull, reason: 'score $score');
      }
    });
  });
}
