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

  // 呢兩個 flag 係防「一 frame 入面連撳兩下」嘅 debounce guard：
  // GestureDetector.onTap 嘅 closure 喺 build() 嗰陣就閂咗當時嘅
  // question/_quizIndex，但 setState 觸發嘅 rebuild 要等落一個 frame
  // 先真正執行 build()，所以撳完第一下之後、嗰個 rebuild 未發生之前，
  // 舊 closure 仲喺度、仲會 fire。第二下撳落去會攞住嗰個已經過時嘅
  // question/_quizIndex 再行多次 _answerQuiz，令 _quizAnswers 同題目
  // 對唔上（甚至喺最後一題撳兩下會令 length 衝過
  // mbtiQuizQuestions.length，落一個 build 攞
  // mbtiQuizQuestions[_quizIndex] 就會 RangeError）。
  //
  // 注意：setState(callback) 嘅 callback 本身係*同步*即刻執行㗎（淨係
  // 話「呢個 widget 要 rebuild」畀落一個 frame），唔係等到真正
  // rebuild 嗰刻先行——所以想喺「新 question/_quizIndex 真正生效」
  // 嗰刻先解鎖 guard，唔可以喺 setState callback 入面自己重設，一定
  // 要用 addPostFrameCallback，等成個 frame（包括 build()）行完先
  // reset，先至真係擋到同一 frame 入面嘅第二下撳。
  bool _answering = false;
  bool _finishing = false;

  void _setQuizMode(bool quizMode) {
    setState(() {
      _quizMode = quizMode;
      // 兩個模式各自嘅進度互不相干——切換模式嗰陣清埋另一邊嘅暫存
      // 狀態，咁樣先唔會出現「揀咗 16 宮格再切去測驗，答完 8 題
      // 之後啲舊 grid 選擇仲喺度」嗰種 stale state。
      _selectedGridType = null;
      _quizIndex = 0;
      _quizAnswers.clear();
      _answering = false;
    });
  }

  void _answerQuiz(String letter) {
    if (_answering) return;
    _answering = true;
    setState(() {
      _quizAnswers.add(letter);
      if (_quizAnswers.length == mbtiQuizQuestions.length) {
        widget.onDone(computeMbtiFromAnswers(_quizAnswers));
      } else {
        _quizIndex++;
      }
    });
    // 等呢個 frame（連 build() 都行埋）真正完成咗先解鎖，先至可以
    // 擋到同一 frame 入面、rebuild 未發生之前嘅第二下撳。
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _answering = false;
    });
  }

  void _finishGrid() {
    if (_finishing) return;
    _finishing = true;
    final type = _selectedGridType;
    if (type != null) {
      widget.onDone(type);
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _finishing = false;
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
          onPressed: _selectedGridType == null ? null : _finishGrid,
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
