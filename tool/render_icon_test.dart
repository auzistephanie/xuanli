// 生成 app icon：flutter test --update-goldens tool/render_icon_test.dart
// 唔喺 test/ 入面，所以 `flutter test` 全套唔會跑佢。

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xuanli/theme/brand.dart';
import 'package:xuanli/theme/motion.dart';
import 'package:xuanli/theme/xuanli_theme.dart';
import 'package:xuanli/widgets/orrery.dart';

// decoration: none — 冇 Material 祖先時 Text 會畫黃色 debug 底線。
Widget _k(Color color, {double size = 560}) => Text('K',
    style: TextStyle(
        fontFamily: XuanLiFonts.wordmark,
        fontWeight: FontWeight.w600,
        fontSize: size,
        height: 1,
        color: color,
        decoration: TextDecoration.none));

Widget _canvas({required bool background, required Widget child}) => MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Center(
        child: RepaintBoundary(
          key: const ValueKey('icon'),
          child: Container(
            width: 1024,
            height: 1024,
            decoration: background
                ? const BoxDecoration(
                    gradient: RadialGradient(
                        center: Alignment(0, -0.4),
                        colors: [Color(0xFF2B376A), KairoPalette.night],
                        stops: [0, 0.75]))
                : null,
            alignment: Alignment.center,
            child: child,
          ),
        ),
      ),
    );

void main() {
  setUpAll(() async {
    Motion.ambientEnabled = false;
    final loader = FontLoader(XuanLiFonts.wordmark)
      ..addFont(rootBundle.load('assets/fonts/CormorantGaramond-SemiBold.ttf'));
    await loader.load();
  });

  Future<void> render(WidgetTester tester, Widget w, String file) async {
    tester.view.physicalSize = const Size(1024, 1024);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(w);
    await expectLater(find.byKey(const ValueKey('icon')), matchesGoldenFile('../assets/icon/$file'));
  }

  testWidgets('icon.png（完整）', (tester) async {
    await render(
        tester,
        _canvas(
            background: true,
            child: Stack(alignment: Alignment.center, children: [
              const Orrery(size: 760, coreFraction: 0.001),
              _k(KairoPalette.goldBright),
            ])),
        'icon.png');
  });

  testWidgets('icon_foreground.png（Android adaptive 前景，透明底，留安全區）', (tester) async {
    await render(
        tester,
        _canvas(
            background: false,
            child: Stack(alignment: Alignment.center, children: [
              const Orrery(size: 600, coreFraction: 0.001),
              _k(KairoPalette.goldBright, size: 440),
            ])),
        'icon_foreground.png');
  });

  testWidgets('icon_mono.png（單色）', (tester) async {
    await render(tester, _canvas(background: false, child: _k(Colors.white, size: 440)),
        'icon_mono.png');
  });
}
