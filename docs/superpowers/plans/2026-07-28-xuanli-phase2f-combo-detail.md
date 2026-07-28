# XuanLi Phase 2f — 組合詳解頁 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build spec §9.5's 組合詳解頁 (combo detail page) — a full-screen view of the user's 日主×MBTI combo (name/motto/description/strengths/watchouts/how-to-win), driven entirely by the 160-template `combos.json` data that was already written and loaded in Phase 1 — and wire navigation to it from the onboarding profile card, per Stephanie's confirmed scope decision (see below).

**Architecture:** `ComboDetailScreen` is a stateless, pure-presentation screen that takes a `Profile` and looks up its combo via the already-existing `getCombo(dayGan:, mbti:)` (`lib/models/combo.dart`, already loads/caches `combos.json` via `initCombos()`/`loadCombos()` from Phase 1 — no new engine/loader code needed this phase). It renders per spec §9.5 and `design/design-preview.html`'s "SECTION 1B" (`id="combo"`): header with back arrow + title + a stubbed share icon, day-master×MBTI chip row, combo name (large), motto, description card, a two-column 優勢/留意位 card pair, a 點樣發力 card, and a rarity placeholder card reading "即將推出" (spec §9.5 explicitly calls for a placeholder here, not a real percentage — real rarity/share-card is locked as 第二版/out of MVP scope per spec §2 decision #11's footnote).

## Scope decision already confirmed with Stephanie (don't re-litigate)

Spec says the combo page is "由檔案卡撳入" (entered by tapping the profile card), but the only 檔案卡 (profile card) that currently exists anywhere in the app is `ProfileCardStep` — onboarding's one-time third step (`lib/screens/onboarding/profile_card_step.dart`). There is no persistent settings/profile screen yet (that's Phase 2g, not yet built). Stephanie confirmed: for 2f, make the onboarding profile card itself tappable → navigate to `ComboDetailScreen`, matching the spec's literal wording now. When Phase 2g adds a persistent profile view, it can link to the same `ComboDetailScreen` too — that's out of scope for this plan.

## One deliberate scope trim (documented, not silent)

The share icon (⇪) in the header (design html shows it, "分享卡" is spec-locked as 第二版/second-version-only, same status as calendar write/read integration handled in earlier sub-plans) is rendered for visual fidelity but is a stub: tapping it shows a `SnackBar` reading "分享卡 — 第二版先做", following the exact established stub pattern from Phase 2d/2e's calendar-integration stubs (`lib/screens/activity/activity_widgets.dart`'s "＋ 加入我嘅日曆" button uses the identical `ScaffoldMessenger.showSnackBar` pattern — this plan reuses that convention, not a new one).

---

## File Structure

```
xuanli/
└── lib/screens/
    ├── combo/
    │   └── combo_screen.dart              # NEW — ComboDetailScreen
    └── onboarding/
        └── profile_card_step.dart         # MODIFY — card becomes tappable
└── test/screens/
    ├── combo/
    │   └── combo_screen_test.dart         # NEW
    └── onboarding/
        └── profile_card_step_test.dart    # MODIFY — add tap-navigates test
```

No new engine code, no new model/loader — `Combo`/`getCombo()`/`initCombos()`/`loadCombos()` already exist and are already covered by `test/services/data_loader_test.dart` (asserts all 160 keys present). This phase is pure UI + one navigation wire-up.

---

### Task 1: `lib/screens/combo/combo_screen.dart` — `ComboDetailScreen`

**Files:**
- Create: `lib/screens/combo/combo_screen.dart`
- Create: `test/screens/combo/combo_screen_test.dart`

Per spec §9.5 + design html `#combo` section: header (‹ back / 我嘅組合 / ⇪ share-stub) + 日主×MBTI chip row + combo name (large serif) + motto + description card + 優勢/留意位 two-column card + 點樣發力 card + rarity placeholder card ("即將推出").

- [ ] **Step 1: Write the failing test**

Create `test/screens/combo/combo_screen_test.dart`:

```dart
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xuanli/engine/profile_builder.dart';
import 'package:xuanli/models/combo.dart';
import 'package:xuanli/screens/combo/combo_screen.dart';
import 'package:xuanli/theme/xuanli_theme.dart';

void main() {
  setUpAll(() {
    initCombos(File('lib/data/combos.json').readAsStringSync());
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

  testWidgets('顯示乙_ISFP嘅組合內容：組合名/motto/優勢/留意位/點樣發力/稀有度佔位', (tester) async {
    await tester.pumpWidget(wrap(ComboDetailScreen(profile: profile)));

    expect(find.text('我嘅組合'), findsOneWidget);
    expect(find.textContaining('乙木日主'), findsOneWidget);
    expect(find.textContaining('ISFP'), findsWidgets);
    expect(find.text('林間清泉'), findsOneWidget);
    expect(find.textContaining('柔韌有光'), findsOneWidget);
    expect(find.textContaining('審美同直覺俱佳'), findsOneWidget);
    expect(find.textContaining('諗多過講'), findsOneWidget);
    expect(find.textContaining('水木旺嘅日子'), findsOneWidget);
    expect(find.textContaining('即將推出'), findsOneWidget);
  });

  testWidgets('撳返、撳分享 icon：返會 pop，分享會顯示 stub SnackBar', (tester) async {
    await tester.pumpWidget(wrap(Builder(builder: (context) {
      return Scaffold(
        body: Center(
          child: ElevatedButton(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => ComboDetailScreen(profile: profile)),
            ),
            child: const Text('open'),
          ),
        ),
      );
    })));

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.text('林間清泉'), findsOneWidget);

    await tester.tap(find.text('⇪'));
    await tester.pump();
    expect(find.textContaining('第二版先做'), findsOneWidget);

    await tester.tap(find.text('‹'));
    await tester.pumpAndSettle();
    expect(find.text('open'), findsOneWidget);
    expect(find.text('林間清泉'), findsNothing);
  });
}
```

Note: `乙_ISFP`'s real `combos.json` content (name `林間清泉`, motto `柔韌有光・靜水深流`, first strength `審美同直覺俱佳`, first watchout `諗多過講，易錯過時機`, `howToWin` starting `水木旺嘅日子（亥子寅卯）你行動力最高`) was read directly from the actual data file before writing this plan — these literals are correct, don't second-guess them.

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/screens/combo/combo_screen_test.dart`
Expected: FAIL — `Error: Not found: 'package:xuanli/screens/combo/combo_screen.dart'`.

- [ ] **Step 3: Write the implementation**

Create `lib/screens/combo/combo_screen.dart`:

```dart
import 'package:flutter/material.dart';

import '../../models/combo.dart';
import '../../models/profile.dart';
import '../../theme/xuanli_theme.dart';

/// 組合詳解頁（spec §9.5）：由檔案卡撳入，顯示 [profile] 嘅日主×MBTI
/// 組合（160 模板之一，`combos.json`／`getCombo()` 已喺 Phase 1 起好）。
/// 純顯示畫面，冇自己嘅 state。
class ComboDetailScreen extends StatelessWidget {
  final Profile profile;

  const ComboDetailScreen({super.key, required this.profile});

  @override
  Widget build(BuildContext context) {
    final colors = context.xuanliColors;
    final dayGan = profile.pillars[2].substring(0, 1);
    final combo = getCombo(dayGan: dayGan, mbti: profile.mbti);

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(context, colors),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(18, 4, 18, 24),
                child: Column(
                  children: [
                    _buildNameCard(colors, dayGan, combo),
                    const SizedBox(height: 12),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(child: _buildListCard(colors, '✦ 你嘅優勢', colors.jade, combo.strengths)),
                        const SizedBox(width: 10),
                        Expanded(child: _buildListCard(colors, '◈ 留意位', colors.red, combo.watchouts)),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _buildHowToWinCard(colors, combo),
                    const SizedBox(height: 12),
                    _buildRarityPlaceholder(colors, dayGan),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, XuanLiColors colors) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 6, 10, 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          GestureDetector(
            onTap: () => Navigator.of(context).pop(),
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: Text('‹', style: TextStyle(fontSize: 22, color: colors.ink60)),
            ),
          ),
          Text(
            '我嘅組合',
            style: TextStyle(
              fontFamily: XuanLiFonts.serif,
              fontWeight: FontWeight.w700,
              fontSize: 16,
              color: colors.ink,
            ),
          ),
          GestureDetector(
            onTap: () => ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('分享卡 — 第二版先做')),
            ),
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: Text('⇪', style: TextStyle(fontSize: 18, color: colors.ink60)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNameCard(XuanLiColors colors, String dayGan, Combo combo) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 22),
      decoration: BoxDecoration(
        color: colors.cardSurface,
        borderRadius: BorderRadius.circular(XuanLiRadii.card),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                decoration: BoxDecoration(
                  color: colors.jade.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '$dayGan${_dayGanElement(dayGan)}日主',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: colors.jade),
                ),
              ),
              const SizedBox(width: 10),
              Text('×', style: TextStyle(fontFamily: XuanLiFonts.serif, fontSize: 15, color: colors.gold)),
              const SizedBox(width: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                decoration: BoxDecoration(
                  color: colors.gold,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  profile.mbti,
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: colors.ink),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            combo.name,
            style: TextStyle(
              fontFamily: XuanLiFonts.serif,
              fontSize: 28,
              fontWeight: FontWeight.w900,
              letterSpacing: 6,
              color: colors.ink,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 6),
          Text(
            combo.motto,
            style: TextStyle(fontSize: 11, color: colors.gold, letterSpacing: 2),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 14),
          Text(
            combo.description,
            style: TextStyle(fontSize: 12.5, height: 1.8, color: colors.ink60),
            textAlign: TextAlign.left,
          ),
        ],
      ),
    );
  }

  Widget _buildListCard(XuanLiColors colors, String title, Color titleColor, List<String> items) {
    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: colors.cardSurface,
        borderRadius: BorderRadius.circular(XuanLiRadii.card),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(fontSize: 11, letterSpacing: 2, fontWeight: FontWeight.w700, color: titleColor),
          ),
          const SizedBox(height: 7),
          for (final item in items)
            Padding(
              padding: const EdgeInsets.only(bottom: 2),
              child: Text(item, style: TextStyle(fontSize: 12, height: 1.6, color: colors.ink)),
            ),
        ],
      ),
    );
  }

  Widget _buildHowToWinCard(XuanLiColors colors, Combo combo) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: colors.cardSurface,
        borderRadius: BorderRadius.circular(XuanLiRadii.card),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '☾ 點樣發力（跟你嘅組合）',
            style: TextStyle(fontSize: 11, letterSpacing: 2, fontWeight: FontWeight.w700, color: colors.gold),
          ),
          const SizedBox(height: 7),
          Text(combo.howToWin, style: TextStyle(fontSize: 12, height: 1.7, color: colors.ink)),
        ],
      ),
    );
  }

  Widget _buildRarityPlaceholder(XuanLiColors colors, String dayGan) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: colors.cardSurface,
        border: Border.all(color: colors.ink12, style: BorderStyle.solid),
        borderRadius: BorderRadius.circular(XuanLiRadii.card),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            '$dayGan${_dayGanElement(dayGan)} × ${profile.mbti}・稀有度',
            style: TextStyle(fontSize: 11.5, color: colors.ink60),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: colors.paper2,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text('即將推出', style: TextStyle(fontSize: 11, color: colors.ink30)),
          ),
        ],
      ),
    );
  }

  static const _ganElement = {
    '甲': '木', '乙': '木', '丙': '火', '丁': '火', '戊': '土',
    '己': '土', '庚': '金', '辛': '金', '壬': '水', '癸': '水',
  };

  String _dayGanElement(String dayGan) => _ganElement[dayGan]!;
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/screens/combo/combo_screen_test.dart -v`
Expected: PASS (both tests).

- [ ] **Step 5: `flutter analyze` clean**

Run: `flutter analyze` → `No issues found!`

- [ ] **Step 6: Commit**

```bash
git add lib/screens/combo/combo_screen.dart test/screens/combo/combo_screen_test.dart
git commit -m "feat(combo): add ComboDetailScreen (組合詳解頁)"
```

---

### Task 2: Wire navigation from the onboarding profile card

**Files:**
- Modify: `lib/screens/onboarding/profile_card_step.dart`
- Modify: `test/screens/onboarding/profile_card_step_test.dart`

- [ ] **Step 1: Write the failing test**

Add to `test/screens/onboarding/profile_card_step_test.dart` (read the current file first — add this as a new `testWidgets` block, keep everything else unchanged; also add the two new imports shown below at the top of the file alongside the existing imports):

```dart
import 'dart:io';

import 'package:xuanli/engine/copywriter.dart';
import 'package:xuanli/models/combo.dart';
import 'package:xuanli/screens/combo/combo_screen.dart';
```

New test (add inside `main()`, alongside the existing `testWidgets` blocks — this one needs its own `setUpAll` for `initCombos`, since none of the other tests in this file need it):

```dart
  group('撳檔案卡入組合詳解頁', () {
    setUpAll(() {
      initCombos(File('lib/data/combos.json').readAsStringSync());
    });

    testWidgets('撳個命理檔案卡會 push ComboDetailScreen，顯示返嗰個組合', (tester) async {
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

      await tester.tap(find.text('阿玄'));
      await tester.pumpAndSettle();

      expect(find.byType(ComboDetailScreen), findsOneWidget);
      expect(find.text('林間清泉'), findsOneWidget);
    });
  });
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/screens/onboarding/profile_card_step_test.dart`
Expected: FAIL — tapping `阿玄` (plain text inside the card, not currently wrapped in any tap handler) does nothing, so `find.byType(ComboDetailScreen)` finds nothing.

- [ ] **Step 3: Write the implementation**

In `lib/screens/onboarding/profile_card_step.dart`:

Add the import at the top (alongside the existing imports):
```dart
import '../combo/combo_screen.dart';
```

Wrap the existing profile-card `Container` (the one with the dark gradient background, currently the direct child passed to the outer `Column` right after the "之後所有推薦..." subtitle) in a `GestureDetector` that pushes `ComboDetailScreen`. Concretely, change:

```dart
          const SizedBox(height: 16),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
```

to:

```dart
          const SizedBox(height: 16),
          GestureDetector(
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => ComboDetailScreen(profile: _profile)),
            ),
            child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
```

...and close the new `GestureDetector` right after the existing `Container`'s closing — i.e. the `Container` that currently ends (right before `OnboardingPrimaryButton(`) needs one more closing `)` for the `GestureDetector`. Concretely, find:

```dart
                ),
              ],
            ),
          ),
          OnboardingPrimaryButton(
```

(this is the profile-card `Container`'s closing, right before the "開始睇今日" button) and change it to:

```dart
                ),
              ],
            ),
          )),
          OnboardingPrimaryButton(
```

Run `flutter analyze` immediately after this edit to confirm brace/paren balance is correct — a manual splice like this is exactly the kind of change where a stray/missing bracket is easy to introduce; don't skip straight to running tests without checking analyze first.

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/screens/onboarding/profile_card_step_test.dart -v`
Expected: PASS (all tests, including the new one — 5 total).

- [ ] **Step 5: `flutter analyze` clean, full suite check**

Run: `flutter analyze` → `No issues found!`
Run: `flutter test` → PASS (report the real total count you observe).

Also specifically re-run `test/screens/onboarding/onboarding_flow_test.dart` — it drives `ProfileCardStep` as part of the full 3-step onboarding flow and taps `'開始睇今日'` at the end; confirm this still passes (the new `GestureDetector` wraps the profile-card `Container`, not the button, so it shouldn't interfere, but verify rather than assume — this exact class of "wiring change breaks a sibling test" regression has recurred multiple times in this project's Phase 2 work, e.g. Phase 2c/2d/2e's `TabShell` wiring tasks).

- [ ] **Step 6: Commit**

```bash
git add lib/screens/onboarding/profile_card_step.dart test/screens/onboarding/profile_card_step_test.dart
git commit -m "feat(onboarding): tapping the profile card opens 組合詳解頁"
```

---

## Self-Review Notes

**Spec coverage:** §9.5's full content list — combo name, motto, description, 優勢/留意位 two-column, 點樣發力, 稀有度佔位「即將推出」— all present in Task 1. Navigation entry point ("由檔案卡撳入") wired in Task 2, matching Stephanie's confirmed scope decision (onboarding card only, for now). Share icon shown for visual fidelity per design html, stubbed per spec's 第二版-locked status, using the exact same `SnackBar` stub convention already established in `activity_widgets.dart`.

**No new engine/loader code:** confirmed `Combo`/`initCombos`/`loadCombos`/`getCombo` already exist from Phase 1 and are already tested (`data_loader_test.dart` asserts 160 keys). This plan only consumes that existing API — YAGNI respected, no duplicate loader logic.

**Known regression-fix pattern to watch for:** Task 2's manual brace-splice into an existing, working, already-tested widget file (`profile_card_step.dart`) is exactly the kind of edit that has caused sibling-test breakage in this project before (`TabShell` wiring in Phases 2c/2d/2e) — Task 2 explicitly calls out running `flutter analyze` immediately after the edit and re-running the full onboarding flow test, not just the file's own test.

**Placeholder scan:** every step has complete, literal code; the only "placeholder" is the spec-mandated rarity placeholder card itself, which is not a plan gap — it's the literal spec requirement (§9.5: "稀有度佔位（顯示「即將推出」）").

**Type consistency:** `ComboDetailScreen(profile: profile)` constructor matches its only call site in Task 2 exactly. `getCombo(dayGan:, mbti:)` and `Combo.name/motto/description/strengths/watchouts/howToWin` match `lib/models/combo.dart`'s actual current API exactly (re-read verbatim before writing this plan).
