import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xuanli/theme/brand.dart';
import 'package:xuanli/widgets/brand.dart';

void main() {
  Widget wrap(Widget c) => MaterialApp(home: Scaffold(body: Center(child: c)));

  test('品牌常數', () {
    expect(kBrandName, 'Kairo');
    expect(kBrandSeal, '吉時');
    expect(kBrandSealShort, '吉');
  });

  test('Wordmark 字體已 bundle 而且細過 100KB', () {
    final f = File('assets/fonts/CormorantGaramond-SemiBold.ttf');
    expect(f.existsSync(), isTrue);
    expect(f.lengthSync(), lessThan(100 * 1024));
  });

  testWidgets('BrandSeal 單字：顯示一個字，尺寸跟 size', (tester) async {
    await tester.pumpWidget(wrap(const BrandSeal(text: '吉', size: 34)));
    expect(find.text('吉'), findsOneWidget);
    expect(tester.getSize(find.byType(BrandSeal)), const Size(34, 34));
  });

  testWidgets('BrandSeal 兩字：直排兩個字', (tester) async {
    await tester.pumpWidget(wrap(const BrandSeal(text: '吉時', size: 64)));
    expect(find.text('吉'), findsOneWidget);
    expect(find.text('時'), findsOneWidget);
    expect(tester.getTopLeft(find.text('時')).dy,
        greaterThan(tester.getTopLeft(find.text('吉')).dy));
  });

  testWidgets('Wordmark 顯示 Kairo', (tester) async {
    await tester.pumpWidget(wrap(const Wordmark(fontSize: 24)));
    expect(find.text('Kairo'), findsOneWidget);
  });
}
