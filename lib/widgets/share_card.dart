import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../models/combo.dart';
import '../models/profile.dart';
import '../theme/xuanli_theme.dart';
import 'share_parts.dart';

export 'share_parts.dart' show xuanliWebUrl, shareCardSize;

const _ink = Color(0xFF2C261C);

const _elementBg = {
  '木': Color(0xFFE7F3EA),
  '火': Color(0xFFF8E8E4),
  '土': Color(0xFFF7F0DC),
  '金': Color(0xFFF3F1EB),
  '水': Color(0xFFE6F0F6),
};

const _elementInk = {
  '木': Color(0xFF1E3D2C),
  '火': Color(0xFF6E2E2A),
  '土': Color(0xFF5A4318),
  '金': Color(0xFF3C414C),
  '水': Color(0xFF1A3348),
};

/// 八字×MBTI 組合分享卡。淡色五行底、宮職大字、一句「這就是你」、
/// 底欄用分享句。唔放姓名、出生日期或時辰。
class ShareCard extends StatelessWidget {
  final Profile profile;
  final Combo combo;

  const ShareCard({super.key, required this.profile, required this.combo});

  @override
  Widget build(BuildContext context) {
    final element = profile.dayMaster.characters.last;
    final bg = _elementBg[element] ?? const Color(0xFFF6EFE2);
    final titleInk = _elementInk[element] ?? _ink;
    return SizedBox.fromSize(
      size: shareCardSize,
      child: Material(
        type: MaterialType.transparency,
        child: DecoratedBox(
          decoration: BoxDecoration(color: bg),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(28, 26, 28, 22),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const ShareBrand(),
                const SizedBox(height: 28),
                Text(
                  combo.palaceTitle,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: XuanLiFonts.serif,
                    fontSize: 40,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 4,
                    color: titleInk,
                    height: 1.15,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  '${profile.dayMaster}命 · ${profile.mbti}',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 15,
                    letterSpacing: 1.2,
                    color: titleInk.withValues(alpha: 0.82),
                  ),
                ),
                const SizedBox(height: 22),
                Text(
                  combo.thisIsYou,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 15,
                    height: 1.55,
                    color: _ink,
                  ),
                ),
                const Spacer(),
                Text(
                  combo.shareLine,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: XuanLiFonts.serif,
                    fontSize: 15,
                    height: 1.45,
                    fontWeight: FontWeight.w700,
                    color: titleInk,
                  ),
                ),
                const SizedBox(height: 16),
                _qr(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _qr() {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(5),
          decoration: BoxDecoration(
            color: sharePaper,
            borderRadius: BorderRadius.circular(8),
          ),
          child: QrImageView(
            data: xuanliWebUrl,
            size: 64,
            padding: EdgeInsets.zero,
            backgroundColor: sharePaper,
            eyeStyle: const QrEyeStyle(eyeShape: QrEyeShape.square, color: shareNavy),
            dataModuleStyle: const QrDataModuleStyle(
              dataModuleShape: QrDataModuleShape.square,
              color: shareNavy,
            ),
            semanticsLabel: 'Kairo 網站 QR code',
          ),
        ),
        const SizedBox(width: 12),
        const Expanded(
          child: Text(
            'Kairo・僅供參考',
            style: TextStyle(fontSize: 13, height: 1.4, color: _ink),
          ),
        ),
      ],
    );
  }
}
