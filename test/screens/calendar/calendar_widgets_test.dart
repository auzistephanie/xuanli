import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xuanli/screens/calendar/calendar_widgets.dart';
import 'package:xuanli/theme/xuanli_theme.dart';

void main() {
  Widget wrap(Widget child) =>
      MaterialApp(theme: XuanLiTheme.light(), home: Scaffold(body: child));

  group('CalendarGrid', () {
    testWidgets('顯示成個月啲日子（含前置留白），撳日會 call onSelectDay', (tester) async {
      final days = [
        for (var d = 1; d <= 5; d++)
          CalendarCellData(day: d, lunarLabel: '初$d', band: '平', isToday: d == 3),
      ];
      int? selected;

      await tester.pumpWidget(wrap(CalendarGrid(
        leadingBlanks: 2,
        days: days,
        selectedDay: null,
        onSelectDay: (d) => selected = d,
      )));

      expect(find.text('3'), findsOneWidget);
      await tester.tap(find.text('3'));
      expect(selected, 3);
    });

    testWidgets('band 吉/忌 格仔用啱嘅 dot 顏色（吉=jade，忌=red）', (tester) async {
      final days = [
        CalendarCellData(day: 1, lunarLabel: '初一', band: '吉'),
        CalendarCellData(day: 2, lunarLabel: '初二', band: '忌'),
      ];

      await tester.pumpWidget(wrap(CalendarGrid(
        leadingBlanks: 0,
        days: days,
        selectedDay: null,
        onSelectDay: (_) {},
      )));

      final colors = XuanLiTheme.light().extension<XuanLiColors>()!;

      // 揾返 day 1（吉）同 day 2（忌）嗰粒 dot：每個格仔入面嗰個
      // shape:BoxShape.circle 嘅 Container。
      final dotFinder = find.byWidgetPredicate((w) =>
          w is Container &&
          w.decoration is BoxDecoration &&
          (w.decoration as BoxDecoration).shape == BoxShape.circle);
      expect(dotFinder, findsNWidgets(2));

      final dots = tester.widgetList<Container>(dotFinder).toList();
      final dot1Color = (dots[0].decoration as BoxDecoration).color;
      final dot2Color = (dots[1].decoration as BoxDecoration).color;

      expect(dot1Color, colors.jade);
      expect(dot2Color, colors.red);
    });

    testWidgets('isToday 格仔有金框，唔係 today 嘅冇', (tester) async {
      final days = [
        CalendarCellData(day: 1, lunarLabel: '初一', band: '平', isToday: true),
        CalendarCellData(day: 2, lunarLabel: '初二', band: '平', isToday: false),
      ];

      await tester.pumpWidget(wrap(CalendarGrid(
        leadingBlanks: 0,
        days: days,
        selectedDay: null,
        onSelectDay: (_) {},
      )));

      final colors = XuanLiTheme.light().extension<XuanLiColors>()!;

      // 每個格仔最外層果個 Container（GestureDetector 嘅直屬 child）
      // 先有粒 border。用 find.ancestor 由日期數字 Text 追返出去。
      final cell1Container = tester.widget<Container>(
        find.ancestor(
          of: find.text('1'),
          matching: find.byType(Container),
        ).first,
      );
      final cell2Container = tester.widget<Container>(
        find.ancestor(
          of: find.text('2'),
          matching: find.byType(Container),
        ).first,
      );

      final border1 = (cell1Container.decoration as BoxDecoration).border as Border;
      final border2 = (cell2Container.decoration as BoxDecoration).border as Border;

      expect(border1.top.color, colors.gold);
      expect(border1.top.width, 2);
      expect(border2.top.color, colors.ink12);
      expect(border2.top.width, 1);
    });

    testWidgets('hasEvents=true 顯示事件小橫條，hasEvents=false 唔顯示', (tester) async {
      final days = [
        CalendarCellData(day: 1, lunarLabel: '初一', band: '平', hasEvents: true),
        CalendarCellData(day: 2, lunarLabel: '初二', band: '平', hasEvents: false),
      ];

      await tester.pumpWidget(wrap(CalendarGrid(
        leadingBlanks: 0,
        days: days,
        selectedDay: null,
        onSelectDay: (_) {},
      )));

      final colors = XuanLiTheme.light().extension<XuanLiColors>()!;

      // 事件橫條係 height:2.5, color:ink60, borderRadius 嘅 Container。
      final eventBarFinder = find.byWidgetPredicate((w) =>
          w is Container &&
          w.constraints?.maxHeight == 2.5 &&
          w.decoration is BoxDecoration &&
          (w.decoration as BoxDecoration).color == colors.ink60);

      expect(eventBarFinder, findsOneWidget);

      // 確認嗰條橫條係喺 day 1 嗰格入面（day 1 有 event，day 2 冇）。
      final ancestorOfDay1 = find.ancestor(
        of: find.text('1'),
        matching: find.byType(GestureDetector),
      );
      expect(
        find.descendant(of: ancestorOfDay1, matching: eventBarFinder),
        findsOneWidget,
      );
    });
  });

  group('DayCard', () {
    testWidgets('顯示日期/分數/副標題/宜忌，calendarAvailable 預設 false 就完全唔顯示行程 section', (tester) async {
      await tester.pumpWidget(wrap(const DayCard(
        dateLabel: '7月16日（四）辛卯日',
        band: '吉',
        score: 88,
        subtitleLine: '六月初三・成日・沖雞煞西',
        yiLine: '嫁娶・祈福・剪髮',
        jiLine: '伐木・掘井',
      )));

      expect(find.text('7月16日（四）辛卯日'), findsOneWidget);
      expect(find.textContaining('吉'), findsWidgets);
      expect(find.textContaining('88'), findsOneWidget);
      expect(find.textContaining('嫁娶'), findsOneWidget);
      expect(find.textContaining('伐木'), findsOneWidget);
      // 冇日曆權限（或者未查）：成個「你嘅行程」section 靜默隱藏，
      // 唔會顯示任何行程相關文字。
      expect(find.textContaining('你嘅行程'), findsNothing);
    });

    testWidgets('calendarAvailable=true、eventLines 空 → 顯示「今日冇行程」', (tester) async {
      await tester.pumpWidget(wrap(const DayCard(
        dateLabel: '7月16日（四）辛卯日',
        band: '吉',
        score: 88,
        subtitleLine: '六月初三・成日・沖雞煞西',
        yiLine: '嫁娶・祈福・剪髮',
        jiLine: '伐木・掘井',
        calendarAvailable: true,
        eventLines: [],
      )));

      expect(find.textContaining('你嘅行程'), findsOneWidget);
      expect(find.text('今日冇行程'), findsOneWidget);
    });

    testWidgets('calendarAvailable=true、有 eventLines → 逐條顯示（最多 5 條）', (tester) async {
      await tester.pumpWidget(wrap(const DayCard(
        dateLabel: '7月16日（四）辛卯日',
        band: '吉',
        score: 88,
        subtitleLine: '六月初三・成日・沖雞煞西',
        yiLine: '嫁娶・祈福・剪髮',
        jiLine: '伐木・掘井',
        calendarAvailable: true,
        eventLines: ['09:00 早會', '14:30 剪髮'],
      )));

      expect(find.text('09:00 早會'), findsOneWidget);
      expect(find.text('14:30 剪髮'), findsOneWidget);
      expect(find.text('今日冇行程'), findsNothing);
    });

    testWidgets('band 忌 嘅分數 chip 用 red，同 吉 唔同色', (tester) async {
      await tester.pumpWidget(wrap(const DayCard(
        dateLabel: '7月17日（五）壬辰日',
        band: '忌',
        score: 32,
        subtitleLine: '六月初四・破日・沖狗煞南',
        yiLine: '無',
        jiLine: '嫁娶・出行',
      )));

      final colors = XuanLiTheme.light().extension<XuanLiColors>()!;

      final chipContainer = tester.widget<Container>(
        find.ancestor(
          of: find.text('忌 32'),
          matching: find.byType(Container),
        ).first,
      );
      final chipColor = (chipContainer.decoration as BoxDecoration).color;

      expect(chipColor, colors.red.withValues(alpha: 0.14));
      expect(chipColor, isNot(colors.jade.withValues(alpha: 0.14)));
    });

    testWidgets('band 平 嘅分數 chip 用 ink60，同 吉/忌 唔同色', (tester) async {
      await tester.pumpWidget(wrap(const DayCard(
        dateLabel: '7月18日（六）癸巳日',
        band: '平',
        score: 58,
        subtitleLine: '六月初五・平日・沖豬煞東',
        yiLine: '祈福',
        jiLine: '安葬',
      )));

      final colors = XuanLiTheme.light().extension<XuanLiColors>()!;

      final chipContainer = tester.widget<Container>(
        find.ancestor(
          of: find.text('平 58'),
          matching: find.byType(Container),
        ).first,
      );
      final chipColor = (chipContainer.decoration as BoxDecoration).color;

      expect(chipColor, colors.ink60.withValues(alpha: 0.14));
      expect(chipColor, isNot(colors.jade.withValues(alpha: 0.14)));
      expect(chipColor, isNot(colors.red.withValues(alpha: 0.14)));
    });
  });
}
