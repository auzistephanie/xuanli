# XuanLi Phase 2e — Tab C 月曆 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build spec §9.4's month calendar screen — a 7-column grid coloured by personal 吉/忌/平 band, month navigation, and a tap-to-expand day card — replacing `TabShell`'s Tab C placeholder. No new engine functions needed this time: `buildDayReading()`, `computeFortuneScore()`, and `computeAnnualOutlook()` (from Phase 2a/2b/2d) cover everything.

**Architecture:** `CalendarScreen` owns `_displayedMonth` (which month is showing) and `_selectedDate` (which day's card is expanded, `null` if none). On every rebuild it computes ONE lightweight `CalendarCellData` per day in the displayed month (date, lunar label, band — via `AlmanacDay.forDate()` + `computeFortuneScore()`, NOT the full `buildDayReading()`, since grid cells don't need advice/MBTI/yi-ji) — this is the single-pass-per-render discipline Phase 2d's review established, applied proactively here rather than discovered as a bug. The full `buildDayReading()` (yi/ji/advice/scores) is only computed once, for whichever single day is currently expanded in the day card — never for all ~30 grid days. Presentational pieces (`CalendarGrid`, `DayCard`) live in their own widgets file, matching the established `today_widgets.dart`/`activity_widgets.dart` pattern.

## Scope decision already confirmed with Stephanie (don't re-litigate)

Same as Phase 2d's calendar-write stub: the month grid's "有行程" event-indicator bar and the day card's "📅 你嘅行程" event list both need real `device_calendar` reads (spec §9.9), which can't be tested in this environment (no simulator/device) and is spec'd as its own cross-cutting integration point. Stephanie confirmed: ship the grid + day card fully, with the event-related pieces visibly stubbed (a `hasEvents` flag that's always `false` for now, and a labeled stub line in the day card) — real integration is a dedicated later sub-plan covering both Tab B's write button and Tab C's read display together.

## Two deliberate scope trims (documented, not silent)

1. **Month-ganzhi subtitle simplified.** Design html's header shows "丙午年・乙未月（小暑後）" — year ganzhi + month ganzhi + solar-term note. This plan only shows the year ganzhi ("丙午年", via the already-existing `computeAnnualOutlook()` — zero new engine code needed) and drops the month-ganzhi/solar-term detail, which would need a new engine function for marginal cosmetic value. Worth revisiting later if Stephanie wants full fidelity.
2. **Day card's 宜/忌 display is a compact one-line-each list** (`宜 A・B・C` / `忌 D・E`), not Tab A's boxed `YjColumn` treatment or the "✦ [element]旺日，你嘅大日子" per-match flourish design html shows. This is a deliberately lighter secondary view, not a duplicate of Tab A.

---

## File Structure

```
xuanli/
└── lib/screens/
    ├── tab_shell.dart                  # MODIFY — Tab C placeholder → real CalendarScreen
    └── calendar/
        ├── calendar_widgets.dart       # NEW — CalendarGrid (+ legend), DayCard
        └── calendar_screen.dart        # NEW — Tab C composition
└── test/screens/
    ├── tab_shell_test.dart             # MODIFY — Tab C assertion updates
    └── calendar/
        ├── calendar_widgets_test.dart  # NEW
        └── calendar_screen_test.dart   # NEW
```

---

### Task 1: `lib/screens/calendar/calendar_widgets.dart` — `CalendarGrid`, `DayCard`

**Files:**
- Create: `lib/screens/calendar/calendar_widgets.dart`
- Create: `test/screens/calendar/calendar_widgets_test.dart`

Per spec §9.4: 7-column grid (吉玉綠/忌朱紅/平淡墨 dots, 藏藍幼條 for events — stubbed, 今日金框), plus an expanded day card (date+band+score chip, subtitle, compact yi/ji lines, stubbed event section).

- [ ] **Step 1: Write the failing test**

Create `test/screens/calendar/calendar_widgets_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xuanli/screens/calendar/calendar_widgets.dart';
import 'package:xuanli/theme/xuanli_theme.dart';

void main() {
  Widget wrap(Widget child) =>
      MaterialApp(theme: XuanLiTheme.light(), home: Scaffold(body: child));

  group('CalendarGrid', () {
    testWidgets('顯示成個月啲日子（含前置留白），撳日會 call onSelectDay', (tester) async {
      final days = [
        for (var d = 1; d <= 5; d++)
          CalendarCellData(day: d, lunarLabel: '初$d', band: '平', isToday: d == 3),
      ];
      int? selected;

      await tester.pumpWidget(wrap(CalendarGrid(
        leadingBlanks: 2,
        days: days,
        selectedDay: null,
        onSelectDay: (d) => selected = d,
      )));

      expect(find.text('3'), findsOneWidget);
      await tester.tap(find.text('3'));
      expect(selected, 3);
    });
  });

  group('DayCard', () {
    testWidgets('顯示日期/分數/副標題/宜忌，冇行程就顯示 stub 提示', (tester) async {
      await tester.pumpWidget(wrap(const DayCard(
        dateLabel: '7月16日（四）辛卯日',
        band: '吉',
        score: 88,
        subtitleLine: '六月初三・成日・沖雞煞西',
        yiLine: '嫁娶・祈福・剪髮',
        jiLine: '伐木・掘井',
      )));

      expect(find.text('7月16日（四）辛卯日'), findsOneWidget);
      expect(find.textContaining('吉'), findsWidgets);
      expect(find.textContaining('88'), findsOneWidget);
      expect(find.textContaining('嫁娶'), findsOneWidget);
      expect(find.textContaining('伐木'), findsOneWidget);
      expect(find.textContaining('行事曆整合'), findsOneWidget);
    });
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/screens/calendar/calendar_widgets_test.dart`
Expected: FAIL — `Error: Not found: 'package:xuanli/screens/calendar/calendar_widgets.dart'`.

- [ ] **Step 3: Write the implementation**

Create `lib/screens/calendar/calendar_widgets.dart`:

```dart
import 'package:flutter/material.dart';

import '../../theme/xuanli_theme.dart';

/// 一格月曆格仔嘅顯示資料（screen 計好先遞落嚟，widget 本身唔做
/// engine 計算——同 today_widgets.dart/activity_widgets.dart 一樣嘅
/// 「dumb widget」原則）。
class CalendarCellData {
  final int day;
  final String lunarLabel;
  final String band; // "吉"|"平"|"忌"
  final bool isToday;
  final bool hasEvents; // 永遠 false（stub，行事曆整合留返之後 sub-plan）

  const CalendarCellData({
    required this.day,
    required this.lunarLabel,
    required this.band,
    this.isToday = false,
    this.hasEvents = false,
  });
}

/// 月曆格仔（design html 月 grid）。[leadingBlanks] 係 1 號之前嘅空白格
/// 數量（0-6，由嗰個月 1 號係星期幾決定）。
class CalendarGrid extends StatelessWidget {
  final int leadingBlanks;
  final List<CalendarCellData> days;
  final int? selectedDay;
  final ValueChanged<int> onSelectDay;

  const CalendarGrid({
    super.key,
    required this.leadingBlanks,
    required this.days,
    required this.selectedDay,
    required this.onSelectDay,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.xuanliColors;
    return Column(
      children: [
        GridView.count(
          crossAxisCount: 7,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 4,
          crossAxisSpacing: 4,
          children: [
            for (var i = 0; i < leadingBlanks; i++) const SizedBox.shrink(),
            for (final cell in days) _buildCell(context, colors, cell),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _legendItem(colors, colors.jade, '吉'),
            const SizedBox(width: 14),
            _legendItem(colors, colors.red, '忌'),
            const SizedBox(width: 14),
            _legendItem(colors, colors.ink30, '平'),
            const SizedBox(width: 14),
            Row(
              children: [
                Container(width: 12, height: 3, color: colors.ink60),
                const SizedBox(width: 4),
                Text('有行程', style: TextStyle(fontSize: 10.5, color: colors.ink60)),
              ],
            ),
          ],
        ),
      ],
    );
  }

  Widget _legendItem(XuanLiColors colors, Color dotColor, String label) {
    return Row(
      children: [
        Container(width: 9, height: 9, decoration: BoxDecoration(color: dotColor, borderRadius: BorderRadius.circular(3))),
        const SizedBox(width: 4),
        Text(label, style: TextStyle(fontSize: 10.5, color: colors.ink60)),
      ],
    );
  }

  Widget _buildCell(BuildContext context, XuanLiColors colors, CalendarCellData cell) {
    final dotColor = cell.band == '吉'
        ? colors.jade
        : cell.band == '忌'
            ? colors.red
            : colors.ink30;
    final bgColor = cell.band == '吉'
        ? colors.jade.withValues(alpha: 0.10)
        : cell.band == '忌'
            ? colors.red.withValues(alpha: 0.08)
            : colors.cardSurface;
    final isSelected = cell.day == selectedDay;

    return GestureDetector(
      onTap: () => onSelectDay(cell.day),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 5),
        decoration: BoxDecoration(
          color: bgColor,
          border: Border.all(
            color: cell.isToday ? colors.gold : colors.ink12,
            width: cell.isToday ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(XuanLiRadii.cell),
          boxShadow: isSelected
              ? [BoxShadow(color: colors.jade, spreadRadius: 2, blurRadius: 0)]
              : null,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              '${cell.day}',
              style: TextStyle(
                fontFamily: XuanLiFonts.serif,
                fontWeight: FontWeight.w700,
                fontSize: 13,
                color: colors.ink,
              ),
            ),
            Text(
              cell.lunarLabel,
              style: TextStyle(fontSize: 8.5, color: colors.ink60),
            ),
            const SizedBox(height: 3),
            Container(width: 5, height: 5, decoration: BoxDecoration(color: dotColor, shape: BoxShape.circle)),
            if (cell.hasEvents) ...[
              const SizedBox(height: 2),
              Container(width: 14, height: 2.5, decoration: BoxDecoration(color: colors.ink60, borderRadius: BorderRadius.circular(2))),
            ],
          ],
        ),
      ),
    );
  }
}

/// 展開日卡（design html 撳日展開嗰張卡）。宜/忌用一行精簡列表顯示
/// （唔係 Tab A `YjColumn` 嗰種盒仔），行程部分係 stub。
class DayCard extends StatelessWidget {
  final String dateLabel;
  final String band;
  final int score;
  final String subtitleLine;
  final String yiLine;
  final String jiLine;

  const DayCard({
    super.key,
    required this.dateLabel,
    required this.band,
    required this.score,
    required this.subtitleLine,
    required this.yiLine,
    required this.jiLine,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.xuanliColors;
    final bandColor = band == '吉' ? colors.jade : (band == '忌' ? colors.red : colors.ink60);
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colors.cardSurface,
        border: Border.all(color: colors.ink12),
        borderRadius: BorderRadius.circular(XuanLiRadii.card),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  dateLabel,
                  style: TextStyle(
                    fontFamily: XuanLiFonts.serif,
                    fontSize: 15.5,
                    fontWeight: FontWeight.w700,
                    color: colors.ink,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                decoration: BoxDecoration(
                  color: bandColor.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '$band $score',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: bandColor),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(subtitleLine, style: TextStyle(fontSize: 11, color: colors.ink60)),
          Container(
            margin: const EdgeInsets.only(top: 8),
            padding: const EdgeInsets.only(top: 8),
            decoration: BoxDecoration(border: Border(top: BorderSide(color: colors.ink12))),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text.rich(
                  TextSpan(children: [
                    TextSpan(text: '宜 ', style: TextStyle(color: colors.jade, fontWeight: FontWeight.w700)),
                    TextSpan(text: yiLine, style: TextStyle(color: colors.ink)),
                  ]),
                  style: const TextStyle(fontSize: 12.5, height: 1.7),
                ),
                Text.rich(
                  TextSpan(children: [
                    TextSpan(text: '忌 ', style: TextStyle(color: colors.red, fontWeight: FontWeight.w700)),
                    TextSpan(text: jiLine, style: TextStyle(color: colors.ink)),
                  ]),
                  style: const TextStyle(fontSize: 12.5, height: 1.7),
                ),
              ],
            ),
          ),
          Container(
            margin: const EdgeInsets.only(top: 8),
            padding: const EdgeInsets.only(top: 8),
            decoration: BoxDecoration(border: Border(top: BorderSide(color: colors.ink12))),
            child: Text(
              '📅 你嘅行程 — 行事曆整合之後 sub-plan 起',
              style: TextStyle(fontSize: 11.5, color: colors.ink60),
            ),
          ),
        ],
      ),
    );
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/screens/calendar/calendar_widgets_test.dart -v`
Expected: PASS (both tests).

- [ ] **Step 5: `flutter analyze` clean**

Run: `flutter analyze` → `No issues found!`

- [ ] **Step 6: Commit**

```bash
git add lib/screens/calendar/calendar_widgets.dart test/screens/calendar/calendar_widgets_test.dart
git commit -m "feat(calendar): add CalendarGrid, DayCard widgets"
```

---

### Task 2: `lib/screens/calendar/calendar_screen.dart` — Tab C composition

**Files:**
- Create: `lib/screens/calendar/calendar_screen.dart`
- Create: `test/screens/calendar/calendar_screen_test.dart`

Per spec §9.4: month header with prev/next navigation, weekday row, `CalendarGrid`, tap-to-expand `DayCard`. Range 1900–2100 (`lunar` package's own limit — navigation should not go outside it).

- [ ] **Step 1: Write the failing test**

Create `test/screens/calendar/calendar_screen_test.dart`:

```dart
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xuanli/engine/almanac.dart';
import 'package:xuanli/engine/copywriter.dart';
import 'package:xuanli/engine/profile_builder.dart';
import 'package:xuanli/screens/calendar/calendar_screen.dart';
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

  testWidgets('顯示 2026 年 7 月，今日（7月11日）預設展開日卡', (tester) async {
    await tester.pumpWidget(wrap(CalendarScreen(
      profile: profile,
      today: DateTime(2026, 7, 11),
    )));

    expect(find.textContaining('2026年7月'), findsOneWidget);
    expect(find.textContaining('丙午年'), findsOneWidget);
    // 今日預設展開，日卡應該顯示緊 7-11 golden fixture 嘅內容。
    expect(find.textContaining('7月11日'), findsOneWidget);
    expect(find.textContaining('丙戌'), findsWidgets);
  });

  testWidgets('撳「›」去下個月，header 會轉，選日狀態reset（冇日卡）', (tester) async {
    await tester.pumpWidget(wrap(CalendarScreen(
      profile: profile,
      today: DateTime(2026, 7, 11),
    )));

    await tester.tap(find.text('›'));
    await tester.pumpAndSettle();

    expect(find.textContaining('2026年8月'), findsOneWidget);
  });

  testWidgets('撳月曆入面第 16 日（7月16日），日卡轉去嗰日', (tester) async {
    await tester.pumpWidget(wrap(CalendarScreen(
      profile: profile,
      today: DateTime(2026, 7, 11),
    )));

    await tester.tap(find.text('16'));
    await tester.pumpAndSettle();

    expect(find.textContaining('7月16日'), findsOneWidget);
    expect(find.textContaining('辛卯'), findsWidgets);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/screens/calendar/calendar_screen_test.dart`
Expected: FAIL — `Error: Not found: 'package:xuanli/screens/calendar/calendar_screen.dart'`.

- [ ] **Step 3: Write the implementation**

Create `lib/screens/calendar/calendar_screen.dart`:

```dart
import 'package:flutter/material.dart';

import '../../engine/almanac.dart';
import '../../engine/annual_outlook.dart';
import '../../engine/day_reading_engine.dart';
import '../../engine/scoring.dart';
import '../../models/profile.dart';
import '../../theme/xuanli_theme.dart';
import 'calendar_widgets.dart';

/// Tab C・月曆（spec §9.4）。[today] 冇畀就用今日（同 [TodayScreen]／
/// [ActivityScreen] 一樣嘅 UI-only「初始顯示邊個月/邊日」模式）。
class CalendarScreen extends StatefulWidget {
  final Profile profile;
  final DateTime? today;

  const CalendarScreen({super.key, required this.profile, this.today});

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  static const _weekdayHeaders = ['日', '一', '二', '三', '四', '五', '六'];
  static const _minMonth = DateTime(1900, 1);
  static const _maxMonth = DateTime(2100, 12);

  late DateTime _displayedMonth;
  int? _selectedDay;

  DateTime get _today {
    final t = widget.today;
    if (t != null) return t;
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }

  @override
  void initState() {
    super.initState();
    final today = _today;
    _displayedMonth = DateTime(today.year, today.month);
    _selectedDay = today.day;
  }

  bool get _showsToday =>
      _displayedMonth.year == _today.year && _displayedMonth.month == _today.month;

  void _changeMonth(int delta) {
    final next = DateTime(_displayedMonth.year, _displayedMonth.month + delta);
    if (next.isBefore(_minMonth) || next.isAfter(_maxMonth)) return;
    setState(() {
      _displayedMonth = next;
      _selectedDay = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.xuanliColors;
    final year = _displayedMonth.year;
    final month = _displayedMonth.month;
    final daysInMonth = DateTime(year, month + 1, 0).day;
    final leadingBlanks = DateTime(year, month, 1).weekday % 7;

    final userYearZhi = widget.profile.pillars[0].substring(1);
    final cells = [
      for (var d = 1; d <= daysInMonth; d++)
        _cellFor(DateTime(year, month, d), isToday: _showsToday && d == _today.day),
    ];

    final yearGanZhi = computeAnnualOutlook(
      date: _displayedMonth,
      userYearZhi: userYearZhi,
    ).yearGanZhi;

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(18, 10, 18, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                GestureDetector(
                  onTap: () => _changeMonth(-1),
                  child: Text('‹', style: TextStyle(fontSize: 20, color: colors.ink60)),
                ),
                Column(
                  children: [
                    Text(
                      '$year年$month月',
                      style: TextStyle(
                        fontFamily: XuanLiFonts.serif,
                        fontWeight: FontWeight.w700,
                        fontSize: 17,
                        letterSpacing: 2,
                        color: colors.ink,
                      ),
                    ),
                    Text(
                      '$yearGanZhi年',
                      style: TextStyle(fontSize: 11, color: colors.ink60, letterSpacing: 1),
                    ),
                  ],
                ),
                GestureDetector(
                  onTap: () => _changeMonth(1),
                  child: Text('›', style: TextStyle(fontSize: 20, color: colors.ink60)),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                for (final w in _weekdayHeaders)
                  Expanded(
                    child: Center(
                      child: Text(
                        w,
                        style: TextStyle(
                          fontSize: 10.5,
                          color: w == '日' ? colors.red : colors.ink60,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 6),
            CalendarGrid(
              leadingBlanks: leadingBlanks,
              days: cells,
              selectedDay: _selectedDay,
              onSelectDay: (d) => setState(() => _selectedDay = d),
            ),
            if (_selectedDay != null) _buildDayCard(colors, DateTime(year, month, _selectedDay!)),
          ],
        ),
      ),
    );
  }

  CalendarCellData _cellFor(DateTime date, {required bool isToday}) {
    final day = AlmanacDay.forDate(date);
    final userYearZhi = widget.profile.pillars[0].substring(1);
    final band = computeFortuneScore(
      day: day,
      favorable: widget.profile.favorable,
      unfavorable: widget.profile.unfavorable,
      userYearZhi: userYearZhi,
    ).band;
    return CalendarCellData(
      day: date.day,
      lunarLabel: day.lunarLabel,
      band: band,
      isToday: isToday,
    );
  }

  Widget _buildDayCard(XuanLiColors colors, DateTime date) {
    final reading = buildDayReading(profile: widget.profile, date: date);
    final weekdayChar = _weekdayHeaders[date.weekday % 7];
    final dateLabel = '${date.month}月${date.day}日（$weekdayChar）${reading.ganzhiDay}日';
    final subtitleLine = '${reading.lunarLabel}・${reading.zhiXing}日・${reading.chong}';

    return DayCard(
      dateLabel: dateLabel,
      band: reading.band,
      score: reading.fortuneScore,
      subtitleLine: subtitleLine,
      yiLine: reading.yi.map((e) => e.label).join('・'),
      jiLine: reading.ji.map((e) => e.label).join('・'),
    );
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/screens/calendar/calendar_screen_test.dart -v`
Expected: PASS (all 3 tests).

- [ ] **Step 5: `flutter analyze` clean, full suite check**

Run: `flutter analyze` → `No issues found!`
Run: `flutter test` → PASS (run it first to find your real current baseline — every prior sub-plan in this project has shown the plan's own predicted counts go stale; report the real number you observe).

- [ ] **Step 6: Commit**

```bash
git add lib/screens/calendar/calendar_screen.dart test/screens/calendar/calendar_screen_test.dart
git commit -m "feat(calendar): add CalendarScreen (Tab C 月曆) composition"
```

---

### Task 3: Wire `CalendarScreen` into `TabShell`

**Files:**
- Modify: `lib/screens/tab_shell.dart`
- Modify: `test/screens/tab_shell_test.dart`

- [ ] **Step 1: Update `lib/screens/tab_shell.dart`**

Read the current file first (it now has `TodayScreen` at index 0 and `ActivityScreen` at index 1 from Phase 2c/2d). Change the `IndexedStack` so index 2 also gets real content — this is now the LAST tab, so there's no more `.skip()`/placeholder loop needed:

```dart
      body: IndexedStack(
        index: _index,
        children: [
          TodayScreen(profile: widget.profile),
          ActivityScreen(profile: widget.profile),
          CalendarScreen(profile: widget.profile),
        ],
      ),
```

Add the import: `import 'calendar/calendar_screen.dart';`. At this point `_TabInfo.placeholder` becomes entirely dead (no `Center(child: Text(tab.placeholder))` call sites remain) — remove the now-unused `placeholder` field from `_TabInfo` and its 3 usages in `_tabs`, since keeping dead fields around after this task would be the kind of thing a future `flutter analyze`/lint pass would flag as unused, and there's no reason to carry it forward now that all 3 tabs are real.

- [ ] **Step 2: Update `test/screens/tab_shell_test.dart`**

Read the current file first — it likely has a test asserting `find.text('Tab C — 2e 起')` after tapping "月曆" (from when Tab C was still a placeholder). Update to check for something `CalendarScreen` actually renders (e.g. a month-year string like `find.textContaining('年')` combined with a weekday header, or simplest: `find.textContaining('月')` is too generic — use something specific like the weekday header row, e.g. `expect(find.text('日'), findsWidgets);` combined with confirming `Tab C — 2e 起` is genuinely gone via `findsNothing`). This file's `setUpAll` should already have `initActivities`/`initActivityCategories`/`initMbtiTones` from Phase 2c/2d's fixes — `CalendarScreen` doesn't need any NEW `init*()` call beyond what's already there (it uses `buildDayReading`/`computeFortuneScore`/`computeAnnualOutlook`, all already covered), but verify this yourself rather than assuming.

- [ ] **Step 3: Run the full test suite**

Run: `flutter analyze` → `No issues found!`
Run: `flutter test` → PASS. Also check `test/screens/onboarding/onboarding_flow_test.dart` and any other test that renders a full `TabShell` — grep for `TabShell` (not just `TabShell(`, per the lesson from Phase 2c/2d where a test navigated to one without directly constructing it) across `test/` to find every affected file.

- [ ] **Step 4: Attempt a live run (best-effort — same known environment limitation as every prior phase)**

Run: `flutter devices`. If unavailable (expected), report clearly rather than skipping silently.

- [ ] **Step 5: Commit**

```bash
git add lib/screens/tab_shell.dart test/screens/tab_shell_test.dart
git commit -m "feat(app): wire CalendarScreen into TabShell's Tab C slot

All 3 tabs are now real screens -- TabShell's placeholder scaffolding
(the _TabInfo.placeholder field and its Center(Text(...)) call sites)
is fully retired. This completes spec section 9's core three-tab
navigation (onboarding, Tab A, Tab B, Tab C); remaining spec sections
(組合詳解頁, widgets, notifications, settings, real calendar
integration) are their own future sub-plans."
```

---

## Self-Review Notes

**Spec coverage:** Month grid with 吉/忌/平 dots + today's gold outline (`CalendarGrid`), month navigation with 1900–2100 clamping (`_changeMonth`), tap-to-expand day card matching "Tab A 格式" in spirit (date/band/score/宜忌/行程) via `DayCard`. The two documented scope trims (month-ganzhi/solar-term subtitle, compact yi/ji display) are explicitly noted, not silent gaps. The event-integration stub matches Phase 2d's precedent exactly (visible label, no fake data).

**Known regression-fix pattern to watch for:** exactly like Phase 2c/2d, wiring the third real tab into `TabShell` may break any existing test that renders a full `TabShell` without every `init*()` call all three real tabs transitively need. Task 3 explicitly calls this out.

**Performance discipline applied proactively:** unlike Phase 2d's `ActivityScreen` (which needed a review-driven fix after shipping a redundant double-scan), this plan's `CalendarScreen` is designed from the start to compute the cheap `CalendarCellData` once per grid day and the expensive full `buildDayReading()` only once (for the single expanded day), not for all ~30 grid days — applying the lesson from Phase 2d's review up front rather than waiting to rediscover it.

**Placeholder scan:** every step has complete, literal code. The stub event-related pieces are clearly labeled in-app text, not silently incomplete.

**Type consistency:** `CalendarScreen` calls `AlmanacDay.forDate()`, `computeFortuneScore()`, `computeAnnualOutlook()`, `buildDayReading()` with the exact parameter names those existing functions already expose — no drift. `CalendarGrid`/`DayCard`'s fields are all primitives composed by the screen, matching the established "dumb widget" pattern from Phase 2c/2d.
