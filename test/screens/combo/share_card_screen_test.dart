import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:xuanli/engine/profile_builder.dart';
import 'package:xuanli/models/combo.dart';
import 'package:xuanli/models/profile.dart';
import 'package:xuanli/screens/combo/share_card_screen.dart';
import 'package:xuanli/services/share_card_service.dart';
import 'package:xuanli/theme/xuanli_theme.dart';
import 'package:xuanli/widgets/share_card.dart';

void main() {
  setUpAll(() {
    initCombos(File('lib/data/combos.json').readAsStringSync());
  });

  final profile = buildProfile(
    id: 'p1',
    name: '阿玄',
    birthDate: DateTime(1999, 9, 20),
    birthHour: 9,
    birthMinute: 30,
    birthPlace: '香港',
    mbti: 'ISFP',
  );

  Widget wrap(Widget child) =>
      MaterialApp(theme: XuanLiTheme.light(), home: child);

  Profile standIn({
    required String dayMaster,
    required String mbti,
    String name = '阿玄',
  }) {
    return Profile(
      id: 'stand-in',
      name: name,
      birthDate: DateTime(1990, 1, 1),
      birthHour: 8,
      birthPlace: '香港',
      mbti: mbti,
      pillars: ['甲子', '乙丑', '${dayMaster.characters.first}寅', '丙辰'],
      wuxing: const {'木': 20, '火': 20, '土': 20, '金': 20, '水': 20},
      favorable: const ['金'],
      unfavorable: const ['木'],
      dayMaster: dayMaster,
      ziweiStar: '紫微',
      zodiac: '馬',
    );
  }

  test('有專圖嘅宮職用自己張圖，其餘用後備宮官像', () {
    expect(
      palaceIllustrationAsset('城守將軍'),
      'assets/palace/chengshou-jiangjun.png',
    );
    expect(palaceIllustrationAsset('御用畫師'), 'assets/palace/yuyong-huashi.png');
    expect(palaceIllustrationAsset('典籍校書'), palaceFallbackAsset);
    expect(palaceSampleAssets.containsValue(palaceFallbackAsset), isFalse);
  });

  testWidgets('預覽顯示宮職、這就是你、適合盲點合得來，但唔洩露姓名同出生資料', (tester) async {
    await tester.pumpWidget(wrap(ShareCardScreen(profile: profile)));

    final combo = getCombo(dayGan: '乙', mbti: 'ISFP');
    expect(combo.plainLine, contains('眼力'));
    expect(combo.jobs, contains('花藝師'));

    expect(find.text('御用畫師'), findsOneWidget);
    expect(find.text('乙木命 · ISFP'), findsOneWidget);
    expect(find.textContaining('同一件衣服'), findsOneWidget);
    expect(find.text('適合：'), findsOneWidget);
    expect(find.text('視覺設計師、空間設計師'), findsOneWidget);
    expect(find.text('盲點：'), findsOneWidget);
    expect(find.text(combo.blindSpot), findsOneWidget);
    expect(find.text('合得來：'), findsOneWidget);
    expect(find.text(combo.bestMatchDisplay()), findsOneWidget);
    expect(find.textContaining('適合當視覺設計師'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('assets/palace/yuyong-huashi.png')),
      findsOneWidget,
    );
    expect(find.textContaining('眼力'), findsNothing);
    expect(find.textContaining('一句白話'), findsNothing);
    expect(find.textContaining('花藝師'), findsNothing);
    expect(find.textContaining('你呢'), findsNothing);
    expect(find.textContaining('阿玄'), findsNothing);
    expect(find.textContaining('1999'), findsNothing);
    expect(find.textContaining('香港'), findsNothing);
  });

  testWidgets('城守將軍用專圖，未出圖嘅職位用後備圖，最長文案唔溢出', (tester) async {
    tester.view.physicalSize = const Size(800, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final general = standIn(dayMaster: '戊土', mbti: 'ESTJ', name: '阿城');
    final combo = getCombo(dayGan: '戊', mbti: 'ESTJ');
    await tester.pumpWidget(wrap(ShareCard(profile: general, combo: combo)));
    expect(find.text('城守將軍'), findsOneWidget);
    expect(find.text('營運主管、風險管理'), findsOneWidget);
    expect(find.text(combo.blindSpot), findsOneWidget);
    expect(find.text(combo.bestMatchDisplay()), findsOneWidget);
    expect(
      find.byKey(const ValueKey('assets/palace/chengshou-jiangjun.png')),
      findsOneWidget,
    );
    expect(find.textContaining('阿城'), findsNothing);
    expect(find.textContaining('1990'), findsNothing);
    expect(tester.takeException(), isNull);

    final missing = standIn(dayMaster: '甲木', mbti: 'INTP');
    final missingCombo = getCombo(dayGan: '甲', mbti: 'INTP');
    expect(missingCombo.palaceTitle, '典籍校書');
    await tester.pumpWidget(
      wrap(ShareCard(profile: missing, combo: missingCombo)),
    );
    expect(find.byKey(ValueKey<String>(palaceFallbackAsset)), findsOneWidget);
    expect(find.text('適合：'), findsOneWidget);
    expect(tester.takeException(), isNull);

    final heavyProfile = standIn(dayMaster: '己土', mbti: 'INTJ');
    final heavy = getCombo(dayGan: '己', mbti: 'INTJ');
    await tester.pumpWidget(
      wrap(ShareCard(profile: heavyProfile, combo: heavy)),
    );
    expect(find.text(heavy.thisIsYou), findsOneWidget);
    expect(find.text(heavy.bestMatchDisplay()), findsOneWidget);
    expect(find.textContaining(heavy.plainLine), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('分享卡有 QR code，網址係固定嘅 https 網站（冇個人資料）', (tester) async {
    await tester.pumpWidget(wrap(ShareCardScreen(profile: profile)));

    // QrImageView 唔保留輸入字串，所以 QR 內容靠 [xuanliWebUrl] 常數（`ShareCard`
    // 直接用佢）＋輸出圖用 OpenCV 掃碼驗證過（見 CHANGELOG）。
    expect(find.byType(QrImageView), findsOneWidget);
    expect(find.bySemanticsLabel('Kairo 網站 QR code'), findsOneWidget);
    expect(xuanliWebUrl, 'https://xuanli-opal.vercel.app');
    expect(find.text('Kairo・僅供參考'), findsOneWidget);
    expect(find.textContaining('你呢'), findsNothing);
  });

  testWidgets('撳分享會截出 1080×1920 PNG 交畀 share service', (tester) async {
    Uint8List? shared;
    String? name;
    final service = ShareCardService(
      share: (png, filename, origin) async {
        shared = png;
        name = filename;
      },
    );
    await tester.pumpWidget(
      wrap(ShareCardScreen(profile: profile, service: service)),
    );

    await tester.runAsync(() async {
      await tester.tap(find.text('分享'));
      // toImage 要真 async（唔係 fake clock）
      for (var i = 0; i < 50 && shared == null; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 50));
      }
    });
    await tester.pump();

    expect(shared, isNotNull);
    expect(name, 'xuanli-御用畫師.png');
    // PNG signature + IHDR width/height
    final bytes = shared!;
    expect(bytes.sublist(0, 8), [137, 80, 78, 71, 13, 10, 26, 10]);
    final header = ByteData.sublistView(bytes, 16, 24);
    expect(header.getUint32(0), 1080);
    expect(header.getUint32(4), 1920);
    expect(find.text('分享'), findsOneWidget); // button 恢復
  });

  testWidgets('分享失敗會提示而唔係靜靜吞咗', (tester) async {
    final service = ShareCardService(
      share: (png, filename, origin) async {
        throw Exception('share sheet failed');
      },
    );
    await tester.pumpWidget(
      wrap(ShareCardScreen(profile: profile, service: service)),
    );

    await tester.runAsync(() async {
      await tester.tap(find.text('分享'));
      await Future<void>.delayed(const Duration(milliseconds: 500));
    });
    await tester.pump();

    expect(find.text('分享失敗，請再試一次'), findsOneWidget);
  });
}
