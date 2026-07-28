import 'package:flutter/material.dart';

import '../../theme/xuanli_theme.dart';

/// 頂部進度條（design html：3 段，行到嗰步 + 之前嘅段用金色）。
class OnboardingProgressDots extends StatelessWidget {
  final int currentStep; // 0, 1, 2
  final int totalSteps;

  const OnboardingProgressDots({
    super.key,
    required this.currentStep,
    required this.totalSteps,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.xuanliColors;
    return Row(
      children: [
        for (var i = 0; i < totalSteps; i++)
          Expanded(
            child: Container(
              height: 3,
              margin: EdgeInsets.only(right: i == totalSteps - 1 ? 0 : 5),
              decoration: BoxDecoration(
                color: i <= currentStep ? colors.gold : colors.ink12,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
      ],
    );
  }
}

/// 兩段式 segmented toggle（design html `.segs`，例如「新曆／農曆」）。
class OnboardingSegmentedToggle extends StatelessWidget {
  final List<String> options;
  final int selectedIndex;
  final ValueChanged<int> onChanged;

  const OnboardingSegmentedToggle({
    super.key,
    required this.options,
    required this.selectedIndex,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.xuanliColors;
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: colors.paper2,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          for (var i = 0; i < options.length; i++)
            Expanded(
              child: GestureDetector(
                onTap: () => onChanged(i),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 7),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: i == selectedIndex ? colors.cardSurface : null,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    options[i],
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: i == selectedIndex ? FontWeight.w700 : FontWeight.w400,
                      color: i == selectedIndex ? colors.ink : colors.ink60,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// 一行「標籤 + 值 + chevron」（design html `.fld`），撳落 call [onTap]。
class OnboardingFieldRow extends StatelessWidget {
  final String label;
  final String value;
  final VoidCallback onTap;

  const OnboardingFieldRow({
    super.key,
    required this.label,
    required this.value,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.xuanliColors;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 11),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: colors.cardSurface,
          border: Border.all(color: colors.ink12),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(fontSize: 11, color: colors.ink60, letterSpacing: 1),
                ),
                const SizedBox(height: 3),
                Text(
                  value,
                  style: TextStyle(
                    fontFamily: XuanLiFonts.serif,
                    fontSize: 15.5,
                    fontWeight: FontWeight.w600,
                    color: colors.ink,
                  ),
                ),
              ],
            ),
            Text('›', style: TextStyle(fontSize: 18, color: colors.ink30)),
          ],
        ),
      ),
    );
  }
}

/// 主按鈕（design html `.btnMain`，深藍底米黃字）。
class OnboardingPrimaryButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;

  const OnboardingPrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.xuanliColors;
    final enabled = onPressed != null;
    // GestureDetector (not ElevatedButton/TextButton) is deliberate here —
    // it's the only way to get this exact custom look (deep-ink fill,
    // serif letter-spaced label, no Material ripple) design-preview.html
    // calls for. That means screen readers get none of Material's built-in
    // button semantics for free, so Semantics() adds them back explicitly.
    return Semantics(
      button: true,
      enabled: enabled,
      label: label,
      child: GestureDetector(
        onTap: onPressed,
        child: Container(
          width: double.infinity,
          margin: const EdgeInsets.only(top: 8),
          padding: const EdgeInsets.symmetric(vertical: 14),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: enabled ? colors.ink : colors.ink30,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontFamily: XuanLiFonts.serif,
              fontSize: 15,
              fontWeight: FontWeight.w600,
              letterSpacing: 4,
              color: colors.paper,
            ),
          ),
        ),
      ),
    );
  }
}
