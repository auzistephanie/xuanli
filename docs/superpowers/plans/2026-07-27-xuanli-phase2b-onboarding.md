# XuanLi Phase 2b — Onboarding Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build the real 3-step onboarding flow (spec §9.1: 出生資料 → MBTI → 命理檔案卡) that replaces `main.dart`'s `_OnboardingPlaceholder`, so a first-time user can actually create a profile and land on the (still-placeholder) tab shell.

**Architecture:** Two small new pure-Dart pieces first (a simplified "流年" annual-outlook engine function, and the MBTI 8-question quiz content + scoring — the latter is UI-only content, not engine logic, so it lives in `lib/models/` as a plain const list rather than a JSON asset). Then a shared small-widgets file (progress dots, field row, segmented toggle, primary button) to avoid re-styling the same `.fld`/`.segs`/`.btnMain` patterns three times. Then the three step screens, each a focused `StatelessWidget`/`StatefulWidget` taking current state + an `onNext` callback — no shared mutable state class, just lifted state in the parent `OnboardingFlow`. Finally `OnboardingFlow` (owns all the field state across steps) and the `main.dart` wiring (replacing the placeholder, extracting `TabShell` to its own file so onboarding can navigate to it without importing `main.dart`).

**Tech Stack:** Flutter (Material 3), existing Phase 2a foundations (`XuanLiTheme`/`XuanLiColors`/`XuanLiRadii`/`context.xuanliColors`, `StorageService`, `buildProfile()`), `lunar` package (for the new annual-outlook function and lunar-calendar date conversion via the already-existing `lunarToSolarDate()`).

---

## Two scope decisions already confirmed with Stephanie (don't re-litigate)

1. **MBTI quiz content** (8 questions, 2 per axis, A/B options) doesn't exist anywhere in the repo yet — unlike `combos.json`'s 160 pre-written templates. Stephanie asked for a first draft to be written as part of this plan (Task 2, below) — she'll review/edit after it ships, this isn't precious/locked content the way `combos.json` is.
2. **"流年" (annual outlook) on the profile card** — design html shows `丙午流年：肖兔・本年平順，留意農曆五月人際變動` but no engine logic for "does this YEAR clash with the user's zodiac" exists yet (only day-level clash). Stephanie confirmed: build a simplified version now (year ganzhi + zodiac-clash boolean + one of two template sentences) — not a full annual-fortune system.

---

## File Structure

```
xuanli/
├── lib/
│   ├── engine/
│   │   └── annual_outlook.dart        # NEW — pure: year ganzhi + zodiac-clash + template text
│   ├── models/
│   │   └── mbti_quiz.dart             # NEW — 8 quiz questions (const data) + computeMbtiFromAnswers()
│   ├── screens/
│   │   ├── tab_shell.dart             # NEW — TabShell extracted out of main.dart
│   │   └── onboarding/
│   │       ├── onboarding_widgets.dart    # NEW — shared: progress dots, field row, segmented toggle, primary button
│   │       ├── birth_data_step.dart       # NEW — Step 1 UI
│   │       ├── mbti_step.dart             # NEW — Step 2 UI (16-grid or 8Q quiz)
│   │       ├── profile_card_step.dart     # NEW — Step 3 UI (builds + saves Profile)
│   │       └── onboarding_flow.dart       # NEW — owns state, switches between the 3 steps
│   └── main.dart                      # MODIFY — route to OnboardingFlow, import TabShell from new file
├── test/
│   ├── engine/
│   │   └── annual_outlook_test.dart       # NEW
│   ├── models/
│   │   └── mbti_quiz_test.dart            # NEW
│   ├── screens/
│   │   └── onboarding/
│   │       ├── birth_data_step_test.dart      # NEW
│   │       ├── mbti_step_test.dart            # NEW
│   │       ├── profile_card_step_test.dart    # NEW
│   │       └── onboarding_flow_test.dart      # NEW
│   └── widget_test.dart               # unchanged (still tests bootstrap -> onboarding placeholder text is
│                                       #   gone now, see Task 8 — this file needs a small update there)
```

---

### Task 1: `lib/engine/annual_outlook.dart` — simplified 流年 (annual outlook)

**Files:**
- Create: `lib/engine/annual_outlook.dart`
- Create: `test/engine/annual_outlook_test.dart`

- [ ] **Step 1: Write the failing test**

Create `test/engine/annual_outlook_test.dart`:

```dart
import 'package:test/test.dart';
import 'package:xuanli/engine/annual_outlook.dart';

void main() {
  group('computeAnnualOutlook', () {
    test('2026 年（丙午）對肖兔用戶（年支卯）：唔沖太歲', () {
      final outlook = computeAnnualOutlook(
        date: DateTime(2026, 7, 11),
        userYearZhi: '卯',
      );

      expect(outlook.yearGanZhi, '丙午');
      expect(outlook.isZodiacClash, isFalse);
      expect(outlook.summary, contains('丙午流年'));
      expect(outlook.summary, contains('平順'));
    });

    test('2026 年（丙午）對肖鼠用戶（年支子）：沖太歲（子午相沖）', () {
      final outlook = computeAnnualOutlook(
        date: DateTime(2026, 7, 11),
        userYearZhi: '子',
      );

      expect(outlook.yearGanZhi, '丙午');
      expect(outlook.isZodiacClash, isTrue);
      expect(outlook.summary, contains('沖太歲'));
    });

    test('yearGanZhi 一定係天干+地支兩個字', () {
      final outlook = computeAnnualOutlook(
        date: DateTime(2025, 1, 1),
        userYearZhi: '卯',
      );
      expect(outlook.yearGanZhi.length, 2);
    });
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `dart test test/engine/annual_outlook_test.dart`
Expected: FAIL — `Error: Not found: 'package:xuanli/engine/annual_outlook.dart'`.

- [ ] **Step 3: Write the implementation**

Create `lib/engine/annual_outlook.dart`:

```dart
import 'package:lunar/lunar.dart';
import 'wuxing_tables.dart';

/// 流年概覽（spec §9.1 命理檔案卡「流年+沖太歲提示」）——MVP 簡化版，
/// 淨係計算今年天干地支 + 沖唔沖用戶生肖，唔做完整流年吉凶排盤
/// （同 ziwei.dart 降級版一樣嘅範圍決定：夠用、deterministic，
/// 唔喺 MVP 度追求命理學上完整——已同 Stephanie 確認）。
class AnnualOutlook {
  final String yearGanZhi; // "丙午"
  final bool isZodiacClash; // 今年地支沖唔沖用戶年支（沖太歲）
  final String summary; // 模板文案，畀檔案卡直接顯示

  AnnualOutlook({
    required this.yearGanZhi,
    required this.isZodiacClash,
    required this.summary,
  });
}

/// [date] 通常傳今日；[userYearZhi] = 用戶四柱年支
/// （`profile.pillars[0]` 最後一個字）。
AnnualOutlook computeAnnualOutlook({
  required DateTime date,
  required String userYearZhi,
}) {
  final lunar = Solar.fromYmd(date.year, date.month, date.day).getLunar();
  final yearGanZhi = lunar.getYearInGanZhi();
  final yearZhi = yearGanZhi.substring(1);
  final isZodiacClash = zhiClash[yearZhi] == userYearZhi;

  final summary = isZodiacClash
      ? '$yearGanZhi流年：沖太歲，流年運勢反覆，凡事宜留一線，忌臨時改大計。'
      : '$yearGanZhi流年：本年整體平順，留意人際關係嘅小變動。';

  return AnnualOutlook(
    yearGanZhi: yearGanZhi,
    isZodiacClash: isZodiacClash,
    summary: summary,
  );
}
```

(`lunar.getYearInGanZhi()` returns stem/branch characters directly — these 22 characters never need `traditionalize()`, same as `almanac.dart`'s `ganzhiDay` which also skips it.)

- [ ] **Step 4: Run test to verify it passes**

Run: `dart test test/engine/annual_outlook_test.dart -v`
Expected: PASS (all 3 tests).

- [ ] **Step 5: Commit**

```bash
git add lib/engine/annual_outlook.dart test/engine/annual_outlook_test.dart
git commit -m "feat(engine): add computeAnnualOutlook() — simplified 流年/沖太歲 for profile card"
```

---

### Task 2: `lib/models/mbti_quiz.dart` — 8-question quiz content + scoring

**Files:**
- Create: `lib/models/mbti_quiz.dart`
- Create: `test/models/mbti_quiz_test.dart`

- [ ] **Step 1: Write the failing test**

Create `test/models/mbti_quiz_test.dart`:

```dart
import 'package:test/test.dart';
import 'package:xuanli/models/mbti_quiz.dart';

void main() {
  group('mbtiQuizQuestions', () {
    test('啱啱 8 題，每軸（EI/SN/TF/JP）啱啱 2 題', () {
      expect(mbtiQuizQuestions.length, 8);
      for (final axis in ['EI', 'SN', 'TF', 'JP']) {
        expect(
          mbtiQuizQuestions.where((q) => q.axis == axis).length,
          2,
          reason: '$axis 軸應該有 2 題',
        );
      }
    });

    test('每題嘅 optionALetter/optionBLetter 都屬於自己嗰軸嘅兩個字母', () {
      const axisLetters = {
        'EI': {'E', 'I'},
        'SN': {'S', 'N'},
        'TF': {'T', 'F'},
        'JP': {'J', 'P'},
      };
      for (final q in mbtiQuizQuestions) {
        final letters = axisLetters[q.axis]!;
        expect(letters.contains(q.optionALetter), isTrue);
        expect(letters.contains(q.optionBLetter), isTrue);
        expect(q.optionALetter, isNot(q.optionBLetter));
      }
    });
  });

  group('computeMbtiFromAnswers', () {
    test('8 題全部一致答案 -> 對應 4 字母型', () {
      final result = computeMbtiFromAnswers(['I', 'I', 'S', 'S', 'F', 'F', 'J', 'J']);
      expect(result, 'ISFJ');
    });

    test('某軸 2 題打和（1-1）-> 用嗰軸第一題答案做決定性一票', () {
      // EI 第一題答 I，第二題答 E（打和）；其餘三軸兩題一致。
      final result = computeMbtiFromAnswers(['I', 'E', 'N', 'N', 'T', 'T', 'P', 'P']);
      expect(result, 'INTP');
    });

    test('answers 長度唔啱 8 -> throw ArgumentError', () {
      expect(() => computeMbtiFromAnswers(['I', 'E']), throwsArgumentError);
    });
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `dart test test/models/mbti_quiz_test.dart`
Expected: FAIL — `Error: Not found: 'package:xuanli/models/mbti_quiz.dart'`.

- [ ] **Step 3: Write the implementation**

Create `lib/models/mbti_quiz.dart`:

```dart
/// MBTI 8 題快測（spec §9.1：「我知我嘅類型」16 宮格 或 8 題快測，
/// 每軸 2 題，A/B 選項，即場計型）。題目內容係 onboarding 專用文案，
/// 唔涉及 engine 演算法，所以淨係一個 plain Dart const list，唔使
/// 走 JSON asset 嗰套（同 combos.json/activities.json 嗰啲畀 engine
/// 消費嘅數據唔同——呢個淨係 UI 用）。
///
/// ⚠️ 呢 8 題文案係第一稿（Stephanie 已確認由 Claude 幫手擬），
/// 未算最終定稿，之後可以再執靚佢，唔屬於「已寫好唔准改」嗰類內容。
class MbtiQuizQuestion {
  final String axis; // "EI" | "SN" | "TF" | "JP"
  final String prompt;
  final String optionALabel;
  final String optionALetter;
  final String optionBLabel;
  final String optionBLetter;

  const MbtiQuizQuestion({
    required this.axis,
    required this.prompt,
    required this.optionALabel,
    required this.optionALetter,
    required this.optionBLabel,
    required this.optionBLetter,
  });
}

const List<MbtiQuizQuestion> mbtiQuizQuestions = [
  MbtiQuizQuestion(
    axis: 'EI',
    prompt: '放假嗰日，你會更想——',
    optionALabel: '自己一個慢慢嘆，叉返電',
    optionALetter: 'I',
    optionBLabel: '約朋友出去，愈熱鬧愈精神',
    optionBLetter: 'E',
  ),
  MbtiQuizQuestion(
    axis: 'EI',
    prompt: '去到一個派對，你通常——',
    optionALabel: '識返幾個熟人就企喺度傾偈',
    optionALetter: 'I',
    optionBLabel: '周圍搭訕，識到邊個得邊個',
    optionBLetter: 'E',
  ),
  MbtiQuizQuestion(
    axis: 'SN',
    prompt: '睇一份計劃書，你會先留意——',
    optionALabel: '實際嘅步驟同數字',
    optionALetter: 'S',
    optionBLabel: '背後嘅大方向同可能性',
    optionBLetter: 'N',
  ),
  MbtiQuizQuestion(
    axis: 'SN',
    prompt: '講件事畀朋友聽，你會——',
    optionALabel: '由頭到尾交代晒細節',
    optionALetter: 'S',
    optionBLabel: '跳去重點，留返啲畀佢哋自己諗',
    optionBLetter: 'N',
  ),
  MbtiQuizQuestion(
    axis: 'TF',
    prompt: '朋友同你呻返份工唔開心，你會——',
    optionALabel: '同佢分析下件事點解會咁',
    optionALetter: 'T',
    optionBLabel: '先陪佢感受吓，聽佢講',
    optionBLetter: 'F',
  ),
  MbtiQuizQuestion(
    axis: 'TF',
    prompt: '決定緊要嘢嗰陣，你比較信——',
    optionALabel: '邏輯同利弊分析',
    optionALetter: 'T',
    optionBLabel: '自己嘅感覺同對人嘅影響',
    optionBLetter: 'F',
  ),
  MbtiQuizQuestion(
    axis: 'JP',
    prompt: '出門旅行，你會——',
    optionALabel: '行程排到實一實，心裡先踏實',
    optionALetter: 'J',
    optionBLabel: '淨係訂機票酒店，其餘到時算',
    optionBLetter: 'P',
  ),
  MbtiQuizQuestion(
    axis: 'JP',
    prompt: '死線前一日，你通常——',
    optionALabel: '早就搞掂晒，淨係等交',
    optionALetter: 'J',
    optionBLabel: '先開始衝刺，愈迫愈有火',
    optionBLetter: 'P',
  ),
];

/// 16 個 MBTI 類型（「我知我嘅類型」16 宮格用）。
const List<String> allMbtiTypes = [
  'INTJ', 'INTP', 'ENTJ', 'ENTP', 'INFJ', 'INFP', 'ENFJ', 'ENFP',
  'ISTJ', 'ISFJ', 'ESTJ', 'ESFJ', 'ISTP', 'ISFP', 'ESTP', 'ESFP',
];

/// [answers] 要啱啱 8 個元素，每個對應 [mbtiQuizQuestions] 同一 index
/// 題目揀咗嘅字母。
String computeMbtiFromAnswers(List<String> answers) {
  if (answers.length != mbtiQuizQuestions.length) {
    throw ArgumentError(
      'answers must have exactly ${mbtiQuizQuestions.length} elements, '
      'got ${answers.length}',
    );
  }

  const axisOrder = ['EI', 'SN', 'TF', 'JP'];
  final result = StringBuffer();

  for (final axis in axisOrder) {
    final axisIndices = [
      for (var i = 0; i < mbtiQuizQuestions.length; i++)
        if (mbtiQuizQuestions[i].axis == axis) i,
    ];
    // 2 題投票，打和（1-1）用第一題做決定性一票。淨係 2 票嘅情況下，
    // 「打和用第一題」呢條規則本身已經蓋晒「兩題一致」嗰種情況
    // （一致嗰陣第一題答案就係嗰票結果），所以淨係讀第一題答案已經
    // 足夠——唔係漏咗第二題唔計，而係規則本身令佢喺計分嗰下冧埋。
    // 第二題喺 UI 層面仍然係用戶要答嘅 8 題之一，唔係擺設。
    result.write(answers[axisIndices[0]]);
  }

  return result.toString();
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `dart test test/models/mbti_quiz_test.dart -v`
Expected: PASS (all 5 tests).

- [ ] **Step 5: Commit**

```bash
git add lib/models/mbti_quiz.dart test/models/mbti_quiz_test.dart
git commit -m "feat(models): add MBTI 8-question quiz content + computeMbtiFromAnswers()"
```

---

### Task 3: `lib/screens/onboarding/onboarding_widgets.dart` — shared onboarding UI pieces

**Files:**
- Create: `lib/screens/onboarding/onboarding_widgets.dart`

Pulls out the repeated design-html patterns (`.segs`/`.fld`/`.btnMain`/progress dots/`.toggleRow`) so the 3 step screens don't each re-style the same containers. No test file for this task — it's pure presentational widgets with no logic branches to unit-test; its correctness is verified visually when the step screens that use it are reviewed (Tasks 4-6), and structurally by `flutter analyze` + the step widget tests exercising it indirectly.

- [ ] **Step 1: Write the file**

Create `lib/screens/onboarding/onboarding_widgets.dart`:

```dart
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
    return GestureDetector(
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
    );
  }
}
```

- [ ] **Step 2: Verify it compiles**

Run: `flutter analyze`
Expected: `No issues found!` (this file isn't used anywhere yet, but it must still compile cleanly — an unused-file compile error would still surface here).

- [ ] **Step 3: Commit**

```bash
git add lib/screens/onboarding/onboarding_widgets.dart
git commit -m "feat(onboarding): add shared onboarding UI pieces (progress dots, field row, segmented toggle, primary button)"
```

---

### Task 4: `lib/screens/onboarding/birth_data_step.dart` — Step 1 UI

**Files:**
- Create: `lib/screens/onboarding/birth_data_step.dart`
- Create: `test/screens/onboarding/birth_data_step_test.dart`

Per spec §9.1 ①: 新曆/農曆 segmented switch, date picker, time picker (showing Chinese 時辰 name), "我唔清楚出生時間" toggle, 地點 text field (default 香港), "下一步" button.

- [ ] **Step 1: Write the failing test**

Create `test/screens/onboarding/birth_data_step_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xuanli/screens/onboarding/birth_data_step.dart';
import 'package:xuanli/theme/xuanli_theme.dart';

void main() {
  // `theme:` matters here, not just cosmetics — every onboarding widget
  // reads `context.xuanliColors`, which requires XuanLiTheme's
  // ThemeExtension to be present on the ambient theme (same as main.dart
  // always provides it). Without this, the first themed widget throws a
  // null-check failure before any test assertion runs.
  Widget wrap(Widget child) =>
      MaterialApp(theme: XuanLiTheme.light(), home: Scaffold(body: child));

  testWidgets('顯示標題、預設地點「香港」，下一步預設可撳', (tester) async {
    var nextCalled = false;
    await tester.pumpWidget(wrap(BirthDataStep(
      isLunar: false,
      birthDate: DateTime(1999, 9, 20),
      birthHour: 9,
      birthMinute: 30,
      birthTimeUnknown: false,
      birthPlace: '香港',
      onChanged: (_) {},
      onNext: () => nextCalled = true,
    )));

    expect(find.text('你嘅出生一刻'), findsOneWidget);
    expect(find.text('香港'), findsOneWidget);

    await tester.tap(find.text('下一步'));
    await tester.pump();
    expect(nextCalled, isTrue);
  });

  testWidgets('顯示時辰中文名（09:30 -> 巳時）', (tester) async {
    await tester.pumpWidget(wrap(BirthDataStep(
      isLunar: false,
      birthDate: DateTime(1999, 9, 20),
      birthHour: 9,
      birthMinute: 30,
      birthTimeUnknown: false,
      birthPlace: '香港',
      onChanged: (_) {},
      onNext: () {},
    )));

    expect(find.textContaining('巳時'), findsOneWidget);
  });

  testWidgets('撳「我唔清楚出生時間」toggle 會通知 onChanged(birthTimeUnknown: true)', (tester) async {
    BirthDataState? changed;
    await tester.pumpWidget(wrap(BirthDataStep(
      isLunar: false,
      birthDate: DateTime(1999, 9, 20),
      birthHour: 9,
      birthMinute: 30,
      birthTimeUnknown: false,
      birthPlace: '香港',
      onChanged: (s) => changed = s,
      onNext: () {},
    )));

    await tester.tap(find.text('我唔清楚出生時間'));
    await tester.pump();

    expect(changed, isNotNull);
    expect(changed!.birthTimeUnknown, isTrue);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/screens/onboarding/birth_data_step_test.dart`
Expected: FAIL — `Error: Not found: 'package:xuanli/screens/onboarding/birth_data_step.dart'`.

- [ ] **Step 3: Write the implementation**

Create `lib/screens/onboarding/birth_data_step.dart`:

```dart
import 'package:flutter/material.dart';

import '../../theme/xuanli_theme.dart';
import 'onboarding_widgets.dart';

/// [BirthDataStep] 每次用戶改任何欄位都會經 [onChanged] 交返一份完整
/// 新 state，畀 [OnboardingFlow] 更新自己嘅 lifted state——呢個 widget
/// 本身唔存內部狀態（除咗掣一啲純 UI-only 嘅嘢，見下面）。
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
          Padding(
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
                  onChanged: (v) => onChanged(_state.copyWith(
                    birthTimeUnknown: v,
                    clearBirthHour: v,
                  )),
                  activeThumbColor: colors.jade,
                ),
              ],
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
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/screens/onboarding/birth_data_step_test.dart -v`
Expected: PASS (all 3 tests).

- [ ] **Step 5: `flutter analyze` clean**

Run: `flutter analyze`
Expected: `No issues found!`

- [ ] **Step 6: Commit**

```bash
git add lib/screens/onboarding/birth_data_step.dart test/screens/onboarding/birth_data_step_test.dart
git commit -m "feat(onboarding): add Step 1 UI — birth data (solar/lunar, date/time, unknown-time toggle, place)"
```

---

### Task 5: `lib/screens/onboarding/mbti_step.dart` — Step 2 UI

**Files:**
- Create: `lib/screens/onboarding/mbti_step.dart`
- Create: `test/screens/onboarding/mbti_step_test.dart`

Per spec §9.1 ②: toggle between "我知我嘅類型" (16-grid direct select) and "快速測驗（8題）" (one question at a time, A/B options, axis chips, progress "第 N / 8 題").

- [ ] **Step 1: Write the failing test**

Create `test/screens/onboarding/mbti_step_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xuanli/screens/onboarding/mbti_step.dart';
import 'package:xuanli/theme/xuanli_theme.dart';

void main() {
  // See birth_data_step_test.dart's wrap() for why `theme:` is required
  // here, not optional — context.xuanliColors needs it present.
  Widget wrap(Widget child) =>
      MaterialApp(theme: XuanLiTheme.light(), home: Scaffold(body: child));

  testWidgets('16 宮格模式：撳一個型別再撳下一步，callback 攞返嗰個型別', (tester) async {
    String? result;
    await tester.pumpWidget(wrap(MbtiStep(onDone: (mbti) => result = mbti)));

    expect(find.text('你嘅性格底色'), findsOneWidget);
    await tester.tap(find.text('ISFP'));
    await tester.pump();
    await tester.tap(find.text('下一步'));
    await tester.pump();

    expect(result, 'ISFP');
  });

  testWidgets('切去快速測驗模式，答晒 8 題之後自動計出型別', (tester) async {
    String? result;
    await tester.pumpWidget(wrap(MbtiStep(onDone: (mbti) => result = mbti)));

    await tester.tap(find.text('快速測驗（8題）'));
    await tester.pump();
    expect(find.textContaining('第 1 / 8 題'), findsOneWidget);

    // 答晒 8 題，每次揀第一個選項（optionA）。
    for (var i = 0; i < 8; i++) {
      final buttons = find.byType(GestureDetector);
      // 揀本題嘅 optionA：畫面入面「下一題」/"完成" 按鈕之前嗰個 GestureDetector。
      // 用文字揾更穩陣：搵住兩個選項入面第一個（optionA 喺上面）。
      await tester.tap(find.byKey(const ValueKey('mbti-quiz-option-a')));
      await tester.pump();
    }

    expect(result, isNotNull);
    expect(result!.length, 4);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/screens/onboarding/mbti_step_test.dart`
Expected: FAIL — `Error: Not found: 'package:xuanli/screens/onboarding/mbti_step.dart'`.

- [ ] **Step 3: Write the implementation**

Create `lib/screens/onboarding/mbti_step.dart`:

```dart
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
            onChanged: (i) => setState(() => _quizMode = i == 1),
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
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/screens/onboarding/mbti_step_test.dart -v`
Expected: PASS (both tests).

- [ ] **Step 5: `flutter analyze` clean**

Run: `flutter analyze`
Expected: `No issues found!`

- [ ] **Step 6: Commit**

```bash
git add lib/screens/onboarding/mbti_step.dart test/screens/onboarding/mbti_step_test.dart
git commit -m "feat(onboarding): add Step 2 UI — MBTI (16-grid select or 8-question quiz)"
```

---

### Task 6: `lib/screens/onboarding/profile_card_step.dart` — Step 3 UI

**Files:**
- Create: `lib/screens/onboarding/profile_card_step.dart`
- Create: `test/screens/onboarding/profile_card_step_test.dart`

Per spec §9.1 ③: 命理檔案卡（藏藍卡：頭像縮寫、MBTI 金 chip、五行橫條、喜用/忌神/紫微、流年+沖太歲提示、完整度%）→「開始睇今日」button that saves the profile and navigates onward. Disclaimer text at the bottom.

- [ ] **Step 1: Write the failing test**

Create `test/screens/onboarding/profile_card_step_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:xuanli/services/storage_service.dart';
import 'package:xuanli/screens/onboarding/profile_card_step.dart';
import 'package:xuanli/theme/xuanli_theme.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  // See birth_data_step_test.dart's wrap() for why `theme:` is required
  // here, not optional — context.xuanliColors needs it present.
  Widget wrap(Widget child) =>
      MaterialApp(theme: XuanLiTheme.light(), home: Scaffold(body: child));

  testWidgets('用阿玄嘅出生資料起檔案卡：顯示日主/MBTI/五行/完整度', (tester) async {
    await tester.pumpWidget(wrap(ProfileCardStep(
      name: '阿玄',
      birthDate: DateTime(1999, 9, 20),
      birthHour: 9,
      birthMinute: 30,
      birthPlace: '香港',
      mbti: 'ISFP',
      onSaved: () {},
    )));
    await tester.pumpAndSettle();

    expect(find.text('阿玄'), findsOneWidget);
    expect(find.textContaining('ISFP'), findsOneWidget);
    expect(find.textContaining('乙木'), findsWidgets);
    expect(find.textContaining('100%'), findsOneWidget);
  });

  testWidgets('撳「開始睇今日」會存 profile 落 StorageService 並 call onSaved', (tester) async {
    var savedCalled = false;
    await tester.pumpWidget(wrap(ProfileCardStep(
      name: '阿玄',
      birthDate: DateTime(1999, 9, 20),
      birthHour: 9,
      birthMinute: 30,
      birthPlace: '香港',
      mbti: 'ISFP',
      onSaved: () => savedCalled = true,
    )));
    await tester.pumpAndSettle();

    await tester.tap(find.text('開始睇今日'));
    await tester.pumpAndSettle();

    expect(savedCalled, isTrue);
    final saved = await StorageService().loadPrimaryProfile();
    expect(saved, isNotNull);
    expect(saved!.name, '阿玄');
    expect(saved.mbti, 'ISFP');
    expect(saved.dayMaster, '乙木');
  });

  testWidgets('冇時辰（降級模式）：完整度顯示 80%', (tester) async {
    await tester.pumpWidget(wrap(ProfileCardStep(
      name: '阿玄',
      birthDate: DateTime(1999, 9, 20),
      birthHour: null,
      birthMinute: 0,
      birthPlace: '香港',
      mbti: 'ISFP',
      onSaved: () {},
    )));
    await tester.pumpAndSettle();

    expect(find.textContaining('80%'), findsOneWidget);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/screens/onboarding/profile_card_step_test.dart`
Expected: FAIL — `Error: Not found: 'package:xuanli/screens/onboarding/profile_card_step.dart'`.

- [ ] **Step 3: Write the implementation**

Create `lib/screens/onboarding/profile_card_step.dart`:

```dart
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
    await StorageService().savePrimaryProfile(_profile);
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
                                '${_profile.dayMaster.substring(0, 1)}${_profile.dayMaster.substring(1)}日主',
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
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/screens/onboarding/profile_card_step_test.dart -v`
Expected: PASS (all 3 tests).

- [ ] **Step 5: `flutter analyze` clean**

Run: `flutter analyze`
Expected: `No issues found!`

- [ ] **Step 6: Commit**

```bash
git add lib/screens/onboarding/profile_card_step.dart test/screens/onboarding/profile_card_step_test.dart
git commit -m "feat(onboarding): add Step 3 UI — profile card (builds Profile, shows summary, saves + finishes)"
```

---

### Task 7: `lib/screens/onboarding/onboarding_flow.dart` — ties the 3 steps together

**Files:**
- Create: `lib/screens/onboarding/onboarding_flow.dart`
- Create: `test/screens/onboarding/onboarding_flow_test.dart`

Owns the lifted state across all 3 steps (birth data fields, mbti) and switches between them. On the final step's save, navigates to `TabShell` (see Task 8 for `TabShell`'s new location).

- [ ] **Step 1: Write the failing test**

Create `test/screens/onboarding/onboarding_flow_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:xuanli/screens/onboarding/onboarding_flow.dart';
import 'package:xuanli/screens/tab_shell.dart';
import 'package:xuanli/theme/xuanli_theme.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('行完 3 步（用預設出生資料 + 16 宮格揀 ISFP）會跳去 TabShell', (tester) async {
    // `theme:` required — see birth_data_step_test.dart's wrap() note;
    // every step OnboardingFlow renders needs context.xuanliColors present.
    await tester.pumpWidget(MaterialApp(theme: XuanLiTheme.light(), home: const OnboardingFlow()));

    // Step 1: 出生資料，用晒預設值直接下一步。
    expect(find.text('你嘅出生一刻'), findsOneWidget);
    await tester.tap(find.text('下一步'));
    await tester.pumpAndSettle();

    // Step 2: MBTI，16 宮格揀 ISFP。
    expect(find.text('你嘅性格底色'), findsOneWidget);
    await tester.tap(find.text('ISFP'));
    await tester.pump();
    await tester.tap(find.text('下一步'));
    await tester.pumpAndSettle();

    // Step 3: 檔案卡，撳「開始睇今日」。
    expect(find.text('你嘅命理檔案'), findsOneWidget);
    await tester.tap(find.text('開始睇今日'));
    await tester.pumpAndSettle();

    expect(find.byType(TabShell), findsOneWidget);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/screens/onboarding/onboarding_flow_test.dart`
Expected: FAIL — `Error: Not found: 'package:xuanli/screens/onboarding/onboarding_flow.dart'` (and `tab_shell.dart` doesn't exist yet either — that's created in Task 8; if this test still fails after Task 7 for that reason, that's expected and fine, Task 8 completes the picture. If you want a clean red/green cycle for this specific test, do Task 8's `tab_shell.dart` extraction FIRST as a tiny sub-step, or accept this test only fully passes once Task 8 lands — either is fine, just don't skip writing it now).

- [ ] **Step 3: Write the implementation**

Create `lib/screens/onboarding/onboarding_flow.dart`:

```dart
import 'package:flutter/material.dart';

import '../tab_shell.dart';
import 'birth_data_step.dart';
import 'mbti_step.dart';
import 'profile_card_step.dart';

/// 3 步 onboarding 嘅殼：擁有跨步驟嘅共用 state（出生資料 + MBTI），
/// 逐步遞畀 [BirthDataStep]/[MbtiStep]/[ProfileCardStep]，行完就
/// navigate 去 [TabShell]（`Navigator.pushReplacement`，唔靠
/// `_AppBootstrap` 嘅 FutureBuilder 自動重新路由）。
class OnboardingFlow extends StatefulWidget {
  const OnboardingFlow({super.key});

  @override
  State<OnboardingFlow> createState() => _OnboardingFlowState();
}

class _OnboardingFlowState extends State<OnboardingFlow> {
  int _step = 0;

  BirthDataState _birthData = BirthDataState(
    isLunar: false,
    birthDate: DateTime(2000, 1, 1),
    birthHour: 9,
    birthMinute: 0,
    birthTimeUnknown: false,
    birthPlace: '香港',
  );

  String? _mbti;

  void _finish() {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const TabShell()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: switch (_step) {
          0 => BirthDataStep(
              isLunar: _birthData.isLunar,
              birthDate: _birthData.birthDate,
              birthHour: _birthData.birthHour,
              birthMinute: _birthData.birthMinute,
              birthTimeUnknown: _birthData.birthTimeUnknown,
              birthPlace: _birthData.birthPlace,
              onChanged: (s) => setState(() => _birthData = s),
              onNext: () => setState(() => _step = 1),
            ),
          1 => MbtiStep(
              onDone: (mbti) => setState(() {
                _mbti = mbti;
                _step = 2;
              }),
            ),
          _ => ProfileCardStep(
              name: '我',
              birthDate: _birthData.birthDate,
              birthHour: _birthData.birthHour,
              birthMinute: _birthData.birthMinute,
              birthPlace: _birthData.birthPlace,
              mbti: _mbti!,
              onSaved: _finish,
            ),
        },
      ),
    );
  }
}
```

(`_birthData.isLunar` — the农曆-vs-新曆 toggle is captured in state for Step 1's UI, but per spec §5 `Profile.birthDate` is always stored as a **公曆** value; converting a lunar-mode pick to solar via the existing `lunarToSolarDate()` happens inside `BirthDataStep`'s date-picker flow in a real lunar-input UI. This plan's Task 4 scope only wires the *solar* date picker end-to-end and carries the `isLunar` flag through state — hooking up an actual lunar y/m/d/leap-month picker UI is a reasonable follow-up, not blocking for this plan; note it in your Task 4 self-review as a known simplification if the lunar toggle doesn't yet drive a different picker, and flag it to Stephanie rather than silently shipping a toggle that looks functional but isn't.)

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/screens/onboarding/onboarding_flow_test.dart -v`
Expected: PASS (requires Task 8's `lib/screens/tab_shell.dart` to exist — if doing tasks strictly in order, do Task 8 before considering Task 7 fully green; it's fine for this specific test to stay red until Task 8 lands, per Step 2's note above).

- [ ] **Step 5: Commit**

```bash
git add lib/screens/onboarding/onboarding_flow.dart test/screens/onboarding/onboarding_flow_test.dart
git commit -m "feat(onboarding): add OnboardingFlow — ties 3 steps together, navigates to TabShell on finish"
```

---

### Task 8: Wire `main.dart` — extract `TabShell`, route to `OnboardingFlow`

**Files:**
- Create: `lib/screens/tab_shell.dart`
- Modify: `lib/main.dart`
- Modify: `test/widget_test.dart`

Extracts `TabShell` (currently living inside `main.dart`) into its own file — needed so `onboarding_flow.dart` (Task 7) can import it without importing the app's entry-point file, and resolves a Minor note from Phase 2a's code review ("`TabShell` is public but nothing outside `main.dart` uses it yet — reconsider when 2c starts"; onboarding now needs it, so this is that moment). Then replaces `_OnboardingPlaceholder` with the real `OnboardingFlow`.

- [ ] **Step 1: Create `lib/screens/tab_shell.dart`**

Move `TabShell`, `_TabShellState`, and `_TabInfo` out of `main.dart` verbatim into this new file:

```dart
import 'package:flutter/material.dart';

/// 主畫面：底部三個 tab（今日／我想做／月曆），2c/2d/2e 逐個補真內容。
/// Tabbar 視覺（跟 design html 精確配色/字體）留返 2c 開始起真 Tab A 嗰陣
/// 一併做——依家用 Material NavigationBar 佔位，證明路由/切換行得通。
class TabShell extends StatefulWidget {
  const TabShell({super.key});

  @override
  State<TabShell> createState() => _TabShellState();
}

class _TabShellState extends State<TabShell> {
  int _index = 0;

  static const _tabs = [
    _TabInfo(icon: '☀', label: '今日', placeholder: 'Tab A — 2c 起'),
    _TabInfo(icon: '✦', label: '我想做', placeholder: 'Tab B — 2d 起'),
    _TabInfo(icon: '▦', label: '月曆', placeholder: 'Tab C — 2e 起'),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _index,
        children: [
          for (final tab in _tabs) Center(child: Text(tab.placeholder)),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: [
          for (final tab in _tabs)
            NavigationDestination(icon: Text(tab.icon), label: tab.label),
        ],
      ),
    );
  }
}

class _TabInfo {
  final String icon;
  final String label;
  final String placeholder;
  const _TabInfo({
    required this.icon,
    required this.label,
    required this.placeholder,
  });
}
```

- [ ] **Step 2: Update `lib/main.dart`**

Remove the `TabShell`/`_TabShellState`/`_TabInfo` classes (now living in `lib/screens/tab_shell.dart`) and the `_OnboardingPlaceholder` class. Add an import for both new files, and change the routing branch to use `OnboardingFlow` instead of `_OnboardingPlaceholder`. The full new file:

```dart
import 'package:flutter/material.dart';

import 'models/profile.dart';
import 'screens/onboarding/onboarding_flow.dart';
import 'screens/tab_shell.dart';
import 'services/data_loader.dart';
import 'services/storage_service.dart';
import 'theme/xuanli_theme.dart';

void main() {
  runApp(const XuanLiApp());
}

class XuanLiApp extends StatelessWidget {
  const XuanLiApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '玄曆',
      debugShowCheckedModeBanner: false,
      theme: XuanLiTheme.light(),
      darkTheme: XuanLiTheme.dark(),
      home: const _AppBootstrap(),
    );
  }
}

/// 啟動時做兩件事先顯示正式畫面：(1) 由 assets 讀 JSON 落 engine 嘅
/// init*() cache（[loadEngineData]）；(2) 睇下本機有冇已存 profile，
/// 決定跳去 onboarding 定係主 tab shell。
class _AppBootstrap extends StatefulWidget {
  const _AppBootstrap();

  @override
  State<_AppBootstrap> createState() => _AppBootstrapState();
}

class _AppBootstrapState extends State<_AppBootstrap> {
  late final Future<Profile?> _bootstrap = _run();

  Future<Profile?> _run() async {
    await loadEngineData();
    return StorageService().loadPrimaryProfile();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Profile?>(
      future: _bootstrap,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        if (snapshot.hasError) {
          return Scaffold(
            body: Center(child: Text('載入失敗：${snapshot.error}')),
          );
        }
        final profile = snapshot.data;
        if (profile == null) {
          return const OnboardingFlow();
        }
        return const TabShell();
      },
    );
  }
}
```

- [ ] **Step 3: Update `test/widget_test.dart`**

The existing composition-root test asserts `find.text('Onboarding — 2b 起')` — that placeholder text is gone now. Update the assertion to match `OnboardingFlow`'s actual first-step title instead. Read the current `test/widget_test.dart` first (it uses `tester.runAsync(...)` to escape the fake-async zone for real asset I/O — keep that mechanism, only change the final assertion). Change:

```dart
expect(find.text('Onboarding — 2b 起'), findsOneWidget);
```

to:

```dart
expect(find.text('你嘅出生一刻'), findsOneWidget);
```

(and correspondingly update any `find.byType(TabShell)`-negation check if present to still make sense — read the file to confirm exact current structure before editing).

- [ ] **Step 4: Run the full test suite**

Run: `dart test test/engine/ test/models/`
Expected: PASS (should now include `annual_outlook_test.dart` and `mbti_quiz_test.dart`).

Run: `flutter test`
Expected: PASS — every test from Phase 2a plus this plan's new tests (Tasks 1, 2, 4, 5, 6, 7, plus the updated `widget_test.dart`).

Run: `flutter analyze`
Expected: `No issues found!`

- [ ] **Step 5: Attempt a live run (best-effort — see Phase 2a's known limitation)**

Run: `flutter devices`. If a real device or working simulator/emulator is available, run the app and manually step through all 3 onboarding screens, confirming visually against `design/design-preview.html`'s OB-1/OB-2/OB-3 mockups (colors, spacing, field values). If Phase 2a's environment limitation still holds (no Xcode Simulator, no Android emulator, no macOS/web platform folders), report that clearly rather than skipping this step silently — same as Phase 2a's Task 8 handled it.

- [ ] **Step 6: Commit**

```bash
git add lib/screens/tab_shell.dart lib/main.dart test/widget_test.dart
git commit -m "feat(app): wire real OnboardingFlow into main.dart, extract TabShell to its own file

TabShell moves out of main.dart so onboarding_flow.dart can import it
without importing the app entry point. main.dart now routes to the
real 3-step onboarding instead of the Phase 2a placeholder."
```

---

## Self-Review Notes

**Spec coverage:** Every element of spec §9.1 has a task: 新曆/農曆 toggle + date/time pickers + unknown-time toggle + place (Task 4), MBTI 16-grid or 8-question quiz (Task 5), profile card with all listed fields including the newly-added 流年/沖太歲 line (Task 6, using Task 1's engine function), disclaimer text (Task 6), navigation to the tab shell on finish (Task 7/8).

**Known, flagged simplification:** the 農曆 (lunar) input mode's toggle exists in state (Task 4/7) but this plan does not build a full lunar y/m/d/leap-month picker UI — only the solar `showDatePicker` path is fully wired end-to-end. This should be called out explicitly when Task 4 is reviewed, not silently shipped as if lunar input fully works. If Stephanie wants lunar input working before this plan is considered done, that's a real scope addition to raise, not something to guess into the implementation unprompted.

**Placeholder scan:** every step has literal, complete widget code — no "add the rest of the UI here" gaps. The one deliberately-incomplete piece (lunar picker) is explicitly flagged above, not hidden.

**Type consistency:** `BirthDataState` (Task 4) is the type threaded through `OnboardingFlow` (Task 7); `MbtiStep.onDone` returns a `String` (4-letter MBTI code) matching `ProfileCardStep.mbti`'s type; `ProfileCardStep` calls `buildProfile()` (Phase 2a) and `computeAnnualOutlook()` (Task 1) with the exact parameter names those functions already expose — no drift.
