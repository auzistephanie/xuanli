import 'package:flutter/material.dart';

import '../theme/xuanli_theme.dart';

/// 籤詩豎排：四句各成一行由上而下，行序由右至左（傳統讀法）。
class VerticalVerse extends StatelessWidget {
  final List<String> verse;
  final double fontSize;
  final Color color;
  final double columnGap;

  const VerticalVerse({
    super.key,
    required this.verse,
    required this.color,
    this.fontSize = 22,
    this.columnGap = 16,
  });

  @override
  Widget build(BuildContext context) {
    final style = TextStyle(
      fontFamily: XuanLiFonts.serif,
      fontSize: fontSize,
      fontWeight: FontWeight.w600,
      height: 1.32,
      color: color,
    );
    return Directionality(
      textDirection: TextDirection.ltr,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 第一句擺最右。
          for (var i = verse.length - 1; i >= 0; i--) ...[
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [for (final ch in verse[i].characters) Text(ch, style: style)],
            ),
            if (i > 0) SizedBox(width: columnGap),
          ],
        ],
      ),
    );
  }
}
