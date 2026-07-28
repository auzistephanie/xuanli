import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xuanli/models/day_reading.dart';
import 'package:xuanli/screens/today/today_widgets.dart';
import 'package:xuanli/theme/xuanli_theme.dart';

void main() {
  Widget wrap(Widget child) =>
      MaterialApp(theme: XuanLiTheme.light(), home: Scaffold(body: child));

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
      await tester.pumpWidget(wrap(YjColumn(
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
      await tester.pumpWidget(wrap(YjColumn(
        dotLabel: '忌',
        title: '今日忌',
        isYi: false,
        items: const [YjItem(label: '簽約大事', matchesUser: false)],
        extraNote: '申時 15–17',
      )));

      expect(find.text('申時 15–17'), findsOneWidget);
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
}
