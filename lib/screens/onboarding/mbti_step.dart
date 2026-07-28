import 'package:flutter/material.dart';

import '../../models/mbti_quiz.dart';
import '../../theme/xuanli_theme.dart';
import 'onboarding_widgets.dart';

class MbtiStep extends StatefulWidget {
  final ValueChanged<String> onDone;

  const MbtiStep({super.key, required this.onDone});

  @override
  State<MbtiStep> createState() => _MbtiStepState();
}

class _MbtiStepState extends State<MbtiStep> {
  bool _quizMode = false;
  String? _selectedGridType;
  int _quizIndex = 0;
  final List<String> _quizAnswers = [];

  void _setQuizMode(bool quizMode) {
    setState(() {
      _quizMode = quizMode;
      // 兩個模式各自嘅進度互不相干——切換模式嗰陣清埋另一邊嘅暫存
      // 狀態，咁樣先唔會出現「揀咗 16 宮格再切去測驗，答完 8 題
      // 之後啲舊 grid 選擇仲喺度」嗰種 stale state。
      _selectedGridType = null;
      _quizIndex = 0;
      _quizAnswers.clear();
    });
  }

  void _answerQuiz(String letter) {
    setState(() {
      _quizAnswers.add(letter);
      if (_quizAnswers.length == mbtiQuizQuestions.length) {
        widget.onDone(computeMbtiFromAnswers(_quizAnswers));
      } else {
        _quizIndex++;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.xuanliColors;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(18, 6, 18, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const OnboardingProgressDots(currentStep: 1, totalSteps: 3),
          const SizedBox(height: 14),
          Text(
            '你嘅性格底色',
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
            'MBTI 會影響我哋同你講嘢嘅方式，同埋活動建議嘅取向。',
            style: TextStyle(fontSize: 12.5, color: colors.ink60, height: 1.7),
          ),
          const SizedBox(height: 16),
          OnboardingSegmentedToggle(
            options: const ['我知我嘅類型', '快速測驗（8題）'],
            selectedIndex: _quizMode ? 1 : 0,
            onChanged: (i) => _setQuizMode(i == 1),
          ),
          const SizedBox(height: 16),
          if (_quizMode) _buildQuiz(colors) else _buildGrid(colors),
        ],
      ),
    );
  }

  Widget _buildGrid(XuanLiColors colors) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GridView.count(
          crossAxisCount: 4,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 8,
          crossAxisSpacing: 8,
          children: [
            for (final type in allMbtiTypes)
              GestureDetector(
                onTap: () => setState(() => _selectedGridType = type),
                child: Container(
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: _selectedGridType == type ? colors.gold : colors.cardSurface,
                    border: Border.all(
                      color: _selectedGridType == type ? colors.gold : colors.ink12,
                    ),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  child: Text(
                    type,
                    style: TextStyle(
                      fontFamily: XuanLiFonts.serif,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      color: _selectedGridType == type ? colors.ink : colors.ink60,
                    ),
                  ),
                ),
              ),
          ],
        ),
        OnboardingPrimaryButton(
          label: '下一步',
          onPressed: _selectedGridType == null
              ? null
              : () => widget.onDone(_selectedGridType!),
        ),
      ],
    );
  }

  Widget _buildQuiz(XuanLiColors colors) {
    final question = mbtiQuizQuestions[_quizIndex];
    final isLast = _quizIndex == mbtiQuizQuestions.length - 1;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: colors.cardSurface,
            border: Border.all(color: colors.ink12),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '第 ${_quizIndex + 1} / ${mbtiQuizQuestions.length} 題',
                style: TextStyle(
                  fontSize: 11,
                  color: colors.gold,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 2,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                question.prompt,
                style: TextStyle(
                  fontFamily: XuanLiFonts.serif,
                  fontSize: 16.5,
                  fontWeight: FontWeight.w600,
                  color: colors.ink,
                  height: 1.6,
                ),
              ),
              const SizedBox(height: 14),
              GestureDetector(
                key: const ValueKey('mbti-quiz-option-a'),
                onTap: () => _answerQuiz(question.optionALetter),
                child: _quizOption(colors, question.optionALabel),
              ),
              const SizedBox(height: 9),
              GestureDetector(
                onTap: () => _answerQuiz(question.optionBLetter),
                child: _quizOption(colors, question.optionBLabel),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Center(
          child: Text(
            isLast ? '答完呢題就計出你嘅型' : '',
            style: TextStyle(fontSize: 11, color: colors.ink30),
          ),
        ),
      ],
    );
  }

  Widget _quizOption(XuanLiColors colors, String label) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        border: Border.all(color: colors.ink12),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(label, style: TextStyle(fontSize: 13.5, color: colors.ink)),
    );
  }
}
