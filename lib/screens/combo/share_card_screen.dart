import 'package:flutter/material.dart';

import '../../models/combo.dart';
import '../../models/profile.dart';
import '../../services/share_card_service.dart';
import '../../widgets/share_card.dart';
import 'share_preview_screen.dart';

/// 組合分享卡預覽頁：顯示 [ShareCard]，撳「分享」截圖並交畀系統 share sheet。
class ShareCardScreen extends StatelessWidget {
  final Profile profile;
  final ShareCardService? service;

  const ShareCardScreen({super.key, required this.profile, this.service});

  @override
  Widget build(BuildContext context) {
    final dayGan = profile.pillars[2].substring(0, 1);
    final combo = getCombo(dayGan: dayGan, mbti: profile.mbti);
    return SharePreviewScreen(
      title: '分享我嘅組合',
      card: ShareCard(profile: profile, combo: combo),
      filename: combo.name,
      service: service,
    );
  }
}
