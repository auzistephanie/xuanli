import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xuanli/screens/activity/activity_widgets.dart';
import 'package:xuanli/theme/xuanli_theme.dart';

void main() {
  Widget wrap(Widget child) =>
      MaterialApp(theme: XuanLiTheme.light(), home: Scaffold(body: child));

  group('ActivityChip', () {
    testWidgets('顯示標籤，撳落會 call onTap', (tester) async {
      var tapped = false;
      await tester.pumpWidget(wrap(ActivityChip(
        label: '剪髮',
        selected: false,
        onTap: () => tapped = true,
      )));

      expect(find.text('剪髮'), findsOneWidget);
      await tester.tap(find.text('剪髮'));
      expect(tapped, isTrue);
    });
  });

  group('ResultCard', () {
    testWidgets('顯示日期/星級/副標題/原因，冇 showCalendarActions 就唔顯示日曆按鈕', (tester) async {
      await tester.pumpWidget(wrap(const ResultCard(
        dateLabel: '7月16日（四）辛卯日',
        stars: 4,
        subtitleLine: '農曆六月初三・成日・沖雞煞西',
        reason: '🔮 成日利成事。',
        showCalendarActions: false,
      )));

      expect(find.text('7月16日（四）辛卯日'), findsOneWidget);
      expect(find.text('農曆六月初三・成日・沖雞煞西'), findsOneWidget);
      expect(find.textContaining('成日利成事'), findsOneWidget);
      expect(find.text('＋ 加入我嘅日曆'), findsNothing);
    });

    testWidgets('showCalendarActions=true 就顯示日曆按鈕，撳落分別 call onAddToCalendar/onViewSchedule', (tester) async {
      var addTapped = false;
      var viewTapped = false;
      await tester.pumpWidget(wrap(ResultCard(
        dateLabel: '7月16日（四）辛卯日',
        stars: 5,
        subtitleLine: '農曆六月初三・成日・沖雞煞西',
        reason: '🔮 成日利成事。',
        showCalendarActions: true,
        onAddToCalendar: () => addTapped = true,
        onViewSchedule: () => viewTapped = true,
      )));

      expect(find.text('＋ 加入我嘅日曆'), findsOneWidget);
      expect(find.text('當日行程 ›'), findsOneWidget);

      await tester.tap(find.text('＋ 加入我嘅日曆'));
      expect(addTapped, isTrue);
      expect(viewTapped, isFalse);

      await tester.tap(find.text('當日行程 ›'));
      expect(viewTapped, isTrue);
    });
  });
}
