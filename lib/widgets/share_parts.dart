import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../theme/xuanli_theme.dart';

/// 分享卡 QR code 指去嘅網址。QR 純粹畫喺圖上（本機生成），app 本身唔會連呢個網址。
const xuanliWebUrl = 'https://xuanli-opal.vercel.app';

/// 分享卡邏輯尺寸（9:16，以 pixelRatio 3 輸出 1080×1920，啱 IG Story）。
const shareCardSize = Size(360, 640);

// 分享卡一律用藏藍深色版（design html 檔案卡嘅配色），唔跟系統深淺色——
// 圖要喺任何人嘅 feed 入面睇落都一致。
const shareNavy = Color(0xFF1C2440);
const shareNavyDeep = Color(0xFF131829);
const sharePaper = Color(0xFFF6EFE2);
const shareGold = Color(0xFFC9A24B);
const shareSealRed = Color(0xFFB23A3A);

/// 所有分享卡共用嘅藏藍漸變底（組合卡、合盤卡）。
class ShareCardBackground extends StatelessWidget {
  final Widget child;

  const ShareCardBackground({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return SizedBox.fromSize(
      size: shareCardSize,
      child: Material(
        type: MaterialType.transparency,
        child: DecoratedBox(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [shareNavy, shareNavyDeep],
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(30, 28, 30, 22),
            child: child,
          ),
        ),
      ),
    );
  }
}

/// 卡頂：朱紅「玄」印＋「玄曆」。
class ShareBrand extends StatelessWidget {
  const ShareBrand({super.key});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          width: 30,
          height: 30,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: shareSealRed,
            borderRadius: BorderRadius.circular(5),
          ),
          child: const Text(
            '玄',
            style: TextStyle(
              fontFamily: XuanLiFonts.serif,
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: sharePaper,
              height: 1.1,
            ),
          ),
        ),
        const SizedBox(width: 10),
        const Text(
          '玄曆',
          style: TextStyle(
            fontFamily: XuanLiFonts.serif,
            fontSize: 20,
            fontWeight: FontWeight.w700,
            letterSpacing: 4,
            color: sharePaper,
          ),
        ),
      ],
    );
  }
}

/// 卡底：QR code＋掃碼提示。QR 內容只係網址，冇任何個人資料。
class ShareFooter extends StatelessWidget {
  final String headline;

  const ShareFooter({super.key, this.headline = '掃碼睇你嘅組合'});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // 米白底深色碼：對比最高，掃得最穩。四周留白（quiet zone）由 padding 提供。
        Container(
          padding: const EdgeInsets.all(5),
          decoration: BoxDecoration(
            color: sharePaper,
            borderRadius: BorderRadius.circular(8),
          ),
          child: QrImageView(
            data: xuanliWebUrl,
            size: 66,
            padding: EdgeInsets.zero,
            backgroundColor: sharePaper,
            eyeStyle: const QrEyeStyle(eyeShape: QrEyeShape.square, color: shareNavy),
            dataModuleStyle: const QrDataModuleStyle(
              dataModuleShape: QrDataModuleShape.square,
              color: shareNavy,
            ),
            semanticsLabel: '玄曆網站 QR code',
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                headline,
                style: TextStyle(
                  fontFamily: XuanLiFonts.serif,
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 2,
                  color: sharePaper.withValues(alpha: 0.95),
                ),
              ),
              const SizedBox(height: 3),
              Text(
                '免註冊・全離線・資料唔離機',
                style: TextStyle(fontSize: 11, color: shareGold.withValues(alpha: 0.9)),
              ),
              const SizedBox(height: 5),
              Text(
                '玄曆 XuanLi・僅供參考',
                style: TextStyle(
                  fontSize: 10,
                  letterSpacing: 1,
                  color: sharePaper.withValues(alpha: 0.4),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
