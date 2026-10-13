import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../models/combo.dart';
import '../models/profile.dart';
import '../theme/xuanli_theme.dart';
import 'share_parts.dart';

export 'share_parts.dart'
    show
        palaceFallbackAsset,
        palaceIllustrationAsset,
        palaceSampleAssets,
        shareCardSize,
        xuanliWebUrl;

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
/// 中間係宮職角色圖加適合／盲點／合得來，底欄用分享句。
/// 唔放姓名、出生日期、時辰，亦唔放「一句白話」（plainLine）。
class ShareCard extends StatelessWidget {
  final Profile profile;
  final Combo combo;

  const ShareCard({super.key, required this.profile, required this.combo});

  @override
  Widget build(BuildContext context) {
    final element = profile.dayMaster.characters.last;
    final bg = _elementBg[element] ?? const Color(0xFFF6EFE2);
    final titleInk = _elementInk[element] ?? _ink;
    final suitable = combo.jobs
        .map((job) => job.trim())
        .where((job) => job.isNotEmpty)
        .take(2)
        .join('、');
    return MediaQuery(
      data: MediaQuery.of(context).copyWith(textScaler: TextScaler.noScaling),
      child: SizedBox.fromSize(
        size: shareCardSize,
        child: Material(
          type: MaterialType.transparency,
          child: DecoratedBox(
            decoration: BoxDecoration(color: bg),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(28, 20, 28, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const ShareBrand(),
                  const SizedBox(height: 14),
                  Text(
                    combo.palaceTitle,
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    style: TextStyle(
                      fontFamily: XuanLiFonts.serif,
                      fontSize: 36,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 4,
                      color: titleInk,
                      height: 1.1,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '${profile.dayMaster}命 · ${profile.mbti}',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14,
                      letterSpacing: 1.2,
                      color: titleInk.withValues(alpha: 0.82),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    combo.thisIsYou,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 13.5,
                      height: 1.4,
                      color: _ink,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Expanded(
                    child: PalaceIllustration(
                      palaceTitle: combo.palaceTitle,
                      ink: titleInk,
                    ),
                  ),
                  if (suitable.isNotEmpty) _fact('適合', suitable, titleInk),
                  _fact('盲點', combo.blindSpot, titleInk),
                  _fact('合得來', combo.bestMatchDisplay(), titleInk),
                  const SizedBox(height: 8),
                  Text(
                    combo.shareLine,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: XuanLiFonts.serif,
                      fontSize: 13,
                      height: 1.35,
                      fontWeight: FontWeight.w700,
                      color: titleInk,
                    ),
                  ),
                  const SizedBox(height: 10),
                  _qr(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _fact(String label, String body, Color ink) {
    return Padding(
      padding: const EdgeInsets.only(top: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 58,
            child: Text(
              '$label：',
              maxLines: 1,
              style: TextStyle(
                fontFamily: XuanLiFonts.serif,
                fontSize: 12,
                fontWeight: FontWeight.w700,
                height: 1.35,
                color: ink,
              ),
            ),
          ),
          Expanded(
            child: Text(
              body,
              style: const TextStyle(fontSize: 12, height: 1.35, color: _ink),
            ),
          ),
        ],
      ),
    );
  }

  Widget _qr() {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: sharePaper,
            borderRadius: BorderRadius.circular(8),
          ),
          child: QrImageView(
            data: xuanliWebUrl,
            size: 58,
            padding: EdgeInsets.zero,
            backgroundColor: sharePaper,
            eyeStyle: const QrEyeStyle(
              eyeShape: QrEyeShape.square,
              color: shareNavy,
            ),
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

/// 宮職角色圖。有專圖就用專圖，否則用通用宮官像；載入失敗再畫一個剪影。
class PalaceIllustration extends StatelessWidget {
  final String palaceTitle;
  final Color ink;

  const PalaceIllustration({
    super.key,
    required this.palaceTitle,
    required this.ink,
  });

  @override
  Widget build(BuildContext context) {
    final asset = palaceIllustrationAsset(palaceTitle);
    return Semantics(
      label: '宮職圖：$palaceTitle',
      child: Image.asset(
        asset,
        key: ValueKey<String>(asset),
        fit: BoxFit.contain,
        filterQuality: FilterQuality.medium,
        errorBuilder: (context, error, stackTrace) =>
            _PalaceSilhouette(ink: ink),
      ),
    );
  }
}

class _PalaceSilhouette extends StatelessWidget {
  final Color ink;

  const _PalaceSilhouette({required this.ink});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _PalaceSilhouettePainter(ink),
      child: const SizedBox.expand(),
    );
  }
}

class _PalaceSilhouettePainter extends CustomPainter {
  final Color ink;

  _PalaceSilhouettePainter(this.ink);

  @override
  void paint(Canvas canvas, Size size) {
    final shortest = size.shortestSide;
    final center = Offset(size.width / 2, size.height / 2);
    final radius = shortest * 0.46;
    final disc = Paint()..color = ink.withValues(alpha: 0.08);
    canvas.drawCircle(center, radius, disc);
    final robe = Paint()..color = ink.withValues(alpha: 0.78);
    final headCenter = center + Offset(0, -radius * 0.22);
    canvas.drawOval(
      Rect.fromCenter(
        center: headCenter,
        width: radius * 0.62,
        height: radius * 0.72,
      ),
      robe,
    );
    final robePath = Path()
      ..moveTo(center.dx - radius * 0.72, center.dy + radius * 0.78)
      ..lineTo(center.dx - radius * 0.42, center.dy + radius * 0.05)
      ..quadraticBezierTo(
        center.dx,
        center.dy - radius * 0.08,
        center.dx + radius * 0.42,
        center.dy + radius * 0.05,
      )
      ..lineTo(center.dx + radius * 0.72, center.dy + radius * 0.78)
      ..close();
    canvas.drawPath(robePath, robe);
  }

  @override
  bool shouldRepaint(covariant _PalaceSilhouettePainter oldDelegate) =>
      oldDelegate.ink != ink;
}
