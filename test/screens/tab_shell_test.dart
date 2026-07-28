import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xuanli/models/profile.dart';
import 'package:xuanli/screens/tab_shell.dart';
import 'package:xuanli/theme/xuanli_theme.dart';

Profile _sampleProfile() => Profile(
      id: 'p1',
      name: '阿玄',
      birthDate: DateTime(1999, 9, 20),
      birthHour: 9,
      birthPlace: '香港',
      mbti: 'ISFP',
      pillars: const ['己卯', '癸酉', '乙亥', '辛巳'],
      wuxing: const {'木': 30, '火': 14, '土': 13, '金': 15, '水': 28},
      favorable: const ['水', '木'],
      unfavorable: const ['金', '土'],
      dayMaster: '乙木',
      ziweiStar: '太陰',
      zodiac: '兔',
    );

void main() {
  Widget wrap(Widget child) =>
      MaterialApp(theme: XuanLiTheme.light(), home: child);

  testWidgets('預設揀第一個 tab（今日），撳第二個 tab 會切換', (tester) async {
    await tester.pumpWidget(wrap(TabShell(profile: _sampleProfile())));

    expect(find.text('今日'), findsOneWidget);
    expect(find.text('我想做'), findsOneWidget);
    expect(find.text('月曆'), findsOneWidget);

    await tester.tap(find.text('我想做'));
    await tester.pump();

    expect(find.text('Tab B — 2d 起'), findsOneWidget);
  });
}
