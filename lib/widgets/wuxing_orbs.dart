import 'package:flutter/material.dart';

import '../theme/brand.dart';
import '../theme/xuanli_theme.dart';

const _order = ['木', '火', '土', '金', '水'];
const _orbColors = {
  '木': [Color(0xFFE9FFE0), Color(0xFF6FBF5A), Color(0xFF1F4D1A)],
  '火': [Color(0xFFFFE2D6), Color(0xFFE5604F), Color(0xFF5C1A12)],
  '土': [Color(0xFFFFF6D8), Color(0xFFD1A650), Color(0xFF5A4314)],
  '金': [Color(0xFFFFFFFF), Color(0xFFC8CCD8), Color(0xFF4B5068)],
  '水': [Color(0xFFDFF3FF), Color(0xFF4F8FD6), Color(0xFF132C55)],
};

const _maxOrb = 40.0;

/// 五行晶球：球直徑 18–40 跟百分比（0–100）。預設標籤色係淺紙色，
/// 擺喺深色卡上面用。
class WuxingOrbs extends StatelessWidget {
  final Map<String, int> wuxing;
  final Color labelColor;

  const WuxingOrbs({super.key, required this.wuxing, this.labelColor = KairoPalette.paper});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        for (final e in _order) _orb(e, wuxing[e] ?? 0),
      ],
    );
  }

  Widget _orb(String element, int pct) {
    final d = 18 + 22 * (pct.clamp(0, 100) / 100);
    final c = _orbColors[element]!;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // 固定高度：細球同大球底部對齊，標籤排一條線。
        SizedBox(
          height: _maxOrb,
          child: Align(
            alignment: Alignment.bottomCenter,
            child: Container(
              key: ValueKey('orb-$element'),
              width: d,
              height: d,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(center: const Alignment(-0.36, -0.44), colors: c, stops: const [0, 0.42, 1]),
                boxShadow: const [BoxShadow(color: Color(0x66000000), blurRadius: 10, spreadRadius: -3, offset: Offset(0, 6))],
              ),
            ),
          ),
        ),
        const SizedBox(height: 6),
        Text(element,
            style: TextStyle(fontFamily: XuanLiFonts.serif, fontWeight: FontWeight.w700, fontSize: 13, color: labelColor)),
        Text('$pct%', style: TextStyle(fontSize: 10.5, color: labelColor.withValues(alpha: 0.62))),
      ],
    );
  }
}
