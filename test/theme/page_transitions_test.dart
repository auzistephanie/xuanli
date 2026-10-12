import 'package:flutter/cupertino.dart' show CupertinoPageTransitionsBuilder;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xuanli/theme/page_transitions.dart';
import 'package:xuanli/theme/xuanli_theme.dart';

Widget _app({bool disableAnimations = false}) => MaterialApp(
      theme: XuanLiTheme.dark(),
      builder: (c, child) => MediaQuery(
        data: MediaQuery.of(c).copyWith(disableAnimations: disableAnimations),
        child: child!,
      ),
      home: Builder(
        builder: (c) => TextButton(
          onPressed: () => Navigator.of(c)
              .push(MaterialPageRoute(builder: (_) => const Text('新頁'))),
          child: const Text('去'),
        ),
      ),
    );

void main() {
  test('light／dark 主題：iOS 用原生過場（保留左掃返回），其他平台用 Kairo 過場', () {
    for (final theme in [XuanLiTheme.light(), XuanLiTheme.dark()]) {
      final b = theme.pageTransitionsTheme.builders;
      expect(b[TargetPlatform.iOS], isA<CupertinoPageTransitionsBuilder>());
      for (final p in [TargetPlatform.android, TargetPlatform.macOS, TargetPlatform.linux, TargetPlatform.windows, TargetPlatform.fuchsia]) {
        expect(b[p], isA<KairoPageTransitionsBuilder>());
      }
    }
  });

  testWidgets('push 新頁：過場中途係淡入，完咗完全顯示', (tester) async {
    await tester.pumpWidget(_app());
    await tester.tap(find.text('去'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    final fades = tester.widgetList<FadeTransition>(find.ancestor(
        of: find.text('新頁'), matching: find.byType(FadeTransition)));
    expect(fades.any((f) => f.opacity.value < 1), isTrue);
    await tester.pumpAndSettle();
    expect(find.text('新頁'), findsOneWidget);
  });

  testWidgets('減少動態效果：冇淡入／放大，新頁直接顯示', (tester) async {
    await tester.pumpWidget(_app(disableAnimations: true));
    await tester.tap(find.text('去'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(
        find.ancestor(
            of: find.text('新頁'), matching: find.byType(ScaleTransition)),
        findsNothing);
    await tester.pumpAndSettle();
    expect(find.text('新頁'), findsOneWidget);
  });
}
