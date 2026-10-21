import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:xuanli/engine/profile_builder.dart';
import 'package:xuanli/engine/synastry.dart';
import 'package:xuanli/models/combo.dart';
import 'package:xuanli/screens/combo/partner_flow.dart';
import 'package:xuanli/services/share_card_service.dart';
import 'package:xuanli/services/storage_service.dart';
import 'package:xuanli/theme/xuanli_theme.dart';
import 'package:xuanli/widgets/synastry_share_card.dart';
import 'package:xuanli/screens/combo/share_preview_screen.dart';

void main() {
  setUpAll(() {
    initCombos(File('lib/data/combos.json').readAsStringSync());
  });

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  final me = buildProfile(
    id: 'p1',
    name: '阿玄',
    birthDate: DateTime(1999, 9, 20),
    birthHour: 9,
    birthMinute: 30,
    birthPlace: '香港',
    mbti: 'ISFP',
  );

  Widget wrap(Widget child) => MaterialApp(theme: XuanLiTheme.light(), home: child);

  Future<void> pickFriend(WidgetTester tester, {String mbti = 'INTJ'}) async {
    // Step 0：出生資料（預設 2000-01-01 09:00）。
    expect(find.text('佢嘅出生一刻'), findsOneWidget);
    await tester.ensureVisible(find.byType(CheckboxListTile));
    await tester.tap(find.byType(CheckboxListTile));
    await tester.pump();
    await tester.ensureVisible(find.text('下一步'));
    await tester.tap(find.text('下一步'));
    await tester.pumpAndSettle();
    // Step 1：MBTI 16 宮格，冇快速測驗。
    expect(find.text('佢偏向邊種性格'), findsOneWidget);
    expect(find.textContaining('快速測驗'), findsNothing);
    await tester.ensureVisible(find.text(mbti));
    await tester.tap(find.text(mbti));
    await tester.pump();
    await tester.ensureVisible(find.text('下一步'));
    await tester.tap(find.text('下一步'));
    await tester.pumpAndSettle();
  }

  testWidgets('行完兩步出合盤結果：關係名、指數、相處之道', (tester) async {
    await tester.pumpWidget(wrap(PartnerFlow(me: me)));
    await pickFriend(tester);

    final friend = buildProfile(
      id: 'f', name: '朋友', birthDate: DateTime(2000, 1, 1), birthHour: 9,
      birthMinute: 0, birthPlace: '香港', mbti: 'INTJ',
    );
    final expected = computeSynastry(me, friend);

    expect(find.text('我哋嘅合盤'), findsOneWidget);
    expect(find.text(expected.name), findsOneWidget);
    expect(find.text('${expected.score}'), findsOneWidget);
    expect(find.text('相處之道'), findsOneWidget);
    expect(find.text('分享合盤卡'), findsOneWidget);
    expect(find.textContaining('唔會儲存'), findsOneWidget);
    // 兩個宮職都喺度：乙_ISFP「御用畫師」，2000-01-01 係戊日／INTJ「定局參謀」。
    expect(find.text('御用畫師'), findsOneWidget);
    expect(find.text('定局參謀'), findsOneWidget);
  });

  testWidgets('私隱：朋友資料由頭到尾冇寫入任何儲存', (tester) async {
    await tester.pumpWidget(wrap(PartnerFlow(me: me)));
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getKeys(), isEmpty);

    await pickFriend(tester);
    expect(find.text('我哋嘅合盤'), findsOneWidget);
    expect(prefs.getKeys(), isEmpty);
    expect(await StorageService().loadPrimaryProfile(), isNull);

    await tester.scrollUntilVisible(find.text('同另一個朋友合盤'), 200);
    await tester.tap(find.text('同另一個朋友合盤'));
    await tester.pumpAndSettle();
    expect(find.text('佢嘅出生一刻'), findsOneWidget);
    expect(prefs.getKeys(), isEmpty);
  });

  testWidgets('返回掣：MBTI 步返出生資料，出生資料步離開', (tester) async {
    await tester.pumpWidget(wrap(Builder(builder: (context) {
      return Scaffold(
        body: Center(
          child: ElevatedButton(
            onPressed: () => Navigator.of(context)
                .push(MaterialPageRoute(builder: (_) => PartnerFlow(me: me))),
            child: const Text('open'),
          ),
        ),
      );
    })));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.byType(CheckboxListTile));
    await tester.tap(find.byType(CheckboxListTile));
    await tester.pump();
    await tester.ensureVisible(find.text('下一步'));
    await tester.tap(find.text('下一步'));
    await tester.pumpAndSettle();
    expect(find.text('佢偏向邊種性格'), findsOneWidget);

    await tester.tap(find.byTooltip('返回'));
    await tester.pumpAndSettle();
    expect(find.text('佢嘅出生一刻'), findsOneWidget);

    await tester.tap(find.byTooltip('返回'));
    await tester.pumpAndSettle();
    expect(find.text('open'), findsOneWidget);
  });

  testWidgets('分享合盤卡：預覽有 QR、冇個人資料，截出 1080×1920 PNG', (tester) async {
    Uint8List? shared;
    String? filename;
    final service = ShareCardService(share: (png, name, origin) async {
      shared = png;
      filename = name;
    });
    final friend = buildProfile(
      id: 'f', name: '朋友', birthDate: DateTime(2000, 1, 7), birthHour: 9,
      birthMinute: 30, birthPlace: '香港', mbti: 'INTJ',
    );
    final result = computeSynastry(me, friend);
    await tester.pumpWidget(wrap(SharePreviewScreen(
      title: '分享合盤',
      filename: '合盤-${result.name}',
      service: service,
      card: SynastryShareCard(comboNameA: '御用畫師', comboNameB: '軍師', result: result),
    )));

    expect(find.text(result.name), findsOneWidget);
    expect(find.text('${result.score}'), findsOneWidget);
    expect(find.text('掃碼同朋友合盤'), findsOneWidget);
    expect(find.bySemanticsLabel('Kairo 網站 QR code'), findsOneWidget);
    expect(find.textContaining('阿玄'), findsNothing);
    expect(find.textContaining('1999'), findsNothing);
    expect(find.textContaining('2000'), findsNothing);

    await tester.runAsync(() async {
      await tester.tap(find.text('分享'));
      for (var i = 0; i < 50 && shared == null; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 50));
      }
    });
    await tester.pump();

    expect(shared, isNotNull);
    expect(filename, 'xuanli-合盤-${result.name}.png');
    final header = ByteData.sublistView(shared!, 16, 24);
    expect(header.getUint32(0), 1080);
    expect(header.getUint32(4), 1920);
  });

  testWidgets('合盤卡喺最闊嘅測試字體都唔 overflow', (tester) async {
    for (final pair in [
      ['甲', '子', '壬', '丑'], // 相生＋六合
      ['庚', '寅', '甲', '申'], // 相剋＋六沖
    ]) {
      final a = buildProfile(
        id: 'a', name: 'a', birthDate: DateTime(1999, 9, 20), birthHour: 9,
        birthMinute: 30, birthPlace: '香港', mbti: 'ENFP',
      );
      final b = buildProfile(
        id: 'b', name: 'b', birthDate: DateTime(2003, 3, 3), birthHour: 15,
        birthMinute: 0, birthPlace: '香港', mbti: 'ISTJ',
      );
      final result = computeSynastry(a, b);
      await tester.pumpWidget(wrap(SharePreviewScreen(
        title: '分享合盤',
        filename: pair.join(),
        card: SynastryShareCard(comboNameA: '御用畫師', comboNameB: '軍師', result: result),
      )));
      expect(tester.takeException(), isNull, reason: pair.join());
    }
  });
}
