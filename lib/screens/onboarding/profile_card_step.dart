import 'package:flutter/material.dart';

import '../../engine/annual_outlook.dart';
import '../../engine/profile_builder.dart';
import '../../models/profile.dart';
import '../../services/storage_service.dart';
import '../../theme/xuanli_theme.dart';
import 'onboarding_widgets.dart';

/// 五行條顏色（design html 入面每行五行有自己嘅裝飾色，唔屬於全局
/// 品牌 token——木/火/土用返 XuanLiColors 嘅 jade/red/gold，金/水
/// 淨係呢個畫面用嘅裝飾色，直接寫死喺度）。
const _wuxingBarColors = {
  '木': Color(0xFF6CAE84),
  '火': Color(0xFFC96A6A),
  '土': Color(0xFFC9A24B),
  '金': Color(0xFF9AA3B8),
  '水': Color(0xFF5F87AD),
};
const _wuxingLabelColors = {
  '木': Color(0xFF8FD0A8),
  '火': Color(0xFFE08484),
  '土': Color(0xFFD9B46A),
  '金': Color(0xFFCFD4DE),
  '水': Color(0xFF8FB6D9),
};
const _wuxingOrder = ['木', '火', '土', '金', '水'];

class ProfileCardStep extends StatefulWidget {
  final String name;
  final DateTime birthDate;
  final int? birthHour;
  final int birthMinute;
  final String birthPlace;
  final String mbti;
  final VoidCallback onSaved;

  const ProfileCardStep({
    super.key,
    required this.name,
    required this.birthDate,
    required this.birthHour,
    required this.birthMinute,
    required this.birthPlace,
    required this.mbti,
    required this.onSaved,
  });

  @override
  State<ProfileCardStep> createState() => _ProfileCardStepState();
}

class _ProfileCardStepState extends State<ProfileCardStep> {
  late final Profile _profile = buildProfile(
    id: DateTime.now().microsecondsSinceEpoch.toString(),
    name: widget.name,
    birthDate: widget.birthDate,
    birthHour: widget.birthHour,
    birthMinute: widget.birthMinute,
    birthPlace: widget.birthPlace,
    mbti: widget.mbti,
  );

  bool _saving = false;

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await StorageService().savePrimaryProfile(_profile);
    } catch (_) {
      // 100% offline/local storage — 呢度出錯嘅唯一實際成因係
      // shared_preferences 平台通道罕見故障，唔應該靜靜哋令個掣
      // 永久 disabled（用戶冇辦法再撳）。重設 _saving 畀用戶可以再試，
      // 用 SnackBar 講返個錯（唔用 rethrow：呢個 widget 冇上層 error UI）。
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('儲存失敗，請再試一次')),
      );
      return;
    }
    if (!mounted) return;
    widget.onSaved();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.xuanliColors;
    final userYearZhi = _profile.pillars[0].substring(1);
    final outlook = computeAnnualOutlook(date: DateTime.now(), userYearZhi: userYearZhi);
    final avatarInitial = _profile.name.isNotEmpty ? _profile.name.substring(0, 1) : '玄';

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(18, 6, 18, 24),
      child: Column(
        children: [
          Text(
            '你嘅命理檔案',
            style: TextStyle(
              fontFamily: XuanLiFonts.serif,
              fontSize: 21,
              fontWeight: FontWeight.w700,
              color: colors.ink,
              letterSpacing: 2,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '之後所有推薦，都跟呢張卡而行。',
            style: TextStyle(fontSize: 12.5, color: colors.ink60),
          ),
          const SizedBox(height: 16),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF1C2440), Color(0xFF28325A)],
              ),
              borderRadius: BorderRadius.circular(XuanLiRadii.card),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 56,
                      height: 56,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: colors.red,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        avatarInitial,
                        style: TextStyle(
                          fontFamily: XuanLiFonts.serif,
                          fontWeight: FontWeight.w900,
                          fontSize: 22,
                          color: colors.paper,
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _profile.name,
                          style: TextStyle(
                            fontFamily: XuanLiFonts.serif,
                            fontSize: 19,
                            fontWeight: FontWeight.w700,
                            color: colors.paper,
                            letterSpacing: 2,
                          ),
                        ),
                        const SizedBox(height: 5),
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: colors.gold,
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                _profile.mbti,
                                style: TextStyle(
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w700,
                                  color: colors.ink,
                                ),
                              ),
                            ),
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: colors.paper.withValues(alpha: 0.16),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                '${_profile.dayMaster}日主',
                                style: TextStyle(fontSize: 10.5, color: colors.paper),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                for (final element in _wuxingOrder)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 7),
                    child: Row(
                      children: [
                        SizedBox(
                          width: 15,
                          child: Text(
                            element,
                            style: TextStyle(
                              fontFamily: XuanLiFonts.serif,
                              fontWeight: FontWeight.w700,
                              color: _wuxingLabelColors[element],
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(6),
                            child: LinearProgressIndicator(
                              value: (_profile.wuxing[element] ?? 0) / 100,
                              minHeight: 9,
                              backgroundColor: colors.paper.withValues(alpha: 0.14),
                              valueColor: AlwaysStoppedAnimation(_wuxingBarColors[element]),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        SizedBox(
                          width: 34,
                          child: Text(
                            '${_profile.wuxing[element] ?? 0}%',
                            textAlign: TextAlign.right,
                            style: TextStyle(
                              fontSize: 10.5,
                              color: colors.paper.withValues(alpha: 0.6),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    _profileStatBox(colors, '喜用神', _profile.favorable.join('・')),
                    const SizedBox(width: 8),
                    _profileStatBox(colors, '忌神', _profile.unfavorable.join('・')),
                    const SizedBox(width: 8),
                    _profileStatBox(colors, '紫微命宮', _profile.ziweiStar),
                  ],
                ),
                Container(
                  margin: const EdgeInsets.only(top: 12),
                  padding: const EdgeInsets.only(top: 9),
                  decoration: BoxDecoration(
                    border: Border(top: BorderSide(color: colors.paper.withValues(alpha: 0.25))),
                  ),
                  child: Text(
                    '肖${_profile.zodiac}・${outlook.summary} ｜ 檔案完整度 ${_profile.completeness}%',
                    style: TextStyle(fontSize: 11, color: colors.paper.withValues(alpha: 0.75)),
                  ),
                ),
              ],
            ),
          ),
          OnboardingPrimaryButton(
            label: '開始睇今日',
            onPressed: _saving ? null : _save,
          ),
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Text(
              '僅供參考・不代替專業意見',
              style: TextStyle(fontSize: 12.5, color: colors.ink60),
            ),
          ),
        ],
      ),
    );
  }

  Widget _profileStatBox(XuanLiColors colors, String label, String value) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: colors.paper.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: TextStyle(fontSize: 11.5, color: colors.paper.withValues(alpha: 0.75))),
            const SizedBox(height: 2),
            Text(
              value,
              style: TextStyle(
                fontFamily: XuanLiFonts.serif,
                fontSize: 13,
                color: colors.gold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
