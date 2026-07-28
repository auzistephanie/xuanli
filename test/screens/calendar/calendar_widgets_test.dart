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
  });

  group('DayCard', () {
    testWidgets('顯示日期/分數/副標題/宜忌，冇行程就顯示 stub 提示', (tester) async {
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
      expect(find.textContaining('行事曆整合'), findsOneWidget);
    });
  });
}
