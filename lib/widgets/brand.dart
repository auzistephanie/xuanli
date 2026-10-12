import 'package:flutter/material.dart';

import '../theme/brand.dart';
import '../theme/xuanli_theme.dart';

/// 朱紅印章：一個字置中，兩個字直排。
class BrandSeal extends StatelessWidget {
  final String text;
  final double size;

  const BrandSeal({super.key, this.text = kBrandSealShort, this.size = 34});

  @override
  Widget build(BuildContext context) {
    final chars = text.split('');
    final fontSize = chars.length == 1 ? size * 0.5 : size * 0.34;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: KairoPalette.sealRed,
        borderRadius: BorderRadius.circular(size * 0.2),
        boxShadow: [
          BoxShadow(color: KairoPalette.sealRed.withValues(alpha: 0.35), blurRadius: size * 0.35),
        ],
      ),
      child: Container(
        margin: EdgeInsets.all(size * 0.08),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          border: Border.all(color: KairoPalette.paper.withValues(alpha: 0.85), width: size > 40 ? 1.2 : 0.8),
          borderRadius: BorderRadius.circular(size * 0.12),
        ),
        // 印章係固定正方形：系統大字體時縮細入框，唔好 overflow。
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final c in chars)
                Text(
                  c,
                  style: TextStyle(
                    fontFamily: XuanLiFonts.serif,
                    fontWeight: FontWeight.w900,
                    fontSize: fontSize,
                    height: 1.05,
                    color: KairoPalette.paper,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 金色漸變「Kairo」字。
class Wordmark extends StatelessWidget {
  final double fontSize;

  const Wordmark({super.key, this.fontSize = 22});

  @override
  Widget build(BuildContext context) {
    return ShaderMask(
      blendMode: BlendMode.srcIn,
      shaderCallback: (rect) => const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [KairoPalette.goldBright, KairoPalette.gold, KairoPalette.goldDeep],
        stops: [0, 0.6, 1],
      ).createShader(rect),
      child: Text(
        kBrandName,
        style: TextStyle(
          fontFamily: XuanLiFonts.wordmark,
          fontWeight: FontWeight.w600,
          fontSize: fontSize,
          letterSpacing: fontSize * 0.1,
          height: 1.1,
          color: Colors.white,
        ),
      ),
    );
  }
}
