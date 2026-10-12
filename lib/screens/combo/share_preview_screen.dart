import 'package:flutter/material.dart';

import '../../services/share_card_service.dart';
import '../../theme/xuanli_theme.dart';

/// 通用分享卡預覽頁：顯示 [card]（要係 `shareCardSize` 邏輯尺寸嘅 widget），
/// 撳「分享」本機截圖成 1080×1920 PNG 並交畀系統 share sheet。
/// 組合卡同合盤卡共用。
class SharePreviewScreen extends StatefulWidget {
  final String title;
  final Widget card;

  /// 檔名 `xuanli-<filename>.png`。
  final String filename;
  final ShareCardService? service;

  const SharePreviewScreen({
    super.key,
    required this.title,
    required this.card,
    required this.filename,
    this.service,
  });

  @override
  State<SharePreviewScreen> createState() => _SharePreviewScreenState();
}

class _SharePreviewScreenState extends State<SharePreviewScreen> {
  final _boundaryKey = GlobalKey();
  late final ShareCardService _service = widget.service ?? ShareCardService();
  bool _busy = false;

  Future<void> _share() async {
    if (_busy) return;
    setState(() => _busy = true);
    final box = context.findRenderObject() as RenderBox?;
    final origin = box == null ? null : box.localToGlobal(Offset.zero) & box.size;
    try {
      await _service.shareCard(
        _boundaryKey,
        comboName: widget.filename,
        shareOrigin: origin,
      );
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('分享失敗，請再試一次')),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.xuanliColors;
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.title,
          style: TextStyle(
            fontFamily: XuanLiFonts.serif,
            fontWeight: FontWeight.w700,
            fontSize: 16,
            color: colors.ink,
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        iconTheme: IconThemeData(color: colors.ink60),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
                child: Center(
                  child: FittedBox(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(XuanLiRadii.card),
                      child: RepaintBoundary(key: _boundaryKey, child: widget.card),
                    ),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 18),
              child: SizedBox(
                width: double.infinity,
                height: 48,
                child: FilledButton(
                  onPressed: _busy ? null : _share,
                  style: FilledButton.styleFrom(
                    backgroundColor: colors.ink,
                    foregroundColor: colors.paper,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(XuanLiRadii.card),
                    ),
                  ),
                  child: Text(_busy ? '準備緊…' : '分享'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
