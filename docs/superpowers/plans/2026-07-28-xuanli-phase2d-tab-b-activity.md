# XuanLi Phase 2d — Tab B 我想做… (反向擇日) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build spec §9.3's "我想做…" reverse-date-picker screen — activity chips, a date-range selector, and ranked result cards with a 🔮 personalized reason — replacing `TabShell`'s Tab B placeholder. The scoring engine (`rankActivities()`, `scoreActivityForDay()`, `Activity`) already exists from Phase 1; this plan adds the one missing engine piece (activity-specific reason text) and the UI layer.

**Architecture:** A new `buildActivityReason()` in `copywriter.dart` (pure, template-based, same style as the existing daily-advice builder) produces the 🔮 line. `ActivityScreen` owns two pieces of state — selected activity name (default: first activity) and selected range (default: 未來一個月) — and on every rebuild calls `rankActivities()` for the current selection, then composes each `ActivityDayResult` into display strings via `AlmanacDay.forDate()` + `buildActivityReason()`. Presentational pieces (`ActivityChip`, `ResultCard`) live in their own widgets file, mirroring `today_widgets.dart`'s pattern — dumb widgets, screen does all composition.

## Two scope decisions already confirmed with Stephanie (don't re-litigate)

1. **🔮 原因 (reason) text** — spec says "每個結果經 copywriter 產生🔮原因" but no engine function exists for it (only the unrelated daily-advice builder). Stephanie confirmed: write a simplified, deterministic template (not the elaborate multi-clause prose shown in `design/design-preview.html`'s mockup) — Task 1, below.
2. **"＋加入我嘅日曆" / "當日已有 N 個行程"** — both need real `device_calendar` integration (spec §9.9), which can't be tested in this environment (no simulator/device) and is spec'd as its own cross-cutting integration point covering both Tab B write and Tab C read. Stephanie confirmed: ship these as visible-but-stubbed buttons here (matching the `☰` settings-icon stub pattern from Phase 2c) — a real calendar-integration sub-plan comes later, likely alongside Tab C.

---

## File Structure

```
xuanli/
├── lib/
│   ├── engine/
│   │   └── copywriter.dart            # MODIFY — add buildActivityReason()
│   └── screens/
│       ├── tab_shell.dart             # MODIFY — Tab B placeholder → real ActivityScreen
│       └── activity/
│           ├── activity_widgets.dart  # NEW — ActivityChip, ResultCard
│           └── activity_screen.dart   # NEW — Tab B composition
├── test/
│   ├── engine/
│   │   └── copywriter_test.dart       # MODIFY — add buildActivityReason() tests
│   └── screens/
│       ├── tab_shell_test.dart        # MODIFY — Tab B assertion updates
│       └── activity/
│           ├── activity_widgets_test.dart  # NEW
│           └── activity_screen_test.dart   # NEW
```

---

### Task 1: `buildActivityReason()` — 🔮 reason text for activity results

**Files:**
- Modify: `lib/engine/copywriter.dart`
- Modify: `test/engine/copywriter_test.dart`

Simplified deterministic template combining whichever of the 3 scoring signals `scoreActivityForDay()` already checks (keyword hit in 宜, favorable 建除, favorable 五行) into one sentence — no LLM, no `Random`, matching `buildAdvice()`'s existing style.

- [ ] **Step 1: Write the failing test**

Add to `test/engine/copywriter_test.dart` (append a new `group`, keep the existing tests and `setUpAll` unchanged — read the current file first to integrate cleanly):

```dart
  group('buildActivityReason', () {
    test('三個信號全中：2026-07-13（戊子執日）剪髮 + 喜木', () {
      final day = AlmanacDay.forDate(DateTime(2026, 7, 13));
      final activity = loadActivities().firstWhere((a) => a.name == '剪髮');

      final reason = buildActivityReason(
        activity: activity,
        day: day,
        favorable: const ['木'],
      );

      expect(reason, startsWith('🔮'));
      expect(reason, contains('理髮'));
      expect(reason, contains('執'));
      expect(reason, contains('木'));
    });

    test('全部唔中：2026-07-11（丙戌平日）剪髮 + 喜金 -> 用返 fallback 句', () {
      final day = AlmanacDay.forDate(DateTime(2026, 7, 11));
      final activity = loadActivities().firstWhere((a) => a.name == '剪髮');

      final reason = buildActivityReason(
        activity: activity,
        day: day,
        favorable: const ['金'],
      );

      expect(reason, startsWith('🔮'));
      expect(reason, contains('剪髮'));
    });
  });
```

(this test needs `loadActivities()` to be initialized — confirm the file's existing `setUpAll` already calls `initActivities(...)`; if it currently only calls `initMbtiTones`, add `initActivities(File('lib/data/activities.json').readAsStringSync());` to the same `setUpAll` block, and add the `import 'package:xuanli/engine/activity.dart';` + any missing `dart:io`/`almanac.dart` imports the file doesn't already have — read the current file first, don't guess)

- [ ] **Step 2: Run test to verify it fails**

Run: `dart test test/engine/copywriter_test.dart`
Expected: FAIL — `Error: The method 'buildActivityReason' isn't defined`.

- [ ] **Step 3: Write the implementation**

Add to `lib/engine/copywriter.dart` (append; needs a new import for `Activity` — add `import 'activity.dart';` at the top alongside the existing `almanac.dart` import):

```dart
/// 反向擇日「🔮 原因」文案（spec §7：「每個結果經 copywriter 產生🔮原因」）。
/// MVP 簡化版：檢查 [scoreActivityForDay] 已經計緊嘅 3 個信號
/// （宜項關鍵字命中／建除相合／五行親和），有邊個中就講邊個，
/// 全部唔中就用返一句保底文案——deterministic，唔用 LLM。
String buildActivityReason({
  required Activity activity,
  required AlmanacDay day,
  required List<String> favorable,
}) {
  final keywordHit = activity.hitKeywords.any((k) => day.yi.contains(k));
  final zhiXingHit = activity.goodZhiXing.contains(day.zhiXing);
  final elementMatch = favorable.contains(activity.element);

  final clauses = <String>[];
  if (keywordHit) {
    clauses.add('通勝明載「宜${activity.hitKeywords.first}」');
  }
  if (zhiXingHit) {
    clauses.add('${day.zhiXing}日利成事');
  }
  if (elementMatch) {
    clauses.add('${activity.element}氣旺，同你相親');
  }

  final body = clauses.isEmpty
      ? '今日整體平順，適合${activity.name}'
      : clauses.join('，');

  return '🔮 $body。';
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `dart test test/engine/copywriter_test.dart -v`
Expected: PASS (all tests, existing + 2 new).

- [ ] **Step 5: Run the full engine suite, `flutter analyze`**

Run: `dart test test/engine/ test/models/` → PASS.
Run: `flutter analyze` → `No issues found!`

- [ ] **Step 6: Commit**

```bash
git add lib/engine/copywriter.dart test/engine/copywriter_test.dart
git commit -m "feat(engine): add buildActivityReason() — 🔮 reason text for Tab B results"
```

---

### Task 2: `lib/screens/activity/activity_widgets.dart` — `ActivityChip`, `ResultCard`

**Files:**
- Create: `lib/screens/activity/activity_widgets.dart`
- Create: `test/screens/activity/activity_widgets_test.dart`

Per spec §9.3: horizontally-scrollable activity chips (selected = dark fill, unselected = outlined), and result cards (date+ganzhi title, star rating, lunar/建除/沖煞 subtitle, 🔮 reason, optional calendar-action row for the top-ranked card only).

**Note on the range selector:** design html's segmented toggle (未來一週/未來一個月/三個月) is functionally identical to `OnboardingSegmentedToggle` (`lib/screens/onboarding/onboarding_widgets.dart`) — same shape (`options`, `selectedIndex`, `onChanged`), same visual style. Reuse it directly via import rather than duplicating a third copy of the same ~30 lines — despite the "Onboarding" prefix in its name, it's a generic 2/3-option segmented control with no onboarding-specific logic. If a 4th distinct use ever comes up, that's the trigger to rename/promote it to a shared location — not before.

- [ ] **Step 1: Write the failing test**

Create `test/screens/activity/activity_widgets_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xuanli/screens/activity/activity_widgets.dart';
import 'package:xuanli/theme/xuanli_theme.dart';

void main() {
  Widget wrap(Widget child) =>
      MaterialApp(theme: XuanLiTheme.light(), home: Scaffold(body: child));

  group('ActivityChip', () {
    testWidgets('顯示標籤，撳落會 call onTap', (tester) async {
      var tapped = false;
      await tester.pumpWidget(wrap(ActivityChip(
        label: '剪髮',
        selected: false,
        onTap: () => tapped = true,
      )));

      expect(find.text('剪髮'), findsOneWidget);
      await tester.tap(find.text('剪髮'));
      expect(tapped, isTrue);
    });
  });

  group('ResultCard', () {
    testWidgets('顯示日期/星級/副標題/原因，冇 showCalendarActions 就唔顯示日曆按鈕', (tester) async {
      await tester.pumpWidget(wrap(const ResultCard(
        dateLabel: '7月16日（四）辛卯日',
        stars: 4,
        subtitleLine: '農曆六月初三・成日・沖雞煞西',
        reason: '🔮 成日利成事。',
        showCalendarActions: false,
      )));

      expect(find.text('7月16日（四）辛卯日'), findsOneWidget);
      expect(find.text('農曆六月初三・成日・沖雞煞西'), findsOneWidget);
      expect(find.textContaining('成日利成事'), findsOneWidget);
      expect(find.text('＋ 加入我嘅日曆'), findsNothing);
    });

    testWidgets('showCalendarActions=true 就顯示日曆按鈕，撳落有 stub 提示', (tester) async {
      await tester.pumpWidget(wrap(const ResultCard(
        dateLabel: '7月16日（四）辛卯日',
        stars: 5,
        subtitleLine: '農曆六月初三・成日・沖雞煞西',
        reason: '🔮 成日利成事。',
        showCalendarActions: true,
      )));

      expect(find.text('＋ 加入我嘅日曆'), findsOneWidget);

      await tester.tap(find.text('＋ 加入我嘅日曆'));
      await tester.pump();

      expect(find.textContaining('日曆整合'), findsOneWidget);
    });
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/screens/activity/activity_widgets_test.dart`
Expected: FAIL — `Error: Not found: 'package:xuanli/screens/activity/activity_widgets.dart'`.

- [ ] **Step 3: Write the implementation**

Create `lib/screens/activity/activity_widgets.dart`:

```dart
import 'package:flutter/material.dart';

import '../../theme/xuanli_theme.dart';

/// 活動 chip（design html `.chipTag`，選中實心藏藍底，未選中outline）。
class ActivityChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const ActivityChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.xuanliColors;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 7),
        decoration: BoxDecoration(
          color: selected ? colors.ink : colors.cardSurface,
          border: selected ? null : Border.all(color: colors.ink12),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12.5,
            color: selected ? colors.paper : colors.ink,
          ),
        ),
      ),
    );
  }
}

/// 反向擇日結果卡（design html 結果卡區塊）。[showCalendarActions] 淨係
/// 畀排名最高嗰張卡用（design html 淨係第一張示範咗日曆按鈕列）；
/// 日曆整合本身係 stub（spec §9.9 真整合留返之後 sub-plan）。
class ResultCard extends StatelessWidget {
  final String dateLabel;
  final int stars; // 1-5
  final String subtitleLine;
  final String reason;
  final bool showCalendarActions;

  const ResultCard({
    super.key,
    required this.dateLabel,
    required this.stars,
    required this.subtitleLine,
    required this.reason,
    required this.showCalendarActions,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.xuanliColors;
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colors.cardSurface,
        border: Border(left: BorderSide(color: colors.jade, width: 4)),
        borderRadius: BorderRadius.circular(XuanLiRadii.card),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                dateLabel,
                style: TextStyle(
                  fontFamily: XuanLiFonts.serif,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: colors.ink,
                ),
              ),
              Text(
                '★' * stars + '☆' * (5 - stars),
                style: TextStyle(color: colors.gold, fontSize: 13, letterSpacing: 1),
              ),
            ],
          ),
          const SizedBox(height: 3),
          Text(
            subtitleLine,
            style: TextStyle(fontSize: 11, color: colors.ink60),
          ),
          const SizedBox(height: 7),
          Text(
            reason,
            style: TextStyle(fontSize: 12.5, color: colors.ink, height: 1.75),
          ),
          if (showCalendarActions) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () => ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('日曆整合 — 之後 sub-plan 起')),
                    ),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: colors.ink,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '＋ 加入我嘅日曆',
                        style: TextStyle(fontSize: 11.5, color: colors.paper, letterSpacing: 1),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: GestureDetector(
                    onTap: () => ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('日曆整合 — 之後 sub-plan 起')),
                    ),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        border: Border.all(color: colors.ink12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '當日行程 ›',
                        style: TextStyle(fontSize: 11.5, color: colors.ink60),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/screens/activity/activity_widgets_test.dart -v`
Expected: PASS (both tests).

- [ ] **Step 5: `flutter analyze` clean**

Run: `flutter analyze` → `No issues found!`

- [ ] **Step 6: Commit**

```bash
git add lib/screens/activity/activity_widgets.dart test/screens/activity/activity_widgets_test.dart
git commit -m "feat(activity): add ActivityChip, ResultCard widgets"
```

---

### Task 3: `lib/screens/activity/activity_screen.dart` — Tab B composition

**Files:**
- Create: `lib/screens/activity/activity_screen.dart`
- Create: `test/screens/activity/activity_screen_test.dart`

Per spec §9.3: chips row → range segmented (1週/1月/3月) → ranked result cards → "已為你避開 XX" trust-building footer note.

- [ ] **Step 1: Write the failing test**

Create `test/screens/activity/activity_screen_test.dart`:

```dart
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xuanli/engine/activity.dart';
import 'package:xuanli/engine/almanac.dart';
import 'package:xuanli/engine/copywriter.dart';
import 'package:xuanli/engine/profile_builder.dart';
import 'package:xuanli/screens/activity/activity_screen.dart';
import 'package:xuanli/theme/xuanli_theme.dart';

void main() {
  setUpAll(() {
    initActivities(File('lib/data/activities.json').readAsStringSync());
    initActivityCategories(
      File('lib/data/activity_categories.json').readAsStringSync(),
    );
    initMbtiTones(File('lib/data/mbti_tones.json').readAsStringSync());
  });

  Widget wrap(Widget child) =>
      MaterialApp(theme: XuanLiTheme.light(), home: child);

  final profile = buildProfile(
    id: 'p1',
    name: '阿玄',
    birthDate: DateTime(1999, 9, 20),
    birthHour: 9,
    birthMinute: 30,
    birthPlace: '香港',
    mbti: 'ISFP',
  );

  testWidgets('預設揀第一個活動＋未來一個月，顯示結果卡（有頭卡先有日曆按鈕）', (tester) async {
    await tester.pumpWidget(wrap(ActivityScreen(
      profile: profile,
      today: DateTime(2026, 7, 11),
    )));

    expect(find.text('我想做⋯'), findsOneWidget);
    expect(find.textContaining('★'), findsWidgets);
    expect(find.text('＋ 加入我嘅日曆'), findsOneWidget);
  });

  testWidgets('撳第二個活動 chip，結果卡會跟住轉', (tester) async {
    await tester.pumpWidget(wrap(ActivityScreen(
      profile: profile,
      today: DateTime(2026, 7, 11),
    )));

    final activities = loadActivities();
    await tester.tap(find.text(activities[1].name));
    await tester.pumpAndSettle();

    // 轉咗活動之後，個殼（標題/日曆按鈕）仲要喺度，唔會爆嘢。
    expect(find.text('我想做⋯'), findsOneWidget);
  });

  testWidgets('揀「睇醫生」呢個冧安全線嘅活動，唔會冧到冇結果', (tester) async {
    await tester.pumpWidget(wrap(ActivityScreen(
      profile: profile,
      today: DateTime(2026, 7, 11),
    )));

    // 「睇醫生」排喺 activities.json 第 7 個，喺橫向 scroll 嘅 chip
    // 列表入面可能唔喺預設 800px test viewport 嘅可見範圍——同 Phase 2c
    // MBTI 16 宮格個 test 一樣嘅風險，用 ensureVisible 先撳，唔好假設
    // 一定喺可見範圍。
    await tester.ensureVisible(find.text('睇醫生'));
    await tester.tap(find.text('睇醫生'));
    await tester.pumpAndSettle();

    expect(find.textContaining('★'), findsWidgets);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/screens/activity/activity_screen_test.dart`
Expected: FAIL — `Error: Not found: 'package:xuanli/screens/activity/activity_screen.dart'`.

- [ ] **Step 3: Write the implementation**

Create `lib/screens/activity/activity_screen.dart`:

```dart
import 'package:flutter/material.dart';

import '../../engine/activity.dart';
import '../../engine/almanac.dart';
import '../../engine/copywriter.dart';
import '../../engine/scoring.dart';
import '../../models/profile.dart';
import '../../theme/xuanli_theme.dart';
import '../onboarding/onboarding_widgets.dart' show OnboardingSegmentedToggle;
import 'activity_widgets.dart';

/// Tab B・我想做…（反向擇日，spec §9.3）。[today] 冇畀就用今日
/// （同 [TodayScreen] 一樣嘅 UI-only「初始顯示邊日」模式，唔係
/// scoring input 嗰種 `DateTime.now()`）。
class ActivityScreen extends StatefulWidget {
  final Profile profile;
  final DateTime? today;

  const ActivityScreen({super.key, required this.profile, this.today});

  @override
  State<ActivityScreen> createState() => _ActivityScreenState();
}

class _RangeOption {
  final String label;
  final int days;
  const _RangeOption(this.label, this.days);
}

const _rangeOptions = [
  _RangeOption('未來一週', 7),
  _RangeOption('未來一個月', 30),
  _RangeOption('三個月', 90),
];

class _ActivityScreenState extends State<ActivityScreen> {
  late String _selectedActivity = loadActivities().first.name;
  int _rangeIndex = 1; // 未來一個月

  static const _weekdayChars = ['一', '二', '三', '四', '五', '六', '日'];

  DateTime get _today {
    final t = widget.today;
    if (t != null) return t;
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }

  int _fortuneScoreOf(DateTime date) {
    final userYearZhi = widget.profile.pillars[0].substring(1);
    return computeFortuneScore(
      day: AlmanacDay.forDate(date),
      favorable: widget.profile.favorable,
      unfavorable: widget.profile.unfavorable,
      userYearZhi: userYearZhi,
    ).score;
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.xuanliColors;
    final rangeDays = _rangeOptions[_rangeIndex].days;
    final dates = [
      for (var i = 0; i < rangeDays; i++) _today.add(Duration(days: i)),
    ];
    final activity = loadActivities().firstWhere((a) => a.name == _selectedActivity);
    final results = rankActivities(
      activityName: _selectedActivity,
      dates: dates,
      favorable: widget.profile.favorable,
      fortuneScoreOf: _fortuneScoreOf,
    );
    final avoided = _findFirstAvoidedDay(activity: activity, dates: dates);

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(18, 10, 18, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 34,
                  height: 34,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(color: colors.red, borderRadius: BorderRadius.circular(7)),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text('玄', style: TextStyle(color: colors.paper, fontFamily: XuanLiFonts.serif, fontWeight: FontWeight.w900, fontSize: 11, height: 1.1)),
                      Text('曆', style: TextStyle(color: colors.paper, fontFamily: XuanLiFonts.serif, fontWeight: FontWeight.w900, fontSize: 11, height: 1.1)),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  '我想做⋯',
                  style: TextStyle(
                    fontFamily: XuanLiFonts.serif,
                    fontWeight: FontWeight.w700,
                    fontSize: 17,
                    letterSpacing: 3,
                    color: colors.ink,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 36,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  for (final a in loadActivities())
                    Padding(
                      padding: const EdgeInsets.only(right: 7),
                      child: ActivityChip(
                        label: a.name,
                        selected: a.name == _selectedActivity,
                        onTap: () => setState(() => _selectedActivity = a.name),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            OnboardingSegmentedToggle(
              options: [for (final r in _rangeOptions) r.label],
              selectedIndex: _rangeIndex,
              onChanged: (i) => setState(() => _rangeIndex = i),
            ),
            const SizedBox(height: 12),
            for (var i = 0; i < results.length; i++)
              _buildResultCard(colors, results[i], showCalendarActions: i == 0),
            if (avoided != null)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  '${avoided.$1.month}月${avoided.$1.day}日（${avoided.$2}）通勝忌${activity.avoidKeywords.first}，已為你避開 ✓',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 11, color: colors.ink30),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildResultCard(
    XuanLiColors colors,
    ActivityDayResult result, {
    required bool showCalendarActions,
  }) {
    final day = AlmanacDay.forDate(result.date);
    final weekdayChar = _weekdayChars[result.date.weekday - 1];
    final dateLabel = '${result.date.month}月${result.date.day}日（$weekdayChar）${day.ganzhiDay}日';
    final subtitleLine = '${day.lunarLabel}・${day.zhiXing}日・${day.chong}';
    final activity = loadActivities().firstWhere((a) => a.name == _selectedActivity);
    final reason = buildActivityReason(
      activity: activity,
      day: day,
      favorable: widget.profile.favorable,
    );

    return ResultCard(
      dateLabel: dateLabel,
      stars: result.stars,
      subtitleLine: subtitleLine,
      reason: reason,
      showCalendarActions: showCalendarActions,
    );
  }

  /// 搵範圍入面第一個因為忌關鍵字命中而俾淘汰嘅日子（spec §7 安全線：
  /// 淘汰邏輯本身已經喺 [scoreActivityForDay] 度，呢度淨係用返公開
  /// 嘅 engine function 掃一次搵嚟做「已為你避開」信任文案，冇重複
  /// 邏輯）。搵唔到就 null（例如「睇醫生」冇 avoidKeywords，永遠搵唔到）。
  (DateTime, String)? _findFirstAvoidedDay({
    required Activity activity,
    required List<DateTime> dates,
  }) {
    if (activity.avoidKeywords.isEmpty) return null;
    for (final date in dates) {
      final day = AlmanacDay.forDate(date);
      final score = scoreActivityForDay(
        activity: activity,
        day: day,
        favorable: widget.profile.favorable,
        fortuneScore: _fortuneScoreOf(date),
      );
      if (score == null) return (date, day.ganzhiDay);
    }
    return null;
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/screens/activity/activity_screen_test.dart -v`
Expected: PASS (all 3 tests).

- [ ] **Step 5: `flutter analyze` clean, full suite check**

Run: `flutter analyze` → `No issues found!`
Run: `flutter test` → PASS (run it first to find your real current baseline — prior tasks on other branches have shown the plan's own predicted counts go stale after review cycles; report the real number you observe, baseline + however many tests this task actually adds).

- [ ] **Step 6: Commit**

```bash
git add lib/screens/activity/activity_screen.dart test/screens/activity/activity_screen_test.dart
git commit -m "feat(activity): add ActivityScreen (Tab B 我想做…) composition"
```

---

### Task 4: Wire `ActivityScreen` into `TabShell`

**Files:**
- Modify: `lib/screens/tab_shell.dart`
- Modify: `test/screens/tab_shell_test.dart`

- [ ] **Step 1: Update `lib/screens/tab_shell.dart`**

Read the current file first (it now has `TodayScreen` wired into index 0 from Phase 2c). Change the `IndexedStack` children so index 1 also gets real content:

```dart
      body: IndexedStack(
        index: _index,
        children: [
          TodayScreen(profile: widget.profile),
          ActivityScreen(profile: widget.profile),
          for (final tab in _tabs.skip(2)) Center(child: Text(tab.placeholder)),
        ],
      ),
```

Add the import: `import 'activity/activity_screen.dart';`. Tab C (index 2) stays the Phase 2a placeholder.

- [ ] **Step 2: Update `test/screens/tab_shell_test.dart`**

Read the current file first — it likely has a test asserting `find.text('Tab B — 2d 起')` after tapping the "我想做" tab (from Phase 2c, when Tab B was still a placeholder). That text is gone now. Update the assertion to check for something `ActivityScreen` actually renders instead (e.g. `find.text('我想做⋯')`, the screen's own header title). This file will also need the same engine `setUpAll` init pattern it already has (from Phase 2c's fix) extended to cover `initActivities` too, since Tab B's real content now needs it — check whether the existing `setUpAll` already covers this or needs one more `init*()` call.

- [ ] **Step 3: Run the full test suite**

Run: `flutter analyze` → `No issues found!`
Run: `flutter test` → PASS. Also check `test/screens/onboarding/onboarding_flow_test.dart` and any other test that renders `TabShell` end-to-end still passes — wiring in real Tab B content is exactly the kind of change that broke other tests in Phase 2c Task 5 (any test that renders a full `TabShell` now needs every `init*()` Tab A AND Tab B depend on). Grep for `TabShell(` across `test/` to find every affected file rather than assuming only the two files already known to render it.

- [ ] **Step 4: Attempt a live run (best-effort — same known environment limitation as prior phases)**

Run: `flutter devices`. If unavailable (expected, per every prior phase's finding), report clearly rather than skipping silently.

- [ ] **Step 5: Commit**

```bash
git add lib/screens/tab_shell.dart test/screens/tab_shell_test.dart
git commit -m "feat(app): wire ActivityScreen into TabShell's Tab B slot

Tab C remains the Phase 2a placeholder. Wiring in real Tab B content
means every test that renders a full TabShell now needs activity
engine data initialized too — same class of fix Phase 2c Task 5
needed when Tab A went live."
```

---

## Self-Review Notes

**Spec coverage:** Chips (`ActivityChip`, horizontally scrollable), range segmented (`OnboardingSegmentedToggle` reused), ranked result cards with star rating + 🔮 reason (`ResultCard` + `buildActivityReason()`), "已為你避開" trust footer (`_findFirstAvoidedDay`). The two calendar buttons are visible per spec but intentionally stubbed per the confirmed scope decision above — not silently omitted, not silently faked as working.

**Known regression-fix pattern to watch for:** exactly like Phase 2c Task 5, wiring a second real tab into `TabShell` will likely break any existing test that renders a full `TabShell` without the newly-required `init*()` calls. Task 4 explicitly calls this out rather than letting it surprise the implementer.

**Placeholder scan:** every step has literal, complete code. The "stub" calendar buttons are a deliberate, spec-confirmed simplification with a visible in-app label saying so (`日曆整合 — 之後 sub-plan 起`), not a silently-incomplete feature.

**Type consistency:** `ActivityScreen` calls `rankActivities()`/`scoreActivityForDay()`/`AlmanacDay.forDate()`/`computeFortuneScore()`/`buildActivityReason()` with the exact parameter names those Phase 1/Task 1 functions already expose — no drift. `ResultCard`'s fields (`dateLabel`, `stars`, `subtitleLine`, `reason`, `showCalendarActions`) are all primitives composed by the screen, matching the established `YjColumn`/`AdviceCard` "dumb widget" pattern from Phase 2c.
