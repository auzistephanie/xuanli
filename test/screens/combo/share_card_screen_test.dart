import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:xuanli/engine/profile_builder.dart';
import 'package:xuanli/models/combo.dart';
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

  Widget wrap(Widget child) => MaterialApp(theme: XuanLiTheme.light(), home: child);

  testWidgets('預覽顯示組合名、motto、五行同優勢，但唔洩露姓名同出生資料', (tester) async {
    await tester.pumpWidget(wrap(ShareCardScreen(profile: profile)));

    expect(find.text('林間清泉'), findsOneWidget);
    expect(find.textContaining('柔韌有光'), findsOneWidget);
    expect(find.text('乙木日主'), findsOneWidget);
    expect(find.text('ISFP'), findsOneWidget);
    for (final element in ['木', '火', '土', '金', '水']) {
      expect(find.text(element), findsOneWidget);
    }
    expect(find.text('估算約 0.88%・每 114 人先有一個'), findsOneWidget);
    expect(find.textContaining('阿玄'), findsNothing);
    expect(find.textContaining('1999'), findsNothing);
    expect(find.textContaining('香港'), findsNothing);
  });

  testWidgets('分享卡有 QR code，網址係固定嘅 https 網站（冇個人資料）', (tester) async {
    await tester.pumpWidget(wrap(ShareCardScreen(profile: profile)));

    // QrImageView 唔保留輸入字串，所以 QR 內容靠 [xuanliWebUrl] 常數（`ShareCard`
    // 直接用佢）＋輸出圖用 OpenCV 掃碼驗證過（見 CHANGELOG）。
    expect(find.byType(QrImageView), findsOneWidget);
    expect(find.bySemanticsLabel('玄曆網站 QR code'), findsOneWidget);
    expect(xuanliWebUrl, 'https://xuanli-opal.vercel.app');
    expect(find.text('掃碼睇你嘅組合'), findsOneWidget);
  });

  testWidgets('撳分享會截出 1080×1920 PNG 交畀 share service', (tester) async {
    Uint8List? shared;
    String? name;
    final service = ShareCardService(share: (png, filename, origin) async {
      shared = png;
      name = filename;
    });
    await tester.pumpWidget(wrap(ShareCardScreen(profile: profile, service: service)));

    await tester.runAsync(() async {
      await tester.tap(find.text('分享'));
      // toImage 要真 async（唔係 fake clock）
      for (var i = 0; i < 50 && shared == null; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 50));
      }
    });
    await tester.pump();

    expect(shared, isNotNull);
    expect(name, 'xuanli-林間清泉.png');
    // PNG signature + IHDR width/height
    final bytes = shared!;
    expect(bytes.sublist(0, 8), [137, 80, 78, 71, 13, 10, 26, 10]);
    final header = ByteData.sublistView(bytes, 16, 24);
    expect(header.getUint32(0), 1080);
    expect(header.getUint32(4), 1920);
    expect(find.text('分享'), findsOneWidget); // button 恢復
  });

  testWidgets('分享失敗會提示而唔係靜靜吞咗', (tester) async {
    final service = ShareCardService(share: (png, filename, origin) async {
      throw Exception('share sheet failed');
    });
    await tester.pumpWidget(wrap(ShareCardScreen(profile: profile, service: service)));

    await tester.runAsync(() async {
      await tester.tap(find.text('分享'));
      await Future<void>.delayed(const Duration(milliseconds: 500));
    });
    await tester.pump();

    expect(find.text('分享失敗，請再試一次'), findsOneWidget);
  });
}
