import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../theme/xuanli_theme.dart';
import 'brand.dart';

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

/// 已出圖嘅宮職。同一 `palaceTitle` 共用一張（而家每個職位只得一個組合）。
/// 鍵係職位名，值係 `assets/palace/` 入面嘅扁平角色圖。
const palaceSampleAssets = <String, String>{
  '城守將軍': 'assets/palace/chengshou-jiangjun.png',
  '御用畫師': 'assets/palace/yuyong-huashi.png',
  '軍師': 'assets/palace/junshi.png',
  '大將軍': 'assets/palace/dajiangjun.png',
  '水師將軍': 'assets/palace/shuishi-jiangjun.png',
  '南衙統領': 'assets/palace/nanya-tongling.png',
};

/// 未出圖嘅職位用呢張通用宮官像，分享卡中間唔會空。
const palaceFallbackAsset = 'assets/palace/fallback.png';

String palaceIllustrationAsset(String palaceTitle) =>
    palaceSampleAssets[palaceTitle] ?? palaceFallbackAsset;

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

/// 卡頂：朱紅「吉」印＋Kairo。
class ShareBrand extends StatelessWidget {
  const ShareBrand({super.key});

  @override
  Widget build(BuildContext context) {
    return const Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        BrandSeal(size: 30),
        SizedBox(width: 10),
        Wordmark(fontSize: 26),
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
                style: TextStyle(
                  fontSize: 11,
                  color: shareGold.withValues(alpha: 0.9),
                ),
              ),
              const SizedBox(height: 5),
              Text(
                'Kairo・僅供參考',
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
