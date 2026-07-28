# XuanLi Phase 2c — Tab A 今日宜忌 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build the first real tab content — spec §9.2's "今日宜忌" screen (date header, dual命理分/契合度 rings, personalized 宜/忌 columns, 🔮 advice card, 未來七日 strip) — replacing `TabShell`'s Tab A placeholder, and give `TabShell` its final design-accurate tabbar (deferred from Phase 2a/2b's placeholder `NavigationBar`). All the underlying computation already exists from Phase 1 (`buildDayReading()`) — this plan is purely the UI layer.

**Architecture:** `_AppBootstrap` (main.dart) already loads the user's `Profile` before deciding to route to `TabShell` — thread that same `Profile` object into `TabShell` instead of discarding it, so `TabShell` (and eventually every tab) has it without a second async fetch. `TabShell` gets a custom-styled bottom tabbar matching `design/design-preview.html`'s `.tabbar` exactly (this was explicitly deferred here in Phase 2a's plan). A new `TodayScreen` (Tab A's real body) is a `StatefulWidget` holding only `_selectedDate` (defaults to today, changeable via the week-strip), calling `buildDayReading(profile, date)` synchronously in `build()` — no async/FutureBuilder needed, since the engine call is pure and fast. Shared presentational pieces (`ScoreRing`, `YjColumn`, `AdviceCard`, `Week7Strip`) live in their own widgets file, mirroring the `onboarding_widgets.dart` pattern from Phase 2b.

**Tech Stack:** Flutter (`CircularProgressIndicator` with `strokeCap: StrokeCap.round` for the design's rounded-cap rings — verified present on this project's installed Flutter 3.44.7), existing Phase 1 engine (`buildDayReading()`, `DayReading`, `YjItem`), existing Phase 2a/2b infrastructure (`XuanLiTheme`/`XuanLiColors`/`context.xuanliColors`, `Profile`).

---

## File Structure

```
xuanli/
├── lib/
│   ├── main.dart                          # MODIFY — pass loaded Profile into TabShell
│   └── screens/
│       ├── tab_shell.dart                 # MODIFY — accept Profile, custom design-accurate tabbar
│       └── today/
│           ├── today_widgets.dart         # NEW — ScoreRing, YjColumn, AdviceCard, Week7Strip
│           └── today_screen.dart          # NEW — Tab A composition
├── test/
│   ├── widget_test.dart                   # MODIFY — bootstrap now routes to TabShell with a Profile
│   └── screens/
│       ├── tab_shell_test.dart            # NEW
│       └── today/
│           ├── today_widgets_test.dart    # NEW
│           └── today_screen_test.dart     # NEW
```

---

### Task 1: Thread `Profile` from bootstrap into `TabShell`

**Files:**
- Modify: `lib/main.dart`
- Modify: `lib/screens/tab_shell.dart`
- Modify: `test/widget_test.dart`

`_AppBootstrap` already calls `StorageService().loadPrimaryProfile()` to decide whether to route to onboarding or the tab shell — today it discards the loaded `Profile` once it knows one exists (`return const TabShell();`). Every tab (starting with Tab A here) needs that `Profile`, so thread it through instead of re-fetching.

- [ ] **Step 1: Update `lib/screens/tab_shell.dart` to accept a `Profile`**

Read the current file first. Change the class declaration:

```dart
class TabShell extends StatefulWidget {
  final Profile profile;

  const TabShell({super.key, required this.profile});

  @override
  State<TabShell> createState() => _TabShellState();
}
```

Add the import: `import '../models/profile.dart';` at the top. `_TabShellState` needs access to `widget.profile` — leave the tab bodies as the existing placeholders for now (Task 5 wires in the real `TodayScreen`); this step is purely about the constructor/field, not the tabbar styling (that's Task 2) or tab content (Task 5). Don't combine concerns — just get `Profile` flowing through correctly first.

- [ ] **Step 2: Update `lib/main.dart`**

Change the routing line:

```dart
        final profile = snapshot.data;
        if (profile == null) {
          return const OnboardingFlow();
        }
        return const TabShell();
```

to:

```dart
        final profile = snapshot.data;
        if (profile == null) {
          return const OnboardingFlow();
        }
        return TabShell(profile: profile);
```

- [ ] **Step 3: Update `test/widget_test.dart`**

Read its current content first — it currently only exercises the "no saved profile → onboarding" path (explicitly noted as the only path covered, with a comment explaining the has-profile path needs a fully serialized `Profile` in `SharedPreferences` to test, which was out of scope when written). This task's change doesn't require adding that coverage now — just confirm the existing test still compiles and passes given `TabShell` now requires a `profile` parameter (it does, since the existing test's asserted path never reaches `TabShell` — it stays on the onboarding branch). If `flutter analyze`/`flutter test` reveal the existing test needs no changes, say so in your report rather than making unnecessary edits.

- [ ] **Step 4: Verify**

Run: `flutter analyze`
Expected: `No issues found!`

Run: `flutter test`
Expected: PASS, same count as before this task (114) — no new tests added yet, this is pure plumbing.

- [ ] **Step 5: Commit**

```bash
git add lib/main.dart lib/screens/tab_shell.dart test/widget_test.dart
git commit -m "feat(app): thread Profile from bootstrap into TabShell

_AppBootstrap already loads the user's Profile to decide onboarding
vs. tab-shell routing — pass it through instead of discarding it, so
every tab (starting with Tab A next) has it without a second fetch."
```

---

### Task 2: `TabShell` — design-accurate custom tabbar

**Files:**
- Modify: `lib/screens/tab_shell.dart`
- Create: `test/screens/tab_shell_test.dart`

Replaces the Phase 2a placeholder `NavigationBar` with a tabbar matching `design/design-preview.html`'s `.tabbar` exactly: icon glyph (large) above label (small), selected tab in red/bold, unselected in muted ink, top border, no ripple/Material chrome.

- [ ] **Step 1: Write the failing test**

Create `test/screens/tab_shell_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xuanli/models/profile.dart';
import 'package:xuanli/screens/tab_shell.dart';
import 'package:xuanli/theme/xuanli_theme.dart';

Profile _sampleProfile() => Profile(
      id: 'p1',
      name: '阿玄',
      birthDate: DateTime(1999, 9, 20),
      birthHour: 9,
      birthPlace: '香港',
      mbti: 'ISFP',
      pillars: const ['己卯', '癸酉', '乙亥', '辛巳'],
      wuxing: const {'木': 30, '火': 14, '土': 13, '金': 15, '水': 28},
      favorable: const ['水', '木'],
      unfavorable: const ['金', '土'],
      dayMaster: '乙木',
      ziweiStar: '太陰',
      zodiac: '兔',
    );

void main() {
  Widget wrap(Widget child) =>
      MaterialApp(theme: XuanLiTheme.light(), home: child);

  testWidgets('預設揀第一個 tab（今日），撳第二個 tab 會切換', (tester) async {
    await tester.pumpWidget(wrap(TabShell(profile: _sampleProfile())));

    expect(find.text('今日'), findsOneWidget);
    expect(find.text('我想做'), findsOneWidget);
    expect(find.text('月曆'), findsOneWidget);

    await tester.tap(find.text('我想做'));
    await tester.pump();

    expect(find.text('Tab B — 2d 起'), findsOneWidget);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/screens/tab_shell_test.dart`
Expected: FAIL — `TabShell` constructor doesn't accept `profile` as a positional-only/no test file exists relationship issue, OR passes trivially if Task 1 already landed (Task 1 must be done before this task — if run in order, this test may actually already partially work since `TabShell(profile:)` exists; the NEW thing this test exercises is the custom tabbar rendering `今日`/`我想做`/`月曆` as tappable text, which the current `NavigationBar`-based implementation also technically renders via `NavigationDestination(label: ...)` — so this specific test might not fail cleanly against the "before" state. That's fine: the point of TDD here is confirming behavior, and this task's real change is visual (custom styling) more than structural. If the test passes immediately against the pre-Task-2 `NavigationBar` implementation, note that in your report — it's not a sign something's wrong, just that `NavigationBar` already exposed tappable labelled destinations. Proceed to implement the custom tabbar regardless, since the goal is design-fidelity, not new behavior.)

- [ ] **Step 3: Rewrite `lib/screens/tab_shell.dart`**

```dart
import 'package:flutter/material.dart';

import '../models/profile.dart';
import '../theme/xuanli_theme.dart';

/// 主畫面：底部三個 tab（今日／我想做／月曆）。Tabbar 樣式跟
/// design/design-preview.html 嘅 `.tabbar` 精確配色：選中用朱紅+粗體，
/// 未選中用淡墨，頂部一條幼線分隔，冇 Material ripple/預設高亮。
class TabShell extends StatefulWidget {
  final Profile profile;

  const TabShell({super.key, required this.profile});

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
      bottomNavigationBar: _TabBar(
        selectedIndex: _index,
        tabs: _tabs,
        onSelect: (i) => setState(() => _index = i),
      ),
    );
  }
}

class _TabBar extends StatelessWidget {
  final int selectedIndex;
  final List<_TabInfo> tabs;
  final ValueChanged<int> onSelect;

  const _TabBar({
    required this.selectedIndex,
    required this.tabs,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.xuanliColors;
    return Container(
      decoration: BoxDecoration(
        color: colors.cardSurface.withValues(alpha: 0.85),
        border: Border(top: BorderSide(color: colors.ink12)),
      ),
      padding: const EdgeInsets.fromLTRB(0, 10, 0, 22),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            for (var i = 0; i < tabs.length; i++)
              Expanded(
                child: GestureDetector(
                  onTap: () => onSelect(i),
                  behavior: HitTestBehavior.opaque,
                  child: Semantics(
                    button: true,
                    selected: i == selectedIndex,
                    label: tabs[i].label,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          tabs[i].icon,
                          style: TextStyle(
                            fontSize: 19,
                            color: i == selectedIndex ? colors.red : colors.ink60,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          tabs[i].label,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: i == selectedIndex ? FontWeight.w700 : FontWeight.w400,
                            color: i == selectedIndex ? colors.red : colors.ink60,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
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

Note: `SafeArea(top: false, ...)` wraps the tabbar's own bottom padding so it correctly respects a device's home-indicator inset without double-padding at the top (the `Scaffold`'s body already handles top safe area separately, and `TodayScreen` — Task 5 — wraps itself in its own `SafeArea` for its content).

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/screens/tab_shell_test.dart -v`
Expected: PASS.

- [ ] **Step 5: `flutter analyze` clean, full suite green**

Run: `flutter analyze` → `No issues found!`
Run: `flutter test` → PASS, count should be 114 + 1 = 115.

- [ ] **Step 6: Commit**

```bash
git add lib/screens/tab_shell.dart test/screens/tab_shell_test.dart
git commit -m "feat(app): replace placeholder NavigationBar with design-accurate custom tabbar"
```

---

### Task 3: `lib/screens/today/today_widgets.dart` — `ScoreRing`, `YjColumn`, `AdviceCard`

**Files:**
- Create: `lib/screens/today/today_widgets.dart`
- Create: `test/screens/today/today_widgets_test.dart`

- [ ] **Step 1: Write the failing test**

Create `test/screens/today/today_widgets_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xuanli/models/day_reading.dart';
import 'package:xuanli/screens/today/today_widgets.dart';
import 'package:xuanli/theme/xuanli_theme.dart';

void main() {
  Widget wrap(Widget child) =>
      MaterialApp(theme: XuanLiTheme.light(), home: Scaffold(body: child));

  group('ScoreRing', () {
    testWidgets('顯示分數同 label', (tester) async {
      await tester.pumpWidget(wrap(
        ScoreRing(score: 42, ringColor: Colors.amber, label: '命理分・平'),
      ));
      expect(find.text('42'), findsOneWidget);
      expect(find.text('命理分・平'), findsOneWidget);
    });
  });

  group('YjColumn', () {
    testWidgets('已配對項目顯示「✦ 合你」，未配對嘅唔顯示', (tester) async {
      await tester.pumpWidget(wrap(YjColumn(
        dotLabel: '宜',
        title: '今日宜',
        isYi: true,
        items: const [
          YjItem(label: '祭祀祈福', matchesUser: true),
          YjItem(label: '解除舊約', matchesUser: false),
        ],
      )));

      expect(find.text('祭祀祈福'), findsOneWidget);
      expect(find.text('解除舊約'), findsOneWidget);
      expect(find.text('✦ 合你'), findsOneWidget);
    });

    testWidgets('有 extraNote 就顯示喺列表下面', (tester) async {
      await tester.pumpWidget(wrap(YjColumn(
        dotLabel: '忌',
        title: '今日忌',
        isYi: false,
        items: const [YjItem(label: '簽約大事', matchesUser: false)],
        extraNote: '申時 15–17',
      )));

      expect(find.text('申時 15–17'), findsOneWidget);
    });
  });

  group('AdviceCard', () {
    testWidgets('顯示建議文字', (tester) async {
      await tester.pumpWidget(wrap(
        const AdviceCard(advice: '丙戌平日，宜靜不宜動。'),
      ));
      expect(find.textContaining('丙戌平日'), findsOneWidget);
      expect(find.textContaining('🔮'), findsOneWidget);
    });
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/screens/today/today_widgets_test.dart`
Expected: FAIL — `Error: Not found: 'package:xuanli/screens/today/today_widgets.dart'`.

- [ ] **Step 3: Write the implementation**

Create `lib/screens/today/today_widgets.dart`:

```dart
import 'package:flutter/material.dart';

import '../../models/day_reading.dart';
import '../../theme/xuanli_theme.dart';

/// 雙環卡入面單一個環（design html `.ring` + SVG，用
/// [CircularProgressIndicator] 嘅 `strokeCap: StrokeCap.round` 對應
/// SVG 嘅 `stroke-linecap="round"`）。
class ScoreRing extends StatelessWidget {
  final int score; // 0-100
  final Color ringColor;
  final String label;

  const ScoreRing({
    super.key,
    required this.score,
    required this.ringColor,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.xuanliColors;
    return SizedBox(
      width: 104,
      height: 104,
      child: Stack(
        alignment: Alignment.center,
        children: [
          SizedBox(
            width: 104,
            height: 104,
            child: CircularProgressIndicator(
              value: score / 100,
              strokeWidth: 9,
              strokeCap: StrokeCap.round,
              backgroundColor: colors.paper2,
              valueColor: AlwaysStoppedAnimation(ringColor),
            ),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '$score',
                style: TextStyle(
                  fontFamily: XuanLiFonts.serif,
                  fontSize: 30,
                  fontWeight: FontWeight.w900,
                  color: colors.ink,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                label,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 10, color: colors.ink60, letterSpacing: 1),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// 宜／忌其中一欄（design html `.yjCol`）。[isYi] 揀玉綠（宜）定朱紅
/// （忌）主題色。[extraNote]（例如避開時辰）淡色顯示喺項目列表下面。
class YjColumn extends StatelessWidget {
  final String dotLabel; // '宜' | '忌'
  final String title; // '今日宜' | '今日忌'
  final List<YjItem> items;
  final bool isYi;
  final String? extraNote;

  const YjColumn({
    super.key,
    required this.dotLabel,
    required this.title,
    required this.items,
    required this.isYi,
    this.extraNote,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.xuanliColors;
    final themeColor = isYi ? colors.jade : colors.red;
    final bgColor = isYi ? colors.jade.withValues(alpha: 0.09) : colors.red.withValues(alpha: 0.07);
    final borderColor = isYi ? colors.jade.withValues(alpha: 0.25) : colors.red.withValues(alpha: 0.22);

    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: bgColor,
          border: Border.all(color: borderColor),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 20,
                  height: 20,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(color: themeColor, borderRadius: BorderRadius.circular(5)),
                  child: Text(
                    dotLabel,
                    style: TextStyle(color: colors.paper, fontSize: 11, fontWeight: FontWeight.w700),
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  title,
                  style: TextStyle(
                    fontFamily: XuanLiFonts.serif,
                    fontSize: 15,
                    letterSpacing: 2,
                    color: themeColor,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            for (final item in items)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Flexible(
                      child: Text(
                        item.label,
                        style: TextStyle(fontSize: 12.5, color: colors.ink),
                      ),
                    ),
                    if (item.matchesUser)
                      Text(
                        '✦ 合你',
                        style: TextStyle(fontSize: 9.5, color: colors.gold, letterSpacing: 1),
                      ),
                  ],
                ),
              ),
            if (extraNote != null)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: Text(
                  extraNote!,
                  style: TextStyle(fontSize: 12.5, color: colors.ink30),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// 🔮 今日貼身建議卡（design html `.card` 金色主題變體）。
class AdviceCard extends StatelessWidget {
  final String advice;

  const AdviceCard({super.key, required this.advice});

  @override
  Widget build(BuildContext context) {
    final colors = context.xuanliColors;
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.gold.withValues(alpha: 0.08),
        border: Border.all(color: colors.gold.withValues(alpha: 0.35)),
        borderRadius: BorderRadius.circular(XuanLiRadii.card),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '🔮 今日貼身建議',
            style: TextStyle(
              fontSize: 10.5,
              letterSpacing: 2,
              color: colors.gold,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            advice,
            style: TextStyle(
              fontFamily: XuanLiFonts.serif,
              fontSize: 13.5,
              height: 1.85,
              color: colors.ink,
            ),
          ),
        ],
      ),
    );
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/screens/today/today_widgets_test.dart -v`
Expected: PASS (all 4 tests).

- [ ] **Step 5: `flutter analyze` clean**

Run: `flutter analyze` → `No issues found!`

- [ ] **Step 6: Commit**

```bash
git add lib/screens/today/today_widgets.dart test/screens/today/today_widgets_test.dart
git commit -m "feat(today): add ScoreRing, YjColumn, AdviceCard shared widgets"
```

---

### Task 4: `Week7Strip` widget (added to `today_widgets.dart`)

**Files:**
- Modify: `lib/screens/today/today_widgets.dart`
- Modify: `test/screens/today/today_widgets_test.dart`

- [ ] **Step 1: Write the failing test**

Add to `test/screens/today/today_widgets_test.dart` (append a new `group`, keep everything else in the file unchanged):

```dart
import 'package:xuanli/models/profile.dart';
import 'package:xuanli/engine/profile_builder.dart';
```

(add these two imports to the top of the file, alongside the existing ones — `Week7Strip` takes real `DayReading`s, and this test builds them via `buildProfile()`/`buildDayReading()`, so it needs `initMbtiTones`/`initActivityCategories` set up first; see below)

```dart
import 'dart:io';
import 'package:xuanli/engine/day_reading_engine.dart';
import 'package:xuanli/engine/almanac.dart';
import 'package:xuanli/engine/copywriter.dart';
```

(these three plus `dart:io` are also needed — for `initActivityCategories`/`initMbtiTones` and `buildDayReading`)

```dart
  setUpAll(() {
    initMbtiTones(File('lib/data/mbti_tones.json').readAsStringSync());
    initActivityCategories(
      File('lib/data/activity_categories.json').readAsStringSync(),
    );
  });

  group('Week7Strip', () {
    testWidgets('7 日全部顯示，今日嗰格有金框，撳第二日會 call onSelect', (tester) async {
      final profile = buildProfile(
        id: 'p1',
        name: '阿玄',
        birthDate: DateTime(1999, 9, 20),
        birthHour: 9,
        birthMinute: 30,
        birthPlace: '香港',
        mbti: 'ISFP',
      );
      final start = DateTime(2026, 7, 11);
      final readings = [
        for (var i = 0; i < 7; i++)
          buildDayReading(profile: profile, date: start.add(Duration(days: i))),
      ];
      DateTime? selected;

      await tester.pumpWidget(wrap(Week7Strip(
        readings: readings,
        selectedDate: start,
        onSelect: (d) => selected = d,
      )));

      expect(find.text('11'), findsOneWidget);
      expect(find.text('17'), findsOneWidget);

      await tester.tap(find.text('12'));
      await tester.pump();

      expect(selected, DateTime(2026, 7, 12));
    });
  });
```

(place the `setUpAll` inside `void main() { ... }`, before the existing groups, alongside the `wrap()` helper — read the current file structure first to integrate cleanly rather than guessing exact placement)

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/screens/today/today_widgets_test.dart`
Expected: FAIL — `Error: Not found: 'Week7Strip'` (or similar — the class doesn't exist yet).

- [ ] **Step 3: Add `Week7Strip` to `lib/screens/today/today_widgets.dart`**

Append to the end of the file:

```dart
/// 未來七日條（design html `.week7`）。今日（`selectedDate` 命中嗰格）
/// 有金框；吉／忌／平三種 band 各自有主題色；撳格會 call [onSelect]。
class Week7Strip extends StatelessWidget {
  final List<DayReading> readings;
  final DateTime selectedDate;
  final ValueChanged<DateTime> onSelect;

  const Week7Strip({
    super.key,
    required this.readings,
    required this.selectedDate,
    required this.onSelect,
  });

  static const _weekdayChars = ['一', '二', '三', '四', '五', '六', '日'];

  bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  @override
  Widget build(BuildContext context) {
    final colors = context.xuanliColors;
    return Row(
      children: [
        for (var i = 0; i < readings.length; i++)
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(right: i == readings.length - 1 ? 0 : 6),
              child: _buildDay(context, colors, readings[i]),
            ),
          ),
      ],
    );
  }

  Widget _buildDay(BuildContext context, XuanLiColors colors, DayReading reading) {
    final isToday = _isSameDay(reading.date, selectedDate);
    final bandColor = reading.band == '吉'
        ? colors.jade
        : reading.band == '忌'
            ? colors.red
            : colors.ink;
    final bgColor = reading.band == '吉'
        ? colors.jade.withValues(alpha: 0.12)
        : reading.band == '忌'
            ? colors.red.withValues(alpha: 0.09)
            : colors.cardSurface;
    final borderColor = isToday
        ? colors.gold
        : reading.band == '吉'
            ? colors.jade.withValues(alpha: 0.3)
            : reading.band == '忌'
                ? colors.red.withValues(alpha: 0.28)
                : colors.ink12;

    return GestureDetector(
      onTap: () => onSelect(reading.date),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 7),
        decoration: BoxDecoration(
          color: bgColor,
          border: Border.all(color: borderColor, width: isToday ? 2 : 1),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          children: [
            Text(
              _weekdayChars[reading.date.weekday - 1],
              style: TextStyle(fontSize: 10, color: colors.ink60),
            ),
            Text(
              '${reading.date.day}',
              style: TextStyle(fontFamily: XuanLiFonts.serif, fontSize: 13, color: bandColor),
            ),
            Text(reading.band, style: TextStyle(fontSize: 10, color: colors.ink60)),
          ],
        ),
      ),
    );
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/screens/today/today_widgets_test.dart -v`
Expected: PASS (all 5 tests: 4 from Task 3 + 1 new).

- [ ] **Step 5: `flutter analyze` clean, full suite check**

Run: `flutter analyze` → `No issues found!`
Run: `flutter test` → PASS, count 115 + 5 = 120.

- [ ] **Step 6: Commit**

```bash
git add lib/screens/today/today_widgets.dart test/screens/today/today_widgets_test.dart
git commit -m "feat(today): add Week7Strip widget"
```

---

### Task 5: `lib/screens/today/today_screen.dart` — Tab A composition, wired into `TabShell`

**Files:**
- Create: `lib/screens/today/today_screen.dart`
- Create: `test/screens/today/today_screen_test.dart`
- Modify: `lib/screens/tab_shell.dart`

Per spec §9.2: date header (公曆+農曆+干支+沖煞), dual ring card, 宜/忌 columns, advice card, week-7 strip that changes the displayed day.

- [ ] **Step 1: Write the failing test**

Create `test/screens/today/today_screen_test.dart`:

```dart
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xuanli/engine/almanac.dart';
import 'package:xuanli/engine/copywriter.dart';
import 'package:xuanli/engine/profile_builder.dart';
import 'package:xuanli/screens/today/today_screen.dart';
import 'package:xuanli/theme/xuanli_theme.dart';

void main() {
  setUpAll(() {
    initMbtiTones(File('lib/data/mbti_tones.json').readAsStringSync());
    initActivityCategories(
      File('lib/data/activity_categories.json').readAsStringSync(),
    );
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

  testWidgets('顯示 2026-07-11（丙戌平日）golden fixture 嘅日期/干支/雙環/宜忌', (tester) async {
    await tester.pumpWidget(wrap(TodayScreen(
      profile: profile,
      initialDate: DateTime(2026, 7, 11),
    )));

    expect(find.textContaining('7月11日'), findsOneWidget);
    expect(find.textContaining('五月廿七'), findsOneWidget);
    expect(find.textContaining('丙戌'), findsWidgets);
    expect(find.textContaining('沖龍煞北'), findsOneWidget);
    expect(find.text('祭祀'), findsOneWidget);
  });

  testWidgets('撳未來七日條入面第二日，畫面內容轉去嗰日', (tester) async {
    await tester.pumpWidget(wrap(TodayScreen(
      profile: profile,
      initialDate: DateTime(2026, 7, 11),
    )));

    expect(find.textContaining('7月11日'), findsOneWidget);

    await tester.tap(find.text('12'));
    await tester.pumpAndSettle();

    expect(find.textContaining('7月12日'), findsOneWidget);
    expect(find.textContaining('五月廿八'), findsOneWidget);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/screens/today/today_screen_test.dart`
Expected: FAIL — `Error: Not found: 'package:xuanli/screens/today/today_screen.dart'`.

- [ ] **Step 3: Write the implementation**

Create `lib/screens/today/today_screen.dart`:

```dart
import 'package:flutter/material.dart';

import '../../engine/day_reading_engine.dart';
import '../../models/day_reading.dart';
import '../../models/profile.dart';
import '../../theme/xuanli_theme.dart';
import 'today_widgets.dart';

/// Tab A・今日宜忌（spec §9.2）。[initialDate] 冇畀就用今日
/// （UI-only 決定「一開始顯示邊日」，唔係 scoring input 嗰種
/// `DateTime.now()`——一旦定咗 `_selectedDate`，之後全部計算都純
/// 靠嗰個日期，deterministic）。
class TodayScreen extends StatefulWidget {
  final Profile profile;
  final DateTime? initialDate;

  const TodayScreen({super.key, required this.profile, this.initialDate});

  @override
  State<TodayScreen> createState() => _TodayScreenState();
}

class _TodayScreenState extends State<TodayScreen> {
  late DateTime _selectedDate = widget.initialDate ?? _today();

  static DateTime _today() {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }

  static const _weekdayNames = ['一', '二', '三', '四', '五', '六', '日'];

  @override
  Widget build(BuildContext context) {
    final colors = context.xuanliColors;
    final reading = buildDayReading(profile: widget.profile, date: _selectedDate);
    final weekStart = widget.initialDate == null ? _today() : _weekAnchor();
    final week = [
      for (var i = 0; i < 7; i++)
        buildDayReading(profile: widget.profile, date: weekStart.add(Duration(days: i))),
    ];

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(18, 10, 18, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(colors, reading),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
              decoration: BoxDecoration(
                color: colors.cardSurface,
                border: Border.all(color: colors.ink12),
                borderRadius: BorderRadius.circular(XuanLiRadii.card),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  ScoreRing(
                    score: reading.fortuneScore,
                    ringColor: colors.gold,
                    label: '命理分・${reading.band}',
                  ),
                  Container(width: 1, height: 76, color: colors.ink12),
                  ScoreRing(
                    score: reading.mbtiScore,
                    ringColor: colors.jade,
                    label: '狀態契合・${widget.profile.mbti}',
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                YjColumn(dotLabel: '宜', title: '今日宜', items: reading.yi, isYi: true),
                const SizedBox(width: 12),
                YjColumn(
                  dotLabel: '忌',
                  title: '今日忌',
                  items: reading.ji,
                  isYi: false,
                  extraNote: reading.avoidHour,
                ),
              ],
            ),
            AdviceCard(advice: reading.advice),
            const SizedBox(height: 14),
            Text(
              '未來七日',
              style: TextStyle(fontSize: 11, letterSpacing: 2, color: colors.ink60),
            ),
            const SizedBox(height: 8),
            Week7Strip(
              readings: week,
              selectedDate: _selectedDate,
              onSelect: (d) => setState(() => _selectedDate = d),
            ),
          ],
        ),
      ),
    );
  }

  /// 未來七日條要維持喺 [widget.initialDate]（或今日）開始嘅固定七日
  /// 範圍，唔會因為用戶撳咗第二日就成條 strip 一齊郁——只有
  /// `_selectedDate`（畫面主體顯示緊邊日）先會變。
  DateTime _weekAnchor() => widget.initialDate!;

  Widget _buildHeader(XuanLiColors colors, DayReading reading) {
    final weekdayChar = _weekdayNames[_selectedDate.weekday - 1];
    return Row(
      children: [
        Container(
          width: 34,
          height: 34,
          alignment: Alignment.center,
          decoration: BoxDecoration(color: colors.red, borderRadius: BorderRadius.circular(7)),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                '玄',
                style: TextStyle(
                  color: colors.paper,
                  fontFamily: XuanLiFonts.serif,
                  fontWeight: FontWeight.w900,
                  fontSize: 11,
                  height: 1.1,
                ),
              ),
              Text(
                '曆',
                style: TextStyle(
                  color: colors.paper,
                  fontFamily: XuanLiFonts.serif,
                  fontWeight: FontWeight.w900,
                  fontSize: 11,
                  height: 1.1,
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: Column(
            children: [
              Text(
                '${_selectedDate.month}月${_selectedDate.day}日 星期$weekdayChar',
                style: TextStyle(
                  fontFamily: XuanLiFonts.serif,
                  fontWeight: FontWeight.w700,
                  fontSize: 17,
                  letterSpacing: 3,
                  color: colors.ink,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                '${reading.lunarLabel}・${reading.ganzhiDay}日・${reading.chong}',
                style: TextStyle(fontSize: 11, color: colors.ink60, letterSpacing: 1),
              ),
            ],
          ),
        ),
        GestureDetector(
          onTap: () => ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('設定 — 2g 起')),
          ),
          child: Container(
            width: 30,
            height: 30,
            alignment: Alignment.center,
            decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: colors.ink30)),
            child: Text('☰', style: TextStyle(color: colors.ink60)),
          ),
        ),
      ],
    );
  }
}
```

**Important bug to think through while implementing:** `_weekAnchor()` force-unwraps `widget.initialDate!`, but it's only called when `widget.initialDate == null` is false per the ternary in `build()` — trace this carefully yourself before shipping it. Actually, re-examine: `final weekStart = widget.initialDate == null ? _today() : _weekAnchor();` — `_weekAnchor()` is only invoked in the `else` branch, where `widget.initialDate == null` is already known false, so the force-unwrap is safe *in this specific call site*, but `_weekAnchor()` as a standalone method with a bare `!` is a footgun for any future caller. Consider simplifying this whole thing to just `final weekStart = widget.initialDate ?? _today();` directly inline (no separate method needed at all — this achieves the identical result more simply and removes the footgun entirely). Use your judgment: implement whichever is cleaner, but don't ship a method containing an unguarded `!` if a simpler equivalent exists.

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/screens/today/today_screen_test.dart -v`
Expected: PASS (both tests).

- [ ] **Step 5: Wire `TodayScreen` into `TabShell`**

In `lib/screens/tab_shell.dart`, replace the Tab A placeholder body. Currently `_tabs` drives an `IndexedStack` of `Center(child: Text(tab.placeholder))` for all 3 indices uniformly. Change `_TabShellState.build()`'s `IndexedStack` children to special-case index 0:

```dart
      body: IndexedStack(
        index: _index,
        children: [
          TodayScreen(profile: widget.profile),
          for (final tab in _tabs.skip(1)) Center(child: Text(tab.placeholder)),
        ],
      ),
```

Add the import: `import 'today/today_screen.dart';`. Note `TodayScreen` here is constructed WITHOUT `initialDate` (so it defaults to real "today" in the actual running app — the `initialDate` parameter exists purely for test determinism, per its doc comment).

- [ ] **Step 6: Run the full test suite**

Run: `flutter analyze` → `No issues found!`
Run: `flutter test` → PASS, count 120 + 2 = 122.

- [ ] **Step 7: Attempt a live run (best-effort — same known environment limitation as Phase 2a/2b)**

Run: `flutter devices`. If a device/simulator is now available, run the app, complete onboarding (or use an already-saved profile), and visually compare Tab A against `design/design-preview.html`'s "TAB A" mockup. If the same limitation from Phase 2a/2b still holds, report that clearly rather than skipping silently.

- [ ] **Step 8: Commit**

```bash
git add lib/screens/today/today_screen.dart test/screens/today/today_screen_test.dart lib/screens/tab_shell.dart
git commit -m "feat(today): add TodayScreen (Tab A 今日宜忌), wire into TabShell

Date header, dual fortune/MBTI-fit rings, personalized yi/ji columns
with avoid-hour note, advice card, and a 7-day strip that changes
which day is displayed. This is the first tab with real content —
Tab B/C remain Phase 2a placeholders until 2d/2e."
```

---

## Self-Review Notes

**Spec coverage:** Every element of spec §9.2 has a home: date header with 公曆+農曆+干支+沖煞 (Task 5's `_buildHeader`), 雙環卡 命理分金環+契合度玉綠環 (Task 3's `ScoreRing`, wired in Task 5), 宜/忌兩欄 with ✦合你 (Task 3's `YjColumn`), 🔮貼身建議卡 (Task 3's `AdviceCard`), 未來七日條 that changes the displayed day on tap (Task 4's `Week7Strip`).

**Known, deliberate scope boundary:** the settings hamburger icon (☰) is present and tappable (matching the design) but only shows a "設定 — 2g 起" SnackBar stub — Settings itself is Phase 2g's job, not built here. Tab B/C stay exactly as the Phase 2a placeholders left them.

**Placeholder scan:** every step has complete, literal code — the one explicitly-flagged ambiguity (the `_weekAnchor()` force-unwrap footgun) is called out for the implementer to resolve with judgment, not silently shipped.

**Type consistency:** `TodayScreen.profile`/`ScoreRing`/`YjColumn`/`AdviceCard`/`Week7Strip` all consume the exact `DayReading`/`YjItem`/`Profile` types already defined in `lib/models/` from Phase 1 — no new data types introduced, no drift from `buildDayReading()`'s actual return shape.
