import 'package:flutter/material.dart';

import '../../theme/xuanli_theme.dart';
import 'onboarding_widgets.dart';

/// [BirthDataStep] 每次用戶改任何欄位都會經 [onChanged] 交返一份完整
/// 新 state，畀 [OnboardingFlow] 更新自己嘅 lifted state——呢個 widget
/// 本身唔存內部狀態。
class BirthDataState {
  final bool isLunar;
  final DateTime birthDate;
  final int? birthHour;
  final int birthMinute;
  final bool birthTimeUnknown;
  final String birthPlace;

  const BirthDataState({
    required this.isLunar,
    required this.birthDate,
    required this.birthHour,
    required this.birthMinute,
    required this.birthTimeUnknown,
    required this.birthPlace,
  });

  BirthDataState copyWith({
    bool? isLunar,
    DateTime? birthDate,
    int? birthHour,
    bool clearBirthHour = false,
    int? birthMinute,
    bool? birthTimeUnknown,
    String? birthPlace,
  }) {
    return BirthDataState(
      isLunar: isLunar ?? this.isLunar,
      birthDate: birthDate ?? this.birthDate,
      birthHour: clearBirthHour ? null : (birthHour ?? this.birthHour),
      birthMinute: birthMinute ?? this.birthMinute,
      birthTimeUnknown: birthTimeUnknown ?? this.birthTimeUnknown,
      birthPlace: birthPlace ?? this.birthPlace,
    );
  }
}

/// 地支時辰邊界（UI 顯示用，同 `scoring.dart` 嘅 `_zhiHourRange` 概念一樣
/// 但方向相反——嗰邊係地支查鐘點，呢邊係鐘點查地支/時辰名，屬於獨立嘅
/// UI-only 顯示邏輯，唔使同 engine 嗰張表耦合）。
const _shiChenBoundaries = [
  (23, 1, '子'), (1, 3, '丑'), (3, 5, '寅'), (5, 7, '卯'),
  (7, 9, '辰'), (9, 11, '巳'), (11, 13, '午'), (13, 15, '未'),
  (15, 17, '申'), (17, 19, '酉'), (19, 21, '戌'), (21, 23, '亥'),
];

String shiChenName(int hour) {
  for (final (start, end, name) in _shiChenBoundaries) {
    if (start > end) {
      if (hour >= start || hour < end) return '$name時';
    } else if (hour >= start && hour < end) {
      return '$name時';
    }
  }
  throw ArgumentError('hour must be 0-23, got $hour');
}

class BirthDataStep extends StatelessWidget {
  final bool isLunar;
  final DateTime birthDate;
  final int? birthHour;
  final int birthMinute;
  final bool birthTimeUnknown;
  final String birthPlace;
  final ValueChanged<BirthDataState> onChanged;
  final VoidCallback onNext;

  const BirthDataStep({
    super.key,
    required this.isLunar,
    required this.birthDate,
    required this.birthHour,
    required this.birthMinute,
    required this.birthTimeUnknown,
    required this.birthPlace,
    required this.onChanged,
    required this.onNext,
  });

  BirthDataState get _state => BirthDataState(
        isLunar: isLunar,
        birthDate: birthDate,
        birthHour: birthHour,
        birthMinute: birthMinute,
        birthTimeUnknown: birthTimeUnknown,
        birthPlace: birthPlace,
      );

  Future<void> _pickDate(BuildContext context) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: birthDate,
      firstDate: DateTime(1900),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      onChanged(_state.copyWith(birthDate: picked));
    }
  }

  Future<void> _pickTime(BuildContext context) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: birthHour ?? 9, minute: birthMinute),
    );
    if (picked != null) {
      onChanged(_state.copyWith(birthHour: picked.hour, birthMinute: picked.minute));
    }
  }

  Future<void> _editPlace(BuildContext context) async {
    final controller = TextEditingController(text: birthPlace);
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('出生地點'),
        content: TextField(controller: controller, autofocus: true),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: const Text('確定'),
          ),
        ],
      ),
    );
    if (result != null && result.trim().isNotEmpty) {
      onChanged(_state.copyWith(birthPlace: result.trim()));
    }
  }

  void _toggleTimeUnknown(bool v) {
    onChanged(_state.copyWith(
      birthTimeUnknown: v,
      clearBirthHour: v,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.xuanliColors;
    final dateLabel = '${birthDate.year} 年 ${birthDate.month} 月 ${birthDate.day} 日';
    final timeLabel = birthHour == null
        ? '未設定'
        : '${birthHour!.toString().padLeft(2, '0')}:'
            '${birthMinute.toString().padLeft(2, '0')}（${shiChenName(birthHour!)}）';

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(18, 6, 18, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const OnboardingProgressDots(currentStep: 0, totalSteps: 3),
          const SizedBox(height: 14),
          Text(
            '你嘅出生一刻',
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
            '八字由出生年月日時而定，我哋以此推算你嘅五行喜忌。資料只儲存喺你部機，唔會上傳。',
            style: TextStyle(fontSize: 12.5, color: colors.ink60, height: 1.7),
          ),
          const SizedBox(height: 16),
          OnboardingSegmentedToggle(
            options: const ['新曆', '農曆'],
            selectedIndex: isLunar ? 1 : 0,
            onChanged: (i) => onChanged(_state.copyWith(isLunar: i == 1)),
          ),
          const SizedBox(height: 14),
          OnboardingFieldRow(
            label: '出生日期',
            value: dateLabel,
            onTap: () => _pickDate(context),
          ),
          if (!birthTimeUnknown)
            OnboardingFieldRow(
              label: '出生時間',
              value: timeLabel,
              onTap: () => _pickTime(context),
            ),
          // 成行都撳得中——文字標籤本身唔會回應 tap，所以用 GestureDetector
          // 包起成行（連 Switch 埋一齊），等撳標籤文字都可以觸發同一個
          // toggle，等 tap target 大啲、體驗更符合預期（常見 UX pattern）。
          GestureDetector(
            onTap: () => _toggleTimeUnknown(!birthTimeUnknown),
            behavior: HitTestBehavior.opaque,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('我唔清楚出生時間', style: TextStyle(fontSize: 12.5, color: colors.ink60)),
                        Text(
                          '會改用簡易版推算，之後可以補返',
                          style: TextStyle(fontSize: 10.5, color: colors.ink30),
                        ),
                      ],
                    ),
                  ),
                  Switch(
                    value: birthTimeUnknown,
                    onChanged: _toggleTimeUnknown,
                    activeThumbColor: colors.jade,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          OnboardingFieldRow(
            label: '出生地點',
            value: birthPlace,
            onTap: () => _editPlace(context),
          ),
          OnboardingPrimaryButton(label: '下一步', onPressed: onNext),
        ],
      ),
    );
  }
}
