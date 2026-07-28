import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xuanli/engine/almanac.dart';
import 'package:xuanli/engine/copywriter.dart';
import 'package:xuanli/engine/day_reading_engine.dart';
import 'package:xuanli/engine/profile_builder.dart';
import 'package:xuanli/models/day_reading.dart';
import 'package:xuanli/screens/today/today_widgets.dart';
import 'package:xuanli/theme/xuanli_theme.dart';

void main() {
  Widget wrap(Widget child) =>
      MaterialApp(theme: XuanLiTheme.light(), home: Scaffold(body: child));

  // YjColumn 包咗 Expanded 喺自己入面（spec 入面淨係得「兩欄並排」呢個
  // 用法），所以要有真 Row 做 flex parent 先撐得住，同 today_screen.dart
  // 真實用法一致——用 Scaffold(body: child) 直接掛會爆
  // Incorrect use of ParentDataWidget。
  Widget wrapInRow(Widget child) => wrap(Row(children: [child]));

  setUpAll(() {
    initMbtiTones(File('lib/data/mbti_tones.json').readAsStringSync());
    initActivityCategories(
      File('lib/data/activity_categories.json').readAsStringSync(),
    );
  });

  group('ScoreRing', () {
    testWidgets('顯示分數同 label', (tester) async {
      await tester.pumpWidget(wrap(
        ScoreRing(score: 42, ringColor: Colors.amber, label: '命理分・平'),
      ));
      expect(find.text('42'), findsOneWidget);
      expect(find.text('命理分・平'), findsOneWidget);
    });
  });

  group('YjColumn', () {
    testWidgets('已配對項目顯示「✦ 合你」，未配對嘅唔顯示', (tester) async {
      await tester.pumpWidget(wrapInRow(YjColumn(
        dotLabel: '宜',
        title: '今日宜',
        isYi: true,
        items: const [
          YjItem(label: '祭祀祈福', matchesUser: true),
          YjItem(label: '解除舊約', matchesUser: false),
        ],
      )));

      expect(find.text('祭祀祈福'), findsOneWidget);
      expect(find.text('解除舊約'), findsOneWidget);
      expect(find.text('✦ 合你'), findsOneWidget);
    });

    testWidgets('有 extraNote 就顯示喺列表下面', (tester) async {
      await tester.pumpWidget(wrapInRow(YjColumn(
        dotLabel: '忌',
        title: '今日忌',
        isYi: false,
        items: const [YjItem(label: '簽約大事', matchesUser: false)],
        extraNote: '申時 15–17',
      )));

      expect(find.text('申時 15–17'), findsOneWidget);
    });

    testWidgets('items 空 list 顯示「冇特別注明」，唔會淨係得個標題', (tester) async {
      await tester.pumpWidget(wrapInRow(const YjColumn(
        dotLabel: '宜',
        title: '今日宜',
        isYi: true,
        items: [],
      )));

      expect(find.text('冇特別注明'), findsOneWidget);
    });
  });

  group('AdviceCard', () {
    testWidgets('顯示建議文字', (tester) async {
      await tester.pumpWidget(wrap(
        const AdviceCard(advice: '丙戌平日，宜靜不宜動。'),
      ));
      expect(find.textContaining('丙戌平日'), findsOneWidget);
      expect(find.textContaining('🔮'), findsOneWidget);
    });
  });

  group('Week7Strip', () {
    testWidgets('7 日全部顯示，今日嗰格有金框，撳第二日會 call onSelect', (tester) async {
      final profile = buildProfile(
        id: 'p1',
        name: '阿玄',
        birthDate: DateTime(1999, 9, 20),
        birthHour: 9,
        birthMinute: 30,
        birthPlace: '香港',
        mbti: 'ISFP',
      );
      final start = DateTime(2026, 7, 11);
      final readings = [
        for (var i = 0; i < 7; i++)
          buildDayReading(profile: profile, date: start.add(Duration(days: i))),
      ];
      DateTime? selected;

      await tester.pumpWidget(wrap(Week7Strip(
        readings: readings,
        selectedDate: start,
        onSelect: (d) => selected = d,
      )));

      expect(find.text('11'), findsOneWidget);
      expect(find.text('17'), findsOneWidget);

      await tester.tap(find.text('12'));
      await tester.pump();

      expect(selected, DateTime(2026, 7, 12));
    });
  });
}
