import 'package:flutter/material.dart';

import '../../models/combo.dart';
import '../../models/profile.dart';
import '../../services/share_card_service.dart';
import '../../theme/xuanli_theme.dart';
import '../../widgets/share_card.dart';

/// 分享卡預覽頁：顯示 [ShareCard]，撳「分享」截圖並交畀系統 share sheet。
class ShareCardScreen extends StatefulWidget {
  final Profile profile;
  final ShareCardService? service;

  const ShareCardScreen({super.key, required this.profile, this.service});

  @override
  State<ShareCardScreen> createState() => _ShareCardScreenState();
}

class _ShareCardScreenState extends State<ShareCardScreen> {
  final _boundaryKey = GlobalKey();
  late final ShareCardService _service = widget.service ?? ShareCardService();
  bool _busy = false;

  Future<void> _share(Combo combo) async {
    if (_busy) return;
    setState(() => _busy = true);
    final box = context.findRenderObject() as RenderBox?;
    final origin = box == null ? null : box.localToGlobal(Offset.zero) & box.size;
    try {
      await _service.shareCard(_boundaryKey, comboName: combo.name, shareOrigin: origin);
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
    final dayGan = widget.profile.pillars[2].substring(0, 1);
    final combo = getCombo(dayGan: dayGan, mbti: widget.profile.mbti);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          '分享我嘅組合',
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
                      child: RepaintBoundary(
                        key: _boundaryKey,
                        child: ShareCard(profile: widget.profile, combo: combo),
                      ),
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
                  onPressed: _busy ? null : () => _share(combo),
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
