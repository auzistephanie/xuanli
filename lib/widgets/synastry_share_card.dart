import 'package:flutter/material.dart';

import '../engine/synastry.dart';
import '../theme/xuanli_theme.dart';
import 'share_parts.dart';

/// 兩人合盤分享卡（9:16）。只放兩個組合名、關係名、合盤指數同相處之道——
/// **唔放姓名、出生日期、時辰**。
class SynastryShareCard extends StatelessWidget {
  final String comboNameA;
  final String comboNameB;
  final SynastryResult result;

  const SynastryShareCard({
    super.key,
    required this.comboNameA,
    required this.comboNameB,
    required this.result,
  });

  @override
  Widget build(BuildContext context) {
    return ShareCardBackground(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const ShareBrand(),
          const SizedBox(height: 14),
          const Text(
            '兩人合盤',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, letterSpacing: 6, color: shareGold),
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _comboName(comboNameA),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 10),
                child: Text('×',
                    style: TextStyle(
                        fontFamily: XuanLiFonts.serif, fontSize: 18, color: shareGold)),
              ),
              _comboName(comboNameB),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            result.name,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontFamily: XuanLiFonts.serif,
              fontSize: 46,
              fontWeight: FontWeight.w900,
              letterSpacing: 8,
              color: sharePaper,
            ),
          ),
          const SizedBox(height: 12),
          _score(),
          const SizedBox(height: 14),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 8,
            runSpacing: 8,
            children: [
              _pill(result.stemRelationLabel),
              _pill(result.branchLabel),
              _pill(result.complementLabel),
              _pill('MBTI・${result.mbtiLabel}'),
            ],
          ),
          const SizedBox(height: 16),
          _tip(result.tips.first),
          const Spacer(),
          const SizedBox(height: 8),
          const ShareFooter(headline: '掃碼同朋友合盤'),
        ],
      ),
    );
  }

  Widget _comboName(String name) => Text(
    name,
    style: const TextStyle(
      fontFamily: XuanLiFonts.serif,
      fontSize: 17,
      fontWeight: FontWeight.w700,
      letterSpacing: 2,
      color: sharePaper,
    ),
  );

  Widget _score() {
    return Column(
      children: [
        Text(
          '合盤指數',
          style: TextStyle(
            fontSize: 11,
            letterSpacing: 4,
            color: sharePaper.withValues(alpha: 0.6),
          ),
        ),
        const SizedBox(height: 2),
        Text(
          '${result.score}',
          style: const TextStyle(
            fontFamily: XuanLiFonts.serif,
            fontSize: 64,
            height: 1.1,
            fontWeight: FontWeight.w900,
            color: shareGold,
          ),
        ),
        Text(
          result.scoreTitle,
          style: const TextStyle(
            fontFamily: XuanLiFonts.serif,
            fontSize: 16,
            letterSpacing: 4,
            color: sharePaper,
          ),
        ),
      ],
    );
  }

  Widget _pill(String text) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 4),
    decoration: BoxDecoration(
      border: Border.all(color: shareGold.withValues(alpha: 0.7)),
      borderRadius: BorderRadius.circular(20),
    ),
    child: Text(
      text,
      style: const TextStyle(fontSize: 11.5, color: sharePaper),
    ),
  );

  Widget _tip(String text) => Container(
    padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
    decoration: BoxDecoration(
      color: sharePaper.withValues(alpha: 0.07),
      borderRadius: BorderRadius.circular(12),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '相處之道',
          style: TextStyle(fontSize: 11, letterSpacing: 3, color: shareGold),
        ),
        const SizedBox(height: 5),
        Text(
          text,
          style: TextStyle(fontSize: 12.5, height: 1.6, color: sharePaper.withValues(alpha: 0.92)),
        ),
      ],
    ),
  );
}
