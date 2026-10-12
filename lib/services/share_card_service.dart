import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:share_plus/share_plus.dart';

typedef ShareCardSharer = Future<void> Function(
  Uint8List png,
  String filename,
  Rect? shareOrigin,
);

/// 將畫面入面 [boundaryKey] 指住嘅 `RepaintBoundary` 截成 PNG 再交畀系統
/// 分享。圖喺本機生成，唔經任何網絡（鐵律 1）。
class ShareCardService {
  final ShareCardSharer _share;

  ShareCardService({ShareCardSharer? share}) : _share = share ?? _shareWithSystem;

  /// 邏輯尺寸 360×640 × pixelRatio 3 = 1080×1920。
  static const pixelRatio = 3.0;

  Future<Uint8List> capture(GlobalKey boundaryKey) async {
    final boundary =
        boundaryKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
    if (boundary == null) {
      throw StateError('分享卡未準備好');
    }
    final image = await boundary.toImage(pixelRatio: pixelRatio);
    try {
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      if (data == null) throw StateError('分享卡轉圖失敗');
      return data.buffer.asUint8List();
    } finally {
      image.dispose();
    }
  }

  Future<void> shareCard(
    GlobalKey boundaryKey, {
    required String comboName,
    Rect? shareOrigin,
  }) async {
    final png = await capture(boundaryKey);
    await _share(png, 'xuanli-$comboName.png', shareOrigin);
  }

  static Future<void> _shareWithSystem(
    Uint8List png,
    String filename,
    Rect? shareOrigin,
  ) async {
    await SharePlus.instance.share(ShareParams(
      files: [XFile.fromData(png, name: filename, mimeType: 'image/png')],
      fileNameOverrides: [filename],
      title: '玄曆・我嘅組合',
      sharePositionOrigin: shareOrigin,
    ));
  }
}
