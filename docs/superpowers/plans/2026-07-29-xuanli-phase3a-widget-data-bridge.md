# XuanLi Phase 3a — Widget Data Bridge Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build the Dart-side half of spec §9.6's widget data flow — a `WidgetDataBridge` service that computes the next 7 days' `DayReading` and writes it via `home_widget` (`HomeWidget.saveWidgetData`/`updateWidget`), wired to refresh on every app launch — plus the short-form copywriter text spec §9.7 calls "copywriter 短版" (needed by both the widget's compact display and, later, notifications).

**Scope boundary (read this first):** This plan does **NOT** build the native iOS WidgetKit extension or Android AppWidgetProvider — those require Xcode/Android Studio, neither of which is installed on this Mac (`flutter doctor` confirms: no full Xcode.app, only Command Line Tools; no CocoaPods; no Android SDK). Stephanie is installing that tooling separately. This plan also does **NOT** build notification scheduling (`flutter_local_notifications`/`zonedSchedule`, spec §9.7's delivery mechanism) — that package uses a different testing architecture (Pigeon-generated platform interfaces, not a simple mockable `MethodChannel` like `device_calendar`/`home_widget`) and getting notification fire-times correct requires real device-timezone detection (a new dependency, `flutter_timezone` — unlike the calendar-write case in Phase 2h where plain UTC turned out to be correct, wrong timezone handling here would make notifications fire at the wrong wall-clock hour, a real functional bug). Both deserve focused investigation as their own follow-up plan rather than being rushed in here. What THIS plan delivers is real, fully tested, and useful on its own: the moment native widget code exists, it has correct JSON to read.

**Architecture:** `WidgetDayPayload` (a small DTO, JSON-serializable) holds one day's widget-relevant fields, derived from the existing `DayReading` (`lib/engine/day_reading_engine.dart`). `WidgetDataBridge.refreshNext7Days(Profile)` computes 7 `WidgetDayPayload`s starting today, JSON-encodes them as a single string, and calls `HomeWidget.saveWidgetData` + `HomeWidget.updateWidget`. Like `CalendarSyncService` (Phase 2h), it never throws — every platform-channel interaction is wrapped so a missing/unregistered native widget (the current, pre-tooling reality) degrades to a silent no-op rather than crashing app startup. Wired into `main.dart`'s `_AppBootstrap._run()`, fire-and-forget (not awaited) so a slow/failing widget refresh can never delay cold start.

**Tech Stack:** `home_widget` (already in `pubspec.yaml`, version `^0.7.0`, unused until now — same "already-present, never-wired" situation `device_calendar` was in before Phase 2h). No new packages. Tests use `TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(...)` against `home_widget`'s channel (`MethodChannel('home_widget')`, confirmed by reading the installed package source at `~/.pub-cache/hosted/pub.dev/home_widget-0.7.0+1/lib/src/home_widget.dart`) — the exact same technique proven in Phase 2h for `device_calendar`.

---

## Scope decisions (don't re-litigate)

1. **No new packages.** `home_widget` is already present and unused. Notification scheduling and its `flutter_timezone` dependency are explicitly deferred (see Scope boundary above).
2. **`updateWidget`'s `iOSName`/`androidName` are placeholder constants** (`'XuanLiWidget'` / `'XuanLiWidgetProvider'`) that don't yet correspond to any real native widget (none exists). They're documented as needing to match whatever the actual native Widget/AppWidgetProvider class ends up named once the native extension is built — this is intentionally forward-looking, not a claim that native wiring is done.
3. **`refreshNext7Days` is fire-and-forget from `_AppBootstrap._run()`**, not awaited — spec's own Phase 2 acceptance criterion ("冷啟動 <2s") means a background data-refresh must never gate the main navigation flow, and since every failure path inside `WidgetDataBridge` is already caught internally, there's nothing meaningful to await for anyway (no UI depends on its result).
4. **Widget JSON only includes what spec §9.6 actually lists for 小/中 sizes** (score, band, date, lunar label, top 3 宜/2 忌, avoidHour) — not the full `DayReading` (advice/mbtiScore/clashWarning aren't shown on the widget per spec, so they're not serialized).

---

## File Structure

```
xuanli/
└── lib/
    ├── engine/
    │   └── copywriter.dart                  # MODIFY — add buildNotificationText()
    └── services/
        └── widget_data_bridge.dart          # NEW — WidgetDayPayload, WidgetDataBridge
    └── main.dart                            # MODIFY — wire refresh into _AppBootstrap
└── test/
    ├── engine/
    │   └── copywriter_test.dart             # MODIFY — buildNotificationText tests
    ├── services/
    │   └── widget_data_bridge_test.dart     # NEW
    └── widget_test.dart                     # MODIFY — bootstrap wiring test
```

---

### Task 1: `buildNotificationText()` — short-form copywriter text

**Files:**
- Modify: `lib/engine/copywriter.dart`
- Modify: `test/engine/copywriter_test.dart`

Per spec §9.7's example: `"今日丙戌日・命理分 42・宜祈福靜修，忌簽約。避開申時落大決定。"` — one line combining ganzhi day, fortune score, top yi/ji items, and an optional avoid-hour warning. This is used by the widget's "中" size (spec §9.6) and will be reused by notification scheduling once that's built.

- [ ] **Step 1: Write the failing test**

Read the current `test/engine/copywriter_test.dart` first to match its exact style (imports, `setUpAll`, how other `build*` functions are tested — look at the existing `buildAdvice`/`buildActivityReason` test groups for the pattern). Add a new test group:

```dart
  group('buildNotificationText', () {
    test('組合日干支/命理分/宜忌/避時做一行（spec §9.7 例子格式）', () {
      final day = AlmanacDay.forDate(DateTime(2026, 7, 11)); // golden fixture: 丙戌, 平, 沖龍煞北
      final reading = DayReading(
        date: day.date,
        ganzhiDay: day.ganzhiDay,
        lunarLabel: day.lunarLabel,
        zhiXing: day.zhiXing,
        chong: day.chong,
        fortuneScore: 42,
        mbtiScore: 60,
        band: '平',
        yi: const [YjItem(label: '祈福', matchesUser: true), YjItem(label: '靜修', matchesUser: false)],
        ji: const [YjItem(label: '簽約', matchesUser: false)],
        advice: '（唔用於呢個 test）',
        clashWarning: null,
        avoidHour: '申時',
      );

      final text = buildNotificationText(reading);

      expect(text, '今日丙戌日・命理分42・宜祈福、靜修，忌簽約。避開申時落大決定。');
    });

    test('yi 淨係得一項，ji 冇 → 忌部分寫「無」，冇避時就冇最後嗰句', () {
      final day = AlmanacDay.forDate(DateTime(2026, 7, 11));
      final reading = DayReading(
        date: day.date,
        ganzhiDay: day.ganzhiDay,
        lunarLabel: day.lunarLabel,
        zhiXing: day.zhiXing,
        chong: day.chong,
        fortuneScore: 88,
        mbtiScore: 60,
        band: '吉',
        yi: const [YjItem(label: '開光', matchesUser: true)],
        ji: const [],
        advice: '（唔用於呢個 test）',
        clashWarning: null,
        avoidHour: null,
      );

      final text = buildNotificationText(reading);

      expect(text, '今日丙戌日・命理分88・宜開光，忌無。');
    });

    test('yi 超過 2 項淨係攞頭 2 個', () {
      final day = AlmanacDay.forDate(DateTime(2026, 7, 11));
      final reading = DayReading(
        date: day.date,
        ganzhiDay: day.ganzhiDay,
        lunarLabel: day.lunarLabel,
        zhiXing: day.zhiXing,
        chong: day.chong,
        fortuneScore: 50,
        mbtiScore: 60,
        band: '平',
        yi: const [
          YjItem(label: 'A', matchesUser: false),
          YjItem(label: 'B', matchesUser: false),
          YjItem(label: 'C', matchesUser: false),
        ],
        ji: const [],
        advice: '（唔用於呢個 test）',
        clashWarning: null,
        avoidHour: null,
      );

      final text = buildNotificationText(reading);

      expect(text, '今日丙戌日・命理分50・宜A、B，忌無。');
    });
  });
```

You'll need `import '../../lib/models/day_reading.dart';` (or whatever relative path the existing test file already uses for other engine test imports — check first, likely `package:xuanli/models/day_reading.dart`) if `DayReading`/`YjItem` aren't already imported in this test file.

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/engine/copywriter_test.dart`
Expected: FAIL — `buildNotificationText` isn't defined.

- [ ] **Step 3: Write the implementation**

Read the current `lib/engine/copywriter.dart` first. Add the import at the top (check if `day_reading.dart` is already imported — likely not, since this file currently only works with `AlmanacDay`/`Activity`):
```dart
import '../models/day_reading.dart';
```

Add this function (placement: after `buildActivityReason`, at the end of the file):

```dart
/// 短版通知文案（spec §9.7：「內容 = copywriter 短版」，例子：
/// 「今日丙戌日・命理分 42・宜祈福靜修，忌簽約。避開申時落大決定。」）。
/// 淨係攞頭 2 個宜、頭 2 個忌（多過就截，全空就寫「無」），
/// deterministic（純 [reading] 做 input，冇 Random/DateTime.now()）。
/// 畀 widget「中」size 同（之後先起嘅）通知排程共用。
String buildNotificationText(DayReading reading) {
  final yiPart = reading.yi.isEmpty
      ? '無'
      : reading.yi.take(2).map((e) => e.label).join('、');
  final jiPart = reading.ji.isEmpty
      ? '無'
      : reading.ji.take(2).map((e) => e.label).join('、');
  final avoidPart =
      reading.avoidHour != null ? '避開${reading.avoidHour}落大決定。' : '';
  return '今日${reading.ganzhiDay}日・命理分${reading.fortuneScore}・'
      '宜$yiPart，忌$jiPart。$avoidPart';
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/engine/copywriter_test.dart -v`
Expected: PASS (all tests, old and new).

- [ ] **Step 5: `flutter analyze` clean, full suite check**

Run: `flutter analyze` → `No issues found!`
Run: `flutter test` → PASS (report the real total count).

- [ ] **Step 6: Commit**

```bash
git add lib/engine/copywriter.dart test/engine/copywriter_test.dart
git commit -m "feat(widget): add buildNotificationText() short-form copywriter (spec §9.7)"
```

---

### Task 2: `WidgetDataBridge` — home_widget write path

**Files:**
- Create: `lib/services/widget_data_bridge.dart`
- Create: `test/services/widget_data_bridge_test.dart`

- [ ] **Step 1: Write the failing tests**

Create `test/services/widget_data_bridge_test.dart`:

```dart
import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:home_widget/home_widget.dart';
import 'package:xuanli/engine/copywriter.dart';
import 'package:xuanli/engine/profile_builder.dart';
import 'package:xuanli/services/widget_data_bridge.dart';

const _channel = MethodChannel('home_widget');

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    initMbtiTones(File('lib/data/mbti_tones.json').readAsStringSync());
  });

  void mockChannel(Future<dynamic> Function(MethodCall call) handler) {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_channel, handler);
  }

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_channel, null);
  });

  final profile = buildProfile(
    id: 'p1',
    name: '阿玄',
    birthDate: DateTime(1999, 9, 20),
    birthHour: 9,
    birthMinute: 30,
    birthPlace: '香港',
    mbti: 'ISFP',
  );

  group('WidgetDataBridge — 冇 platform channel implementation（呢部 Mac 嘅真實情況）', () {
    test('refreshNext7Days() 唔會 throw，靜靜完成（冇註冊 handler = MissingPluginException）', () async {
      final bridge = WidgetDataBridge();
      await bridge.refreshNext7Days(profile, today: DateTime(2026, 7, 11));
      // 冇 assertion 爆 = 冇 throw，就係呢個 test 想證明嘅嘢。
    });
  });

  group('WidgetDataBridge — mocked platform channel', () {
    test('refreshNext7Days() 傳 7 日 JSON 去 saveWidgetData，再 call updateWidget', () async {
      String? savedId;
      String? savedData;
      var updateWidgetCalled = false;

      mockChannel((call) async {
        switch (call.method) {
          case 'saveWidgetData':
            final args = call.arguments as Map;
            savedId = args['id'] as String;
            savedData = args['data'] as String;
            return true;
          case 'updateWidget':
            updateWidgetCalled = true;
            return true;
          default:
            return null;
        }
      });

      final bridge = WidgetDataBridge();
      await bridge.refreshNext7Days(profile, today: DateTime(2026, 7, 11));

      expect(savedId, isNotNull);
      expect(updateWidgetCalled, isTrue);

      final decoded = json.decode(savedData!) as List;
      expect(decoded.length, 7);

      final first = decoded.first as Map<String, dynamic>;
      expect(first['date'], '2026-07-11');
      expect(first['ganzhiDay'], '丙戌');
      expect(first['band'], isA<String>());
      expect(first['fortuneScore'], isA<int>());
      expect((first['yi'] as List).length, lessThanOrEqualTo(3));
      expect((first['ji'] as List).length, lessThanOrEqualTo(2));

      final last = decoded.last as Map<String, dynamic>;
      expect(last['date'], '2026-07-17'); // today + 6 days
    });

    test('saveWidgetData 失敗（channel throw）都唔會令成個 method 爆', () async {
      mockChannel((call) async {
        throw PlatformException(code: 'ERR', message: 'boom');
      });

      final bridge = WidgetDataBridge();
      // 唔應該 throw ——refreshNext7Days 係 best-effort background refresh，
      // native widget 側可能仲未存在（呢個 plan 冇起 native extension）。
      await bridge.refreshNext7Days(profile, today: DateTime(2026, 7, 11));
    });
  });
}
```

Check `lib/engine/profile_builder.dart` exports a `buildProfile(...)` helper matching this signature — it's already used by several other test files in this repo (`test/screens/calendar/calendar_screen_test.dart`, `test/screens/activity/activity_screen_test.dart` both use it), so this import/call shape should already be correct; read one of those files first to confirm the exact parameter names if anything above doesn't compile.

- [ ] **Step 2: Run tests to verify they fail**

Run: `flutter test test/services/widget_data_bridge_test.dart`
Expected: FAIL — `Error: Not found: 'package:xuanli/services/widget_data_bridge.dart'`.

- [ ] **Step 3: Write the implementation**

Create `lib/services/widget_data_bridge.dart`:

```dart
import 'dart:convert';

import 'package:home_widget/home_widget.dart';

import '../engine/day_reading_engine.dart';
import '../models/profile.dart';

/// 一日份、畀原生 widget render 用嘅精簡資料（spec §9.6：命理分/band/
/// 日期農曆/宜3忌2/避時），淨係包 [DayReading] 入面 widget 真係會顯示
/// 嘅欄位——advice/mbtiScore/clashWarning 呢啲 widget 冇顯示，唔會
/// 序列化，keep 個 JSON 細（widget 儲存空間有限）。
class WidgetDayPayload {
  final DateTime date;
  final String ganzhiDay;
  final String lunarLabel;
  final int fortuneScore;
  final String band;
  final List<String> yi;
  final List<String> ji;
  final String? avoidHour;

  const WidgetDayPayload({
    required this.date,
    required this.ganzhiDay,
    required this.lunarLabel,
    required this.fortuneScore,
    required this.band,
    required this.yi,
    required this.ji,
    required this.avoidHour,
  });

  /// 日期用 "yyyy-MM-dd"——同 spec §9.6 deep link 格式一致
  /// （`xuanli://day/2026-07-11`），原生 widget 撳落去可以直接攞嚟拼 URI。
  Map<String, dynamic> toJson() => {
        'date':
            '${date.year.toString().padLeft(4, '0')}-'
            '${date.month.toString().padLeft(2, '0')}-'
            '${date.day.toString().padLeft(2, '0')}',
        'ganzhiDay': ganzhiDay,
        'lunarLabel': lunarLabel,
        'fortuneScore': fortuneScore,
        'band': band,
        'yi': yi,
        'ji': ji,
        'avoidHour': avoidHour,
      };
}

/// 橋接 engine 同原生 home-screen widget（spec §9.6）。用 [HomeWidget]
/// package 寫入未來 7 日 [WidgetDayPayload] JSON。設計原則同
/// `CalendarSyncService`（Phase 2h）一致：淨係 best-effort background
/// refresh，就算 platform channel 冇註冊 implementation（呢個 plan
/// 未起native widget extension，本身就係而家嘅現實）都唔會 throw，
/// 唔應該因為呢個背景刷新失敗而累到成個 app 開唔到。
class WidgetDataBridge {
  static const _dataKey = 'xuanli_week_readings';

  // TODO(phase3b, 需要 Xcode/Android Studio 先起到 native widget):
  // 呢兩個名淨係 placeholder，要等真係起咗 iOS WidgetKit extension／
  // Android AppWidgetProvider 之後，改做嗰邊實際嘅 class/kind 名。
  static const _iOSWidgetName = 'XuanLiWidget';
  static const _androidWidgetName = 'XuanLiWidgetProvider';

  Future<void> refreshNext7Days(Profile profile, {DateTime? today}) async {
    try {
      final start = today ?? DateTime.now();
      final startDate = DateTime(start.year, start.month, start.day);
      final payloads = [
        for (var i = 0; i < 7; i++) _payloadFor(profile, startDate.add(Duration(days: i))),
      ];
      final jsonStr = json.encode(payloads.map((p) => p.toJson()).toList());

      await HomeWidget.saveWidgetData<String>(_dataKey, jsonStr);
      await HomeWidget.updateWidget(
        iOSName: _iOSWidgetName,
        androidName: _androidWidgetName,
      );
    } catch (_) {
      // Best-effort：native widget extension 未起（或者用戶部機冇 pin
      // 個 widget），呢個背景刷新失敗唔應該影響 app 其餘功能。
    }
  }

  WidgetDayPayload _payloadFor(Profile profile, DateTime date) {
    final reading = buildDayReading(profile: profile, date: date);
    return WidgetDayPayload(
      date: reading.date,
      ganzhiDay: reading.ganzhiDay,
      lunarLabel: reading.lunarLabel,
      fortuneScore: reading.fortuneScore,
      band: reading.band,
      yi: reading.yi.take(3).map((e) => e.label).toList(),
      ji: reading.ji.take(2).map((e) => e.label).toList(),
      avoidHour: reading.avoidHour,
    );
  }
}
```

**Important note if `buildDayReading`'s exact signature doesn't match `{required Profile profile, required DateTime date}`:** read `lib/engine/day_reading_engine.dart` first to confirm — it's used identically elsewhere (`lib/screens/calendar/calendar_screen.dart`, `lib/screens/today/today_screen.dart`) so this should already be correct, but verify before assuming.

- [ ] **Step 4: Run tests to verify they pass**

Run: `flutter test test/services/widget_data_bridge_test.dart -v`
Expected: PASS (all tests).

- [ ] **Step 5: `flutter analyze` clean, full suite check**

Run: `flutter analyze` → `No issues found!`
Run: `flutter test` → PASS (report the real total count).

- [ ] **Step 6: Commit**

```bash
git add lib/services/widget_data_bridge.dart test/services/widget_data_bridge_test.dart
git commit -m "feat(widget): add WidgetDataBridge wrapping home_widget (spec §9.6 write path)"
```

---

### Task 3: Wire `WidgetDataBridge` into app bootstrap

**Files:**
- Modify: `lib/main.dart`
- Modify: `test/widget_test.dart`

Per spec §9.6: "app 每次打開...用 home_widget 寫入未來 7 日 DayReading JSON".

- [ ] **Step 1: Write the failing test**

Read the current `test/widget_test.dart` first (it already has the theme-mode bootstrap test from Phase 2g — match its exact style, including the `rootBundle.clear()` `setUp()` workaround already documented there for cross-test asset-caching). Add these imports if not already present:

```dart
import 'package:flutter/services.dart';
import 'package:home_widget/home_widget.dart';
```

Add this new test:

```dart
  testWidgets(
      'XuanLiApp：有已存 profile 時，bootstrap 會觸發一次 widget data refresh（唔會等佢完先顯示 TabShell）',
      (tester) async {
    var saveWidgetDataCalled = false;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(const MethodChannel('home_widget'), (call) async {
      if (call.method == 'saveWidgetData') saveWidgetDataCalled = true;
      return true;
    });
    addTearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(const MethodChannel('home_widget'), null);
    });

    await StorageService().savePrimaryProfile(_sampleProfileForBootstrapTest());

    await tester.pumpWidget(const XuanLiApp());
    await tester.pump();
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 50));
    });
    await tester.pumpAndSettle();

    expect(find.byType(TabShell), findsOneWidget);
    expect(saveWidgetDataCalled, isTrue);
  });
```

You'll need a sample `Profile` to save — check whether `test/widget_test.dart` already has a helper for this (it may not, since prior tests in this file didn't need a real profile). If not, add a small local helper function near the top of the file (or reuse `buildProfile` from `package:xuanli/engine/profile_builder.dart` if that's already how other test files in this repo construct one — check `test/screens/calendar/calendar_screen_test.dart` for the pattern):

```dart
Profile _sampleProfileForBootstrapTest() => buildProfile(
      id: 'p1',
      name: '阿玄',
      birthDate: DateTime(1999, 9, 20),
      birthHour: 9,
      birthMinute: 30,
      birthPlace: '香港',
      mbti: 'ISFP',
    );
```

(Adjust the exact helper/import to match whatever this repo's established pattern actually is — you'll find it by reading a couple of the calendar/activity screen test files first.)

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/widget_test.dart`
Expected: FAIL — `saveWidgetDataCalled` stays `false` since nothing calls `WidgetDataBridge` yet.

- [ ] **Step 3: Write the implementation**

In `lib/main.dart`, read the current file first. Add the import:
```dart
import 'services/widget_data_bridge.dart';
```

Change `_AppBootstrapState._run()` from:
```dart
  Future<Profile?> _run() async {
    await loadEngineData();
    final settings = await StorageService().loadSettings();
    themeModeController.value = settings.themeMode;
    return StorageService().loadPrimaryProfile();
  }
```
to:
```dart
  Future<Profile?> _run() async {
    await loadEngineData();
    final settings = await StorageService().loadSettings();
    themeModeController.value = settings.themeMode;
    final profile = await StorageService().loadPrimaryProfile();
    if (profile != null) {
      // Fire-and-forget（唔 await）：widget 背景刷新唔應該延遲冷啟動
      // （spec §10 Phase 2 驗收：冷啟動 <2s）。WidgetDataBridge 本身
      // 內部已經 try/catch 晒，失敗唔會有未處理嘅 exception 冚出嚟。
      WidgetDataBridge().refreshNext7Days(profile);
    }
    return profile;
  }
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/widget_test.dart -v`
Expected: PASS (all tests in this file, old and new).

- [ ] **Step 5: `flutter analyze` clean, full suite check**

Run: `flutter analyze` → `No issues found!`
Run: `flutter test` → PASS (report the real total count).

Also re-run `test/screens/onboarding/onboarding_flow_test.dart` and `test/screens/tab_shell_test.dart` specifically — both exercise `_AppBootstrap`/full app-launch paths and are this project's recurring regression-risk files whenever bootstrap changes.

- [ ] **Step 6: Commit**

```bash
git add lib/main.dart test/widget_test.dart
git commit -m "feat(widget): refresh widget data on every app launch (spec §9.6)"
```

---

### Task 4: Docs + final verification

**Files:**
- Modify: `CHANGELOG.md`
- Modify: `CLAUDE.md`

- [ ] **Step 1: Update `CHANGELOG.md`**

Read the current `CHANGELOG.md` first (changes go at the **top**). Add a new entry summarizing: `buildNotificationText()` added (short-form copywriter per spec §9.7); `WidgetDataBridge` added (wraps already-present `home_widget`, no new package); wired into `main.dart` app-launch bootstrap, fire-and-forget so it can't slow cold start. Explicitly note the scope boundary: this is the Dart-side data-writing half of spec §9.6 only — no native iOS WidgetKit extension or Android AppWidgetProvider exists yet (blocked on Xcode/Android Studio, which Stephanie is installing separately), and notification scheduling (spec §9.7's delivery mechanism, `flutter_local_notifications`/`zonedSchedule`) is deliberately deferred to its own follow-up plan since it needs a different testing approach (Pigeon platform-interface, not a simple `MethodChannel` mock) and very likely a new `flutter_timezone` dependency for correct fire-time computation.

- [ ] **Step 2: Update `CLAUDE.md`'s Progress section**

Read the current `CLAUDE.md` first. Do **NOT** check off the `- [ ] Phase 3 Widget（iOS/Android 小+中）+ 每日通知` line — this plan is only a partial slice of Phase 3 (the Dart-side data bridge), not the whole phase (native widget UI + notification scheduling are still outstanding). Leave the checkbox unchecked; this step is a no-op unless you find something else in this section that's now stale and should be corrected — if so, fix only that, don't add new prose (narrative belongs in CHANGELOG.md per Step 1).

- [ ] **Step 3: Full verification sweep**

Run, in order, and report the real output of each:
```bash
flutter analyze
flutter test
dart test test/engine/
```
All three must be 100% green.

Also specifically re-run:
```bash
flutter test test/screens/onboarding/onboarding_flow_test.dart
flutter test test/screens/tab_shell_test.dart
flutter test test/widget_test.dart
```

- [ ] **Step 4: Commit**

```bash
git add CHANGELOG.md CLAUDE.md
git commit -m "docs: update CHANGELOG for Phase 3a widget data bridge"
```

Also `git add` this plan file itself (`docs/superpowers/plans/2026-07-29-xuanli-phase3a-widget-data-bridge.md`), following this project's established convention of committing plan files for completed work — include it in the same commit or a small follow-up one.

---

## Self-Review Notes

**Spec coverage:** covers the Dart-side write half of spec §9.6 exactly (compute + serialize next-7-days `DayReading` subset, write via `home_widget`, refresh on every launch) plus the `buildNotificationText()` short-form copywriter spec §9.7 names. Does NOT cover: native widget rendering (iOS/Android), the widget's own read-side/timeline logic, deep-link handling (`xuanli://day/...` — the JSON's `date` field is formatted ready for this, but no `home_widget`-side click/URI handling is wired since there's no native widget to click yet), or notification scheduling — all explicitly named as deferred, not silently gapped.

**No new packages:** `home_widget` already present, confirmed by reading `pubspec.yaml` before writing this plan. `pubspec.yaml`/`pubspec.lock` should be untouched by every task.

**Testability:** every new code path in `WidgetDataBridge` is covered by a mocked-`MethodChannel('home_widget')` test (success path, save-failure-doesn't-throw path) plus a no-mock test proving the "native widget doesn't exist yet" reality (this Mac's actual state) doesn't crash anything — same verification discipline Phase 2h established for `device_calendar`.

**Placeholder scan:** every step has complete, literal code. The two `TODO(phase3b, ...)` constants in `widget_data_bridge.dart` are intentional, clearly-labeled forward-references to real future work (native widget naming), not vague/unfinished logic — they don't affect what THIS plan's tests verify.

**Type consistency:** `WidgetDayPayload`'s fields/`toJson()` match `DayReading`'s corresponding fields exactly at every reference (`WidgetDataBridge._payloadFor`, the JSON assertions in `widget_data_bridge_test.dart`). `buildNotificationText(DayReading)`'s signature is used identically in its own test file (Task 1) — no other call site exists yet in this plan (widget/notification wiring that will eventually call it is out of scope here).
