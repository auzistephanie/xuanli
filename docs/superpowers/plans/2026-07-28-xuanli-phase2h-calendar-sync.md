# XuanLi Phase 2h — 日曆整合 (calendar_sync) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build spec §9.9's `services/calendar_sync.dart` — real `device_calendar` permission/read/write integration — and wire it into Tab C's month grid + day card (read: event dot + "📅 你嘅行程" list) and Tab B's top result card (write: "＋ 加入我嘅日曆"; "當日行程 ›" reuses the same read path for a single day). This replaces every remaining `之後 sub-plan 起` / `之後有 device 先驗證` calendar stub in the codebase and closes out spec §10 Phase 2's `Tab A/B/C 全功能（含日曆讀寫）` checklist item.

**Architecture:** One new service, `CalendarSyncService`, wraps `DeviceCalendarPlugin` (already a dependency — `device_calendar: ^4.3.0` in `pubspec.yaml`, unused until now). It exposes four methods: `hasPermission()` (silent check, no dialog), `requestPermission()` (idempotent — checks first, only prompts if not already granted), `addAllDayEvent(...)` (write, self-contained permission handling since it's triggered by an explicit user tap), and `eventsInRange(...)`/`eventsOnDay(...)` (read, silently returns `[]` without prompting if permission isn't granted — Tab C's screen is responsible for requesting permission exactly once, on first mount). All four degrade gracefully (return `false`/`[]`, never throw) when the platform channel has no registered implementation — which is always true in `flutter test` on this Mac (no device/simulator), and is also `device_calendar`'s own built-in behavior for any real `PlatformException`. `CalendarScreen`/`ActivityScreen` each hold one `CalendarSyncService` instance in their `State`.

**Tech Stack:** `device_calendar` (already in `pubspec.yaml`, not yet used anywhere — this plan adds no new packages). Tests use `TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(DeviceCalendarPlugin.channel, ...)` to simulate the platform channel — this is the standard Flutter technique for testing plugin consumers without a real device, and it's what "stub verified paths, real device behavior unverified until tested on a real device/simulator" means for this plan.

---

## Scope decisions (confirmed with Stephanie before starting — don't re-litigate)

1. **Building this now, with mocked-channel unit/widget tests only.** True on-device behavior (real permission dialogs, real calendar app writes) cannot be verified on this Mac (no simulator/emulator) — same limitation this project has hit for every device-dependent feature so far (JSON export/import stubs, widget/notification work). This plan produces real, correct integration code and tests every reachable code path via a mocked platform channel; a human must still smoke-test on a real device before shipping.
2. **Read merges events across ALL the user's calendars** (not just the default one) — `retrieveEvents` requires a specific `calendarId` per call (verified by reading the installed package source, `device_calendar-4.3.3/lib/src/device_calendar.dart`), so "read my events this month" means: list calendars, query each, merge, sort by start time. Write targets only the default calendar (or the first non-read-only one if there's no explicit default) — writing to multiple calendars for one add-to-calendar tap would be nonsensical.
3. **Tab C's permission request fires on `CalendarScreen`'s first mount, not strictly on first tab *selection*.** Spec §9.9 says "首次入 Tab C 先問權限" (ask on first entry to Tab C). `TabShell`'s `IndexedStack` (an existing, established architecture from Phase 2c–2e, not something this plan changes) builds all 3 tab screens eagerly at once, so `CalendarScreen.initState()` already runs once, right after onboarding/app-launch, regardless of which tab is visually selected first. Making the request fire only on true first-visible-selection would require threading an `isActive` flag through `TabShell` — a lazy-tab-loading change out of scope for a calendar-integration plan. This is a documented, deliberate trim, not a silent deviation.
4. **Tab B's "加入我嘅日曆" is an explicit user action, so it is NOT silent on permission denial** (unlike Tab C's passive, silent-hide read UI). Tapping it triggers `requestPermission()` if not already granted; if the user declines (or there's no writable calendar), a `SnackBar` explains why nothing happened. Spec's "拒絕 → 行程功能靜默隱藏（唔好嘈）" language is specifically about Tab C's passive display, not an explicit write action a user just tapped — staying silent after an explicit tap would look broken, not polite.
5. **Event title has no per-activity emoji/icon table.** Spec §9.9's example ("✂ 剪髮（玄曆吉日）") uses ✂ only as an illustrative icon for the 剪髮 activity specifically — `lib/data/activities.json` and the design html have no general activity→icon mapping. Building one would be inventing scope. Event titles are `'${activity.name}（玄曆吉日）'` for all activities.
6. **Tab B's "當日行程 ›" button reuses the same read path as Tab C** (`CalendarSyncService.eventsOnDay`), shown in a simple `AlertDialog` (time + title lines, or an explanatory message if empty/no permission) — not a new bespoke screen. This wasn't explicitly in spec §9.9's bullet list, but the button already exists in the shipped UI (added as a stub in an earlier phase) and needs *some* real behavior now; reusing the read capability that Tab C already needs is the smallest correct answer, not new scope.

---

## File Structure

```
xuanli/
└── lib/
    ├── services/
    │   └── calendar_sync.dart              # NEW — CalendarSyncService, CalendarSyncEvent
    ├── screens/
    │   ├── calendar/
    │   │   ├── calendar_screen.dart        # MODIFY — request permission once, load month + day events
    │   │   └── calendar_widgets.dart       # MODIFY — DayCard gets calendarAvailable + eventLines
    │   └── activity/
    │       ├── activity_screen.dart        # MODIFY — wire add-to-calendar + day-schedule dialog
    │       └── activity_widgets.dart       # MODIFY — ResultCard gets onAddToCalendar/onViewSchedule
└── test/
    ├── services/
    │   └── calendar_sync_test.dart         # NEW
    ├── screens/
    │   ├── calendar/
    │   │   ├── calendar_screen_test.dart   # MODIFY
    │   │   └── calendar_widgets_test.dart  # MODIFY
    │   └── activity/
    │       ├── activity_screen_test.dart   # MODIFY
    │       └── activity_widgets_test.dart  # MODIFY
```

---

### Task 1: `lib/services/calendar_sync.dart` — `CalendarSyncService`

**Files:**
- Create: `lib/services/calendar_sync.dart`
- Create: `test/services/calendar_sync_test.dart`

- [ ] **Step 1: Write the failing tests**

Create `test/services/calendar_sync_test.dart`:

```dart
import 'dart:convert';

import 'package:device_calendar/device_calendar.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xuanli/services/calendar_sync.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  void mockChannel(Future<dynamic> Function(MethodCall call) handler) {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(DeviceCalendarPlugin.channel, handler);
  }

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(DeviceCalendarPlugin.channel, null);
  });

  group('CalendarSyncService — permission (no channel mock, matches real dev-machine behavior)', () {
    test('hasPermission() 喺冇 platform channel implementation 嗰陣（好似呢部 Mac 冇 simulator）靜靜返 false', () async {
      final service = CalendarSyncService();
      expect(await service.hasPermission(), isFalse);
    });

    test('requestPermission() 同樣情況靜靜返 false，唔會 throw', () async {
      final service = CalendarSyncService();
      expect(await service.requestPermission(), isFalse);
    });
  });

  group('CalendarSyncService — permission (mocked channel)', () {
    test('hasPermission()/requestPermission() 兩者權限已批 → true', () async {
      mockChannel((call) async {
        if (call.method == 'hasPermissions' || call.method == 'requestPermissions') {
          return true;
        }
        return null;
      });

      final service = CalendarSyncService();
      expect(await service.hasPermission(), isTrue);
      expect(await service.requestPermission(), isTrue);
    });

    test('requestPermission() 已經有權限就唔會再 call requestPermissions channel method', () async {
      var requestPermissionsCalls = 0;
      mockChannel((call) async {
        if (call.method == 'hasPermissions') return true;
        if (call.method == 'requestPermissions') {
          requestPermissionsCalls++;
          return true;
        }
        return null;
      });

      final service = CalendarSyncService();
      await service.requestPermission();
      expect(requestPermissionsCalls, 0);
    });

    test('requestPermission() 冇權限、用戶拒絕 → false', () async {
      mockChannel((call) async {
        if (call.method == 'hasPermissions') return false;
        if (call.method == 'requestPermissions') return false;
        return null;
      });

      final service = CalendarSyncService();
      expect(await service.requestPermission(), isFalse);
    });
  });

  group('CalendarSyncService — addAllDayEvent (write)', () {
    test('冇權限 → 唔會建 event，返 false', () async {
      mockChannel((call) async {
        if (call.method == 'hasPermissions' || call.method == 'requestPermissions') {
          return false;
        }
        return null;
      });

      final service = CalendarSyncService();
      final ok = await service.addAllDayEvent(
        date: DateTime(2026, 7, 20),
        title: '剪髮（玄曆吉日）',
        description: '🔮 測試',
      );

      expect(ok, isFalse);
    });

    test('有權限、冇任何可寫日曆 → 返 false', () async {
      mockChannel((call) async {
        if (call.method == 'hasPermissions') return true;
        if (call.method == 'retrieveCalendars') {
          return json.encode([
            {'id': 'ro1', 'name': 'Readonly', 'isReadOnly': true, 'isDefault': false},
          ]);
        }
        return null;
      });

      final service = CalendarSyncService();
      final ok = await service.addAllDayEvent(
        date: DateTime(2026, 7, 20),
        title: '剪髮（玄曆吉日）',
        description: '🔮 測試',
      );

      expect(ok, isFalse);
    });

    test('有權限、有可寫日曆 → 揀 default calendar，建全日 event，傳啱標題/描述/日期', () async {
      Map<dynamic, dynamic>? sentArgs;
      mockChannel((call) async {
        if (call.method == 'hasPermissions') return true;
        if (call.method == 'retrieveCalendars') {
          return json.encode([
            {'id': 'personal', 'name': 'Personal', 'isReadOnly': false, 'isDefault': false},
            {'id': 'work', 'name': 'Work', 'isReadOnly': false, 'isDefault': true},
          ]);
        }
        if (call.method == 'createOrUpdateEvent') {
          sentArgs = call.arguments as Map<dynamic, dynamic>;
          return 'new-event-id';
        }
        return null;
      });

      final service = CalendarSyncService();
      final ok = await service.addAllDayEvent(
        date: DateTime(2026, 7, 20),
        title: '剪髮（玄曆吉日）',
        description: '🔮 通勝宜理髮',
      );

      expect(ok, isTrue);
      expect(sentArgs, isNotNull);
      expect(sentArgs!['calendarId'], 'work'); // 揀咗 isDefault=true 嗰個，唔係第一個
      expect(sentArgs!['eventTitle'], '剪髮（玄曆吉日）');
      expect(sentArgs!['eventDescription'], '🔮 通勝宜理髮');
      expect(sentArgs!['eventAllDay'], isTrue);

      // `sentArgs` 係 device_calendar package 真正嘅 `createOrUpdateEvent`
      // 對 [Event] 做完內部「歸位去午夜」處理之後先傳去 mock channel
      // 嗰個 map（呢個 test 淨係 mock 咗 platform channel 嗰層，冇 mock
      // package 自己嘅 Dart 前處理），所以 `eventStartDate` 呢個斷言
      // 會真係行過 package 嗰段用 host 系統 local time 重新起 UTC
      // instant 嘅邏輯。呢個 instant 代表緊「呢部跑緊 test 嘅機器噚下
      // 自己個 local time 嘅 2026-07-20 00:00」，所以要跟返同一個
      // host-local 解讀方式去計「應該係乜嘢」，唔可以假設任何固定
      // 嘅 UTC offset（唔同機器/CI 跑呢個 test 會有唔同、但一樣啱嘅
      // 結果）。
      final expectedStartMs =
          DateTime(2026, 7, 20, 0, 0, 0).toUtc().millisecondsSinceEpoch;
      expect(sentArgs!['eventStartDate'], expectedStartMs);
    });

    test('有權限、有可寫日曆、但冇 default → 揀第一個可寫嘅', () async {
      Map<dynamic, dynamic>? sentArgs;
      mockChannel((call) async {
        if (call.method == 'hasPermissions') return true;
        if (call.method == 'retrieveCalendars') {
          return json.encode([
            {'id': 'ro1', 'name': 'Readonly', 'isReadOnly': true, 'isDefault': false},
            {'id': 'personal', 'name': 'Personal', 'isReadOnly': false, 'isDefault': false},
          ]);
        }
        if (call.method == 'createOrUpdateEvent') {
          sentArgs = call.arguments as Map<dynamic, dynamic>;
          return 'new-event-id';
        }
        return null;
      });

      final service = CalendarSyncService();
      final ok = await service.addAllDayEvent(
        date: DateTime(2026, 7, 20),
        title: '剪髮（玄曆吉日）',
        description: '🔮 測試',
      );

      expect(ok, isTrue);
      expect(sentArgs!['calendarId'], 'personal');
    });
  });

  group('CalendarSyncService — eventsInRange/eventsOnDay (read)', () {
    test('冇權限 → 靜靜返 []，唔會嘗試彈權限對話框（唔會 call requestPermissions）', () async {
      var requestPermissionsCalls = 0;
      mockChannel((call) async {
        if (call.method == 'hasPermissions') return false;
        if (call.method == 'requestPermissions') {
          requestPermissionsCalls++;
          return true;
        }
        return null;
      });

      final service = CalendarSyncService();
      final events = await service.eventsInRange(
        start: DateTime(2026, 7, 1),
        end: DateTime(2026, 8, 1),
      );

      expect(events, isEmpty);
      expect(requestPermissionsCalls, 0);
    });

    test('有權限、跨兩個 calendar 嘅 events 會合埋一齊，按開始時間排序', () async {
      mockChannel((call) async {
        if (call.method == 'hasPermissions') return true;
        if (call.method == 'retrieveCalendars') {
          return json.encode([
            {'id': 'personal', 'name': 'Personal', 'isReadOnly': false, 'isDefault': true},
            {'id': 'work', 'name': 'Work', 'isReadOnly': false, 'isDefault': false},
          ]);
        }
        if (call.method == 'retrieveEvents') {
          final calendarId = (call.arguments as Map)['calendarId'];
          if (calendarId == 'personal') {
            return json.encode([
              {
                'eventId': 'e1',
                'calendarId': 'personal',
                'eventTitle': '晚飯',
                'eventStartDate':
                    DateTime.utc(2026, 7, 16, 19, 0).millisecondsSinceEpoch,
                'eventEndDate':
                    DateTime.utc(2026, 7, 16, 20, 0).millisecondsSinceEpoch,
                'eventAllDay': false,
              },
            ]);
          }
          if (calendarId == 'work') {
            return json.encode([
              {
                'eventId': 'e2',
                'calendarId': 'work',
                'eventTitle': '早會',
                'eventStartDate':
                    DateTime.utc(2026, 7, 16, 9, 0).millisecondsSinceEpoch,
                'eventEndDate':
                    DateTime.utc(2026, 7, 16, 9, 30).millisecondsSinceEpoch,
                'eventAllDay': false,
              },
            ]);
          }
          return json.encode([]);
        }
        return null;
      });

      final service = CalendarSyncService();
      final events = await service.eventsInRange(
        start: DateTime(2026, 7, 1),
        end: DateTime(2026, 8, 1),
      );

      expect(events.length, 2);
      // 早會 (9:00) 排喺 晚飯 (19:00) 前面，就算 work calendar 喺 API
      // response 入面排第二。
      expect(events[0].title, '早會');
      expect(events[1].title, '晚飯');
    });

    test('eventsOnDay() 傳一個 [day, day+1) 嘅範圍去 retrieveEvents', () async {
      DateTime? sentStart;
      DateTime? sentEnd;
      mockChannel((call) async {
        if (call.method == 'hasPermissions') return true;
        if (call.method == 'retrieveCalendars') {
          return json.encode([
            {'id': 'personal', 'name': 'Personal', 'isReadOnly': false, 'isDefault': true},
          ]);
        }
        if (call.method == 'retrieveEvents') {
          final args = call.arguments as Map;
          sentStart =
              DateTime.fromMillisecondsSinceEpoch(args['startDate'] as int);
          sentEnd = DateTime.fromMillisecondsSinceEpoch(args['endDate'] as int);
          return json.encode([]);
        }
        return null;
      });

      final service = CalendarSyncService();
      await service.eventsOnDay(DateTime(2026, 7, 16, 15, 30));

      expect(sentStart, DateTime(2026, 7, 16));
      expect(sentEnd, DateTime(2026, 7, 17));
    });
  });
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `flutter test test/services/calendar_sync_test.dart`
Expected: FAIL — `Error: Not found: 'package:xuanli/services/calendar_sync.dart'`.

- [ ] **Step 3: Write the implementation**

Create `lib/services/calendar_sync.dart`:

```dart
import 'package:device_calendar/device_calendar.dart';

/// 一個日曆事件嘅精簡顯示資料（時間+標題）。Tab B「當日行程」／Tab C
/// 日卡共用呢個型別；原始 [Event]（device_calendar 嘅型別）唔直接
/// 外露畀 UI，減少 screen 層對 device_calendar package 嘅耦合。
class CalendarSyncEvent {
  final String title;
  final DateTime start;

  const CalendarSyncEvent({required this.title, required this.start});
}

/// 包裝 device_calendar 嘅權限/讀/寫（spec §9.9）。設計原則：就算冇
/// 權限、冇日曆、或者部機根本冇 platform channel implementation（呢個
/// repo 開發用嘅 Mac 冇 simulator/device，`flutter test` 環境本身就係
/// 呢個情況），都唔會 throw——一律靜靜返 false/[]，等 UI 決定點顯示
/// （Tab C 拒絕權限＝整個行程功能靜默隱藏，唔嘈）。
class CalendarSyncService {
  final DeviceCalendarPlugin _plugin;

  CalendarSyncService({DeviceCalendarPlugin? plugin})
      : _plugin = plugin ?? DeviceCalendarPlugin();

  /// 淨係查詢現有權限狀態，唔會彈系統權限對話框——畀 Tab C 每次
  /// 讀月曆/揀日都用嘅「靜默檢查」，唔應該重複問用戶。
  Future<bool> hasPermission() async {
    final result = await _plugin.hasPermissions();
    return result.isSuccess && (result.data ?? false);
  }

  /// 主動問用戶攞權限（已經有就唔會再彈）。呢個先應該喺明確嘅用戶
  /// 動作／畫面首次進入嗰陣觸發（Tab C 首次入、Tab B 撳加入日曆），
  /// 唔好周圍隨便 call。
  Future<bool> requestPermission() async {
    if (await hasPermission()) return true;
    final result = await _plugin.requestPermissions();
    return result.isSuccess && (result.data ?? false);
  }

  Future<String?> _defaultWritableCalendarId() async {
    final result = await _plugin.retrieveCalendars();
    if (!result.isSuccess || result.data == null) return null;

    final writable = result.data!.where((c) => c.isReadOnly != true).toList();
    if (writable.isEmpty) return null;

    for (final calendar in writable) {
      if (calendar.isDefault == true) return calendar.id;
    }
    return writable.first.id;
  }

  /// 建一個全日 event（spec §9.9 寫：Tab B 加入日曆）。冇權限會先問
  /// 一次；用戶拒絕，或者部機根本冇任何可寫日曆，就返 false，等
  /// 呼叫方（畫面）顯示合適提示。
  ///
  /// [date] 淨係用嚟起 [TZDateTime] 嘅年月日欄位；[Event.allDay]=true
  /// 嗰陣 device_calendar 自己（`assertParameters`）會攞呢啲年月日
  /// 欄位、用 host 機器嘅系統 local time 重新起一個 UTC instant 先
  /// 傳去 platform channel——即係話：淨係嗰個 y/m/d 數值本身有意義，
  /// 用邊個 [Location] 起呢個 [TZDateTime]（呢度用 [UTC] 純粹貪方便）
  /// 對最終傳出去嘅 epoch 完全冇影響（`TZDateTime.from(other, loc)`
  /// 係 instant-preserving，`loc` 淨係影響之後讀 `.year`/`.month`/
  /// `.day` getter 用邊個 offset 顯示，唔會改變已經算好嘅 UTC
  /// instant）。呢個 UTC instant 代表緊「呢部裝住 app 嘅機噚下自己個
  /// local time 嘅午夜」——即係話喺真機（app 同睇返個 calendar 都係
  /// 同一部機、同一個 timezone）度睇，個 event 一定啱啱好落喺用戶
  /// 想要嗰一日，唔使額外處理。（起呢個 plan 嗰陣一開始以為要額外
  /// 起個 fixed-offset `Location`先啱，落手做嗰陣先發現係諗錯咗
  /// `TZDateTime.from` 嘅語義——已經用返呢個簡單版本。）
  Future<bool> addAllDayEvent({
    required DateTime date,
    required String title,
    required String description,
  }) async {
    if (!await requestPermission()) return false;

    final calendarId = await _defaultWritableCalendarId();
    if (calendarId == null) return false;

    final day = TZDateTime(UTC, date.year, date.month, date.day);
    final event = Event(
      calendarId,
      title: title,
      description: description,
      start: day,
      end: day,
      allDay: true,
    );

    final result = await _plugin.createOrUpdateEvent(event);
    return result != null && result.isSuccess;
  }

  /// 讀返 `[start, end)` 範圍入面、用戶全部日曆合埋一齊嘅 events，
  /// 跨 calendar 合併＋按開始時間排序。冇權限就靜靜返 []（唔會嘗試
  /// 彈權限對話框——權限請求由畫面自己喺首次進入嗰陣觸發一次，呢個
  /// method 只讀唔問）。
  Future<List<CalendarSyncEvent>> eventsInRange({
    required DateTime start,
    required DateTime end,
  }) async {
    if (!await hasPermission()) return [];

    final calendarsResult = await _plugin.retrieveCalendars();
    if (!calendarsResult.isSuccess || calendarsResult.data == null) return [];

    final events = <CalendarSyncEvent>[];
    for (final calendar in calendarsResult.data!) {
      if (calendar.id == null) continue;
      final eventsResult = await _plugin.retrieveEvents(
        calendar.id,
        RetrieveEventsParams(startDate: start, endDate: end),
      );
      if (!eventsResult.isSuccess || eventsResult.data == null) continue;

      for (final event in eventsResult.data!) {
        if (event.start == null || event.title == null) continue;
        events.add(CalendarSyncEvent(title: event.title!, start: event.start!));
      }
    }

    events.sort((a, b) => a.start.compareTo(b.start));
    return events;
  }

  /// [eventsInRange] 嘅單日方便版本——Tab B「當日行程」／Tab C 日卡
  /// 共用（DRY：兩邊都係「畀我呢一日嘅 events」，唔應該各自寫一份）。
  Future<List<CalendarSyncEvent>> eventsOnDay(DateTime date) {
    final dayStart = DateTime(date.year, date.month, date.day);
    return eventsInRange(
      start: dayStart,
      end: dayStart.add(const Duration(days: 1)),
    );
  }
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `flutter test test/services/calendar_sync_test.dart -v`
Expected: PASS (all tests).

- [ ] **Step 5: `flutter analyze` clean, full suite check**

Run: `flutter analyze` → `No issues found!`
Run: `flutter test` → PASS (report the real total count you observe — should be the pre-existing count plus this task's new tests, nothing else should change since nothing else imports this new file yet).

- [ ] **Step 6: Commit**

```bash
git add lib/services/calendar_sync.dart test/services/calendar_sync_test.dart
git commit -m "feat(calendar): add CalendarSyncService wrapping device_calendar (permission/read/write)"
```

---

### Task 2: Wire Tab C — real calendar read in `CalendarScreen`/`CalendarGrid`/`DayCard`

**Files:**
- Modify: `lib/screens/calendar/calendar_screen.dart`
- Modify: `lib/screens/calendar/calendar_widgets.dart`
- Modify: `test/screens/calendar/calendar_screen_test.dart`
- Modify: `test/screens/calendar/calendar_widgets_test.dart`

Per spec §9.9: 首次入 Tab C 問權限（拒絕就行程功能靜默隱藏）；讀當月 events → 格仔幼條（已有嘅 `hasEvents` 顯示邏輯，之前永遠 false，而家要接返真數據）+ 日卡列表（時間+標題，最多 5 項）。

- [ ] **Step 1: Write the failing tests**

Read the current `test/screens/calendar/calendar_widgets_test.dart` first (its `DayCard` group asserts `find.textContaining('行事曆整合')` — that hardcoded stub line is being removed this task, so this existing assertion must change, not just gain new tests). Replace the entire `group('DayCard', ...)` block with:

```dart
  group('DayCard', () {
    testWidgets('顯示日期/分數/副標題/宜忌，calendarAvailable 預設 false 就完全唔顯示行程 section', (tester) async {
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
      // 冇日曆權限（或者未查）：成個「你嘅行程」section 靜默隱藏，
      // 唔會顯示任何行程相關文字。
      expect(find.textContaining('你嘅行程'), findsNothing);
    });

    testWidgets('calendarAvailable=true、eventLines 空 → 顯示「今日冇行程」', (tester) async {
      await tester.pumpWidget(wrap(const DayCard(
        dateLabel: '7月16日（四）辛卯日',
        band: '吉',
        score: 88,
        subtitleLine: '六月初三・成日・沖雞煞西',
        yiLine: '嫁娶・祈福・剪髮',
        jiLine: '伐木・掘井',
        calendarAvailable: true,
        eventLines: [],
      )));

      expect(find.textContaining('你嘅行程'), findsOneWidget);
      expect(find.text('今日冇行程'), findsOneWidget);
    });

    testWidgets('calendarAvailable=true、有 eventLines → 逐條顯示（最多 5 條）', (tester) async {
      await tester.pumpWidget(wrap(const DayCard(
        dateLabel: '7月16日（四）辛卯日',
        band: '吉',
        score: 88,
        subtitleLine: '六月初三・成日・沖雞煞西',
        yiLine: '嫁娶・祈福・剪髮',
        jiLine: '伐木・掘井',
        calendarAvailable: true,
        eventLines: ['09:00 早會', '14:30 剪髮'],
      )));

      expect(find.text('09:00 早會'), findsOneWidget);
      expect(find.text('14:30 剪髮'), findsOneWidget);
      expect(find.text('今日冇行程'), findsNothing);
    });

    testWidgets('band 忌 嘅分數 chip 用 red，同 吉 唔同色', (tester) async {
      await tester.pumpWidget(wrap(const DayCard(
        dateLabel: '7月17日（五）壬辰日',
        band: '忌',
        score: 32,
        subtitleLine: '六月初四・破日・沖狗煞南',
        yiLine: '無',
        jiLine: '嫁娶・出行',
      )));

      final colors = XuanLiTheme.light().extension<XuanLiColors>()!;

      final chipContainer = tester.widget<Container>(
        find.ancestor(
          of: find.text('忌 32'),
          matching: find.byType(Container),
        ).first,
      );
      final chipColor = (chipContainer.decoration as BoxDecoration).color;

      expect(chipColor, colors.red.withValues(alpha: 0.14));
      expect(chipColor, isNot(colors.jade.withValues(alpha: 0.14)));
    });

    testWidgets('band 平 嘅分數 chip 用 ink60，同 吉/忌 唔同色', (tester) async {
      await tester.pumpWidget(wrap(const DayCard(
        dateLabel: '7月18日（六）癸巳日',
        band: '平',
        score: 58,
        subtitleLine: '六月初五・平日・沖豬煞東',
        yiLine: '祈福',
        jiLine: '安葬',
      )));

      final colors = XuanLiTheme.light().extension<XuanLiColors>()!;

      final chipContainer = tester.widget<Container>(
        find.ancestor(
          of: find.text('平 58'),
          matching: find.byType(Container),
        ).first,
      );
      final chipColor = (chipContainer.decoration as BoxDecoration).color;

      expect(chipColor, colors.ink60.withValues(alpha: 0.14));
      expect(chipColor, isNot(colors.jade.withValues(alpha: 0.14)));
      expect(chipColor, isNot(colors.red.withValues(alpha: 0.14)));
    });
  });
```

(Leave the `group('CalendarGrid', ...)` block above it completely untouched — the grid's `hasEvents`-per-cell rendering already exists and already has full test coverage; this task only changes where the `hasEvents` boolean value *comes from*, not how `CalendarGrid` renders it.)

Now read the current `test/screens/calendar/calendar_screen_test.dart` first, then add these imports at the top alongside the existing ones:

```dart
import 'dart:convert';

import 'package:device_calendar/device_calendar.dart';
```

Add this new test at the end of `main()`, inside the existing test file (keep every existing test in this file exactly as-is — they exercise the "no calendar permission" path, which is what actually happens in this test environment since there's no platform channel implementation registered by default, so they need no changes):

```dart
  group('CalendarScreen — device_calendar 整合（mocked platform channel）', () {
    tearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(DeviceCalendarPlugin.channel, null);
    });

    testWidgets('有權限＋7月16日有 event：格仔顯示行程橫條，撳開日卡顯示行程列表', (tester) async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(DeviceCalendarPlugin.channel, (call) async {
        switch (call.method) {
          case 'hasPermissions':
          case 'requestPermissions':
            return true;
          case 'retrieveCalendars':
            return json.encode([
              {'id': 'cal1', 'name': 'Personal', 'isReadOnly': false, 'isDefault': true},
            ]);
          case 'retrieveEvents':
            return json.encode([
              {
                'eventId': 'e1',
                'calendarId': 'cal1',
                'eventTitle': '午餐會議',
                'eventStartDate':
                    DateTime.utc(2026, 7, 16, 14, 30).millisecondsSinceEpoch,
                'eventEndDate':
                    DateTime.utc(2026, 7, 16, 15, 30).millisecondsSinceEpoch,
                'eventAllDay': false,
              },
            ]);
          default:
            return null;
        }
      });

      await tester.pumpWidget(wrap(CalendarScreen(
        profile: profile,
        today: DateTime(2026, 7, 11),
      )));
      await tester.pumpAndSettle();

      await tester.tap(find.text('16'));
      await tester.pumpAndSettle();

      expect(find.textContaining('你嘅行程'), findsOneWidget);
      expect(find.text('14:30 午餐會議'), findsOneWidget);
    });

    testWidgets('冇日曆權限：日卡完全冇「你嘅行程」section（同冇 mock 嘅預設情況一致）', (tester) async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(DeviceCalendarPlugin.channel, (call) async {
        if (call.method == 'hasPermissions' || call.method == 'requestPermissions') {
          return false;
        }
        return null;
      });

      await tester.pumpWidget(wrap(CalendarScreen(
        profile: profile,
        today: DateTime(2026, 7, 11),
      )));
      await tester.pumpAndSettle();

      expect(find.textContaining('你嘅行程'), findsNothing);
    });
  });
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `flutter test test/screens/calendar/calendar_widgets_test.dart test/screens/calendar/calendar_screen_test.dart -v`
Expected: FAIL — `DayCard` doesn't have `calendarAvailable`/`eventLines` params yet, so the widgets test won't compile; the screen test's new group fails because `CalendarScreen` never calls `device_calendar` yet, so no mocked calls happen and nothing renders.

- [ ] **Step 3: Write the implementation**

In `lib/screens/calendar/calendar_widgets.dart`, read the current file first. Modify the `DayCard` class: add two new fields with defaults, and replace the hardcoded stub `Container` at the bottom of `build()` with a conditional real one.

Change the `DayCard` class fields/constructor from:
```dart
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
```
to:
```dart
class DayCard extends StatelessWidget {
  final String dateLabel;
  final String band;
  final int score;
  final String subtitleLine;
  final String yiLine;
  final String jiLine;
  final bool calendarAvailable; // false＝日曆權限未批（或者未查完）：成個行程 section 靜默隱藏（spec §9.9）
  final List<String> eventLines; // 已格式化 "HH:mm 標題"，最多 5 條，calendarAvailable=false 時唔會用到

  const DayCard({
    super.key,
    required this.dateLabel,
    required this.band,
    required this.score,
    required this.subtitleLine,
    required this.yiLine,
    required this.jiLine,
    this.calendarAvailable = false,
    this.eventLines = const [],
  });
```

Change the bottom of `build()` from:
```dart
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
to:
```dart
          if (calendarAvailable)
            Container(
              margin: const EdgeInsets.only(top: 8),
              padding: const EdgeInsets.only(top: 8),
              decoration: BoxDecoration(border: Border(top: BorderSide(color: colors.ink12))),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '📅 你嘅行程',
                    style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: colors.ink60),
                  ),
                  const SizedBox(height: 3),
                  if (eventLines.isEmpty)
                    Text('今日冇行程', style: TextStyle(fontSize: 11.5, color: colors.ink30))
                  else
                    for (final line in eventLines.take(5))
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(line, style: TextStyle(fontSize: 11.5, color: colors.ink)),
                      ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
```

In `lib/screens/calendar/calendar_screen.dart`, read the current file first. Add imports:
```dart
import '../../services/calendar_sync.dart';
```

Add state fields and lifecycle/loading methods to `_CalendarScreenState`. Change:
```dart
class _CalendarScreenState extends State<CalendarScreen> {
  static const _weekdayHeaders = ['日', '一', '二', '三', '四', '五', '六'];
  static final _minMonth = DateTime(1900, 1);
  static final _maxMonth = DateTime(2100, 12);

  late DateTime _displayedMonth;
  int? _selectedDay;
```
to:
```dart
class _CalendarScreenState extends State<CalendarScreen> {
  static const _weekdayHeaders = ['日', '一', '二', '三', '四', '五', '六'];
  static final _minMonth = DateTime(1900, 1);
  static final _maxMonth = DateTime(2100, 12);

  final _calendarSync = CalendarSyncService();

  late DateTime _displayedMonth;
  int? _selectedDay;
  bool _calendarAvailable = false;
  Set<int> _daysWithEventsInDisplayedMonth = {};
  List<CalendarSyncEvent> _selectedDayEvents = [];
```

Change `initState()` from:
```dart
  @override
  void initState() {
    super.initState();
    final today = _today;
    _displayedMonth = DateTime(today.year, today.month);
    _selectedDay = today.day;
  }
```
to:
```dart
  @override
  void initState() {
    super.initState();
    final today = _today;
    _displayedMonth = DateTime(today.year, today.month);
    _selectedDay = today.day;
    _initCalendarSync();
  }

  /// spec §9.9：「首次入 Tab C 先問權限」。呢個先係整個畫面入面
  /// 唯一一次真係彈權限對話框嘅地方——之後 [_loadMonthEvents]／
  /// [_loadSelectedDayEvents] 淨係讀，唔會再問。
  Future<void> _initCalendarSync() async {
    final granted = await _calendarSync.requestPermission();
    if (!mounted) return;
    setState(() => _calendarAvailable = granted);
    if (!granted) return;
    await _loadMonthEvents();
    await _loadSelectedDayEvents();
  }

  Future<void> _loadMonthEvents() async {
    final monthStart = DateTime(_displayedMonth.year, _displayedMonth.month, 1);
    final monthEnd = DateTime(_displayedMonth.year, _displayedMonth.month + 1, 1);
    final events = await _calendarSync.eventsInRange(start: monthStart, end: monthEnd);
    if (!mounted) return;
    setState(() {
      _daysWithEventsInDisplayedMonth = events.map((e) => e.start.day).toSet();
    });
  }

  Future<void> _loadSelectedDayEvents() async {
    final day = _selectedDay;
    if (day == null) {
      setState(() => _selectedDayEvents = []);
      return;
    }
    final date = DateTime(_displayedMonth.year, _displayedMonth.month, day);
    final events = await _calendarSync.eventsOnDay(date);
    if (!mounted) return;
    setState(() => _selectedDayEvents = events);
  }
```

Change `_changeMonth` from:
```dart
  void _changeMonth(int delta) {
    final next = DateTime(_displayedMonth.year, _displayedMonth.month + delta);
    if (next.isBefore(_minMonth) || next.isAfter(_maxMonth)) return;
    setState(() {
      _displayedMonth = next;
      _selectedDay = null;
    });
  }
```
to:
```dart
  void _changeMonth(int delta) {
    final next = DateTime(_displayedMonth.year, _displayedMonth.month + delta);
    if (next.isBefore(_minMonth) || next.isAfter(_maxMonth)) return;
    setState(() {
      _displayedMonth = next;
      _selectedDay = null;
      _daysWithEventsInDisplayedMonth = {};
      _selectedDayEvents = [];
    });
    if (_calendarAvailable) _loadMonthEvents();
  }
```

In `build()`, change the `_cellFor` call site from:
```dart
    final cells = [
      for (var d = 1; d <= daysInMonth; d++)
        _cellFor(
          DateTime(year, month, d),
          userYearZhi: userYearZhi,
          isToday: _showsToday && d == _today.day,
        ),
    ];
```
to (no change needed here — `_cellFor` itself is what changes, see below; this snippet is shown only so you can locate the surrounding context).

Change the `onSelectDay` callback passed to `CalendarGrid` from:
```dart
            CalendarGrid(
              leadingBlanks: leadingBlanks,
              days: cells,
              selectedDay: _selectedDay,
              onSelectDay: (d) => setState(() => _selectedDay = d),
            ),
```
to:
```dart
            CalendarGrid(
              leadingBlanks: leadingBlanks,
              days: cells,
              selectedDay: _selectedDay,
              onSelectDay: (d) {
                setState(() => _selectedDay = d);
                if (_calendarAvailable) _loadSelectedDayEvents();
              },
            ),
```

Change `_cellFor` from:
```dart
  CalendarCellData _cellFor(DateTime date, {required String userYearZhi, required bool isToday}) {
    final day = AlmanacDay.forDate(date);
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
```
to:
```dart
  CalendarCellData _cellFor(DateTime date, {required String userYearZhi, required bool isToday}) {
    final day = AlmanacDay.forDate(date);
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
      hasEvents: _daysWithEventsInDisplayedMonth.contains(date.day),
    );
  }
```

Change `_buildDayCard` from:
```dart
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
```
to:
```dart
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
      calendarAvailable: _calendarAvailable,
      eventLines: [
        for (final e in _selectedDayEvents.take(5))
          '${_twoDigits(e.start.hour)}:${_twoDigits(e.start.minute)} ${e.title}',
      ],
    );
  }

  static String _twoDigits(int n) => n.toString().padLeft(2, '0');
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `flutter test test/screens/calendar/calendar_widgets_test.dart test/screens/calendar/calendar_screen_test.dart -v`
Expected: PASS (every test in both files, old and new).

- [ ] **Step 5: `flutter analyze` clean, full suite check**

Run: `flutter analyze` → `No issues found!`
Run: `flutter test` → PASS (report the real total count).

Also specifically re-run `test/screens/onboarding/onboarding_flow_test.dart` and `test/screens/tab_shell_test.dart` — both build a full, real `TabShell` (which eagerly builds `CalendarScreen` via `IndexedStack`, meaning `_initCalendarSync()` now fires during those tests too). Confirm neither breaks or hangs — `CalendarScreen`'s calendar-permission calls should degrade to "no permission" silently in that context, same as every other test in this repo that doesn't explicitly mock the channel, but this must be verified, not assumed.

- [ ] **Step 6: Commit**

```bash
git add lib/screens/calendar/calendar_screen.dart lib/screens/calendar/calendar_widgets.dart test/screens/calendar/calendar_screen_test.dart test/screens/calendar/calendar_widgets_test.dart
git commit -m "feat(calendar): wire real device_calendar read into Tab C (grid dots + day card event list)"
```

---

### Task 3: Wire Tab B — real calendar write in `ActivityScreen`/`ResultCard`

**Files:**
- Modify: `lib/screens/activity/activity_screen.dart`
- Modify: `lib/screens/activity/activity_widgets.dart`
- Modify: `test/screens/activity/activity_screen_test.dart`
- Modify: `test/screens/activity/activity_widgets_test.dart`

Per spec §9.9: 寫：Tab B 加入日曆 → 建全日 event，標題「$活動名（玄曆吉日）」，description 放 🔮 原因（per this plan's scope decision #5, no per-activity icon). "當日行程 ›" reuses `CalendarSyncService.eventsOnDay` (scope decision #6).

- [ ] **Step 1: Write the failing tests**

Read the current `test/screens/activity/activity_widgets_test.dart` first. Replace the second `ResultCard` test (the one that currently taps and expects the old stub SnackBar text) — change:
```dart
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
```
to:
```dart
    testWidgets('showCalendarActions=true 就顯示日曆按鈕，撳落分別 call onAddToCalendar/onViewSchedule', (tester) async {
      var addTapped = false;
      var viewTapped = false;
      await tester.pumpWidget(wrap(ResultCard(
        dateLabel: '7月16日（四）辛卯日',
        stars: 5,
        subtitleLine: '農曆六月初三・成日・沖雞煞西',
        reason: '🔮 成日利成事。',
        showCalendarActions: true,
        onAddToCalendar: () => addTapped = true,
        onViewSchedule: () => viewTapped = true,
      )));

      expect(find.text('＋ 加入我嘅日曆'), findsOneWidget);
      expect(find.text('當日行程 ›'), findsOneWidget);

      await tester.tap(find.text('＋ 加入我嘅日曆'));
      expect(addTapped, isTrue);
      expect(viewTapped, isFalse);

      await tester.tap(find.text('當日行程 ›'));
      expect(viewTapped, isTrue);
    });
```

Now read the current `test/screens/activity/activity_screen_test.dart` first, then add these imports at the top alongside the existing ones:

```dart
import 'package:device_calendar/device_calendar.dart';
```

Add these new tests at the end of `main()` (every existing test in this file stays exactly as-is — `ActivityScreen` only touches `device_calendar` when the calendar buttons are actually tapped, which none of the existing tests do):

```dart
  group('ActivityScreen — 日曆整合（冇 mock platform channel，即係呢部 Mac 嘅真實情況）', () {
    testWidgets('撳「＋ 加入我嘅日曆」：冇日曆權限 → 顯示提示 SnackBar', (tester) async {
      await tester.pumpWidget(wrap(ActivityScreen(
        profile: profile,
        today: DateTime(2026, 7, 11),
      )));

      await tester.tap(find.text('＋ 加入我嘅日曆'));
      await tester.pumpAndSettle();

      expect(find.textContaining('需要日曆權限'), findsOneWidget);
    });

    testWidgets('撳「當日行程 ›」：冇日曆權限 → dialog 顯示提示文字', (tester) async {
      await tester.pumpWidget(wrap(ActivityScreen(
        profile: profile,
        today: DateTime(2026, 7, 11),
      )));

      await tester.tap(find.text('當日行程 ›'));
      await tester.pumpAndSettle();

      expect(find.textContaining('冇搵到行程'), findsOneWidget);

      await tester.tap(find.text('知道喇'));
      await tester.pumpAndSettle();
      expect(find.textContaining('冇搵到行程'), findsNothing);
    });
  });

  group('ActivityScreen — 日曆整合（mocked platform channel）', () {
    tearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(DeviceCalendarPlugin.channel, null);
    });

    testWidgets('撳「＋ 加入我嘅日曆」：有權限、有可寫日曆 → 建 event 成功、顯示成功 SnackBar', (tester) async {
      Map<dynamic, dynamic>? sentArgs;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(DeviceCalendarPlugin.channel, (call) async {
        switch (call.method) {
          case 'hasPermissions':
          case 'requestPermissions':
            return true;
          case 'retrieveCalendars':
            return json.encode([
              {'id': 'cal1', 'name': 'Personal', 'isReadOnly': false, 'isDefault': true},
            ]);
          case 'createOrUpdateEvent':
            sentArgs = call.arguments as Map<dynamic, dynamic>;
            return 'new-event-id';
          default:
            return null;
        }
      });

      await tester.pumpWidget(wrap(ActivityScreen(
        profile: profile,
        today: DateTime(2026, 7, 11),
      )));

      await tester.tap(find.text('＋ 加入我嘅日曆'));
      await tester.pumpAndSettle();

      expect(find.textContaining('已加入你嘅日曆'), findsOneWidget);
      expect(sentArgs, isNotNull);
      expect(sentArgs!['eventAllDay'], isTrue);
      expect((sentArgs!['eventTitle'] as String).contains('（玄曆吉日）'), isTrue);
    });
  });
```

You'll also need `import 'dart:convert';` in `activity_screen_test.dart` for the `json.encode` calls above — check whether it's already imported (it likely isn't, since this file doesn't currently decode/encode JSON directly) and add it if missing.

- [ ] **Step 2: Run tests to verify they fail**

Run: `flutter test test/screens/activity/activity_widgets_test.dart test/screens/activity/activity_screen_test.dart -v`
Expected: FAIL — `ResultCard` has no `onAddToCalendar`/`onViewSchedule` params yet (compile error), and the new `ActivityScreen` tests find no matching SnackBar/dialog text since nothing is wired yet.

- [ ] **Step 3: Write the implementation**

In `lib/screens/activity/activity_widgets.dart`, read the current file first. Modify `ResultCard`: add two callback fields, and wire them into the two existing buttons instead of their hardcoded `ScaffoldMessenger` stub taps.

Change the class fields/constructor from:
```dart
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
```
to:
```dart
class ResultCard extends StatelessWidget {
  final String dateLabel;
  final int stars; // 1-5
  final String subtitleLine;
  final String reason;
  final bool showCalendarActions;
  final VoidCallback? onAddToCalendar;
  final VoidCallback? onViewSchedule;

  const ResultCard({
    super.key,
    required this.dateLabel,
    required this.stars,
    required this.subtitleLine,
    required this.reason,
    required this.showCalendarActions,
    this.onAddToCalendar,
    this.onViewSchedule,
  });
```

Change the two `GestureDetector.onTap` stub callbacks inside the `if (showCalendarActions) ...[` block from:
```dart
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
```
to:
```dart
                Expanded(
                  child: GestureDetector(
                    onTap: onAddToCalendar,
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
                    onTap: onViewSchedule,
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
```

Also update the file's doc comment at the top of `ResultCard` (currently says "日曆整合本身係 stub（spec §9.9 真整合留返之後 sub-plan）") since that's no longer true — change:
```dart
/// 反向擇日結果卡（design html 結果卡區塊）。[showCalendarActions] 淨係
/// 畀排名最高嗰張卡用（design html 淨係第一張示範咗日曆按鈕列）；
/// 日曆整合本身係 stub（spec §9.9 真整合留返之後 sub-plan）。
```
to:
```dart
/// 反向擇日結果卡（design html 結果卡區塊）。[showCalendarActions] 淨係
/// 畀排名最高嗰張卡用（design html 淨係第一張示範咗日曆按鈕列）。
/// 呢個 widget 本身唔知道 device_calendar——[onAddToCalendar]／
/// [onViewSchedule] 由 [ActivityScreen] 注入（dumb widget 原則，同
/// `calendar_widgets.dart` 嘅 `CalendarCellData` 一樣）。
```

In `lib/screens/activity/activity_screen.dart`, read the current file first. Add the import:
```dart
import '../../services/calendar_sync.dart';
```

Add a `CalendarSyncService` field and two handler methods to `_ActivityScreenState`. Change:
```dart
class _ActivityScreenState extends State<ActivityScreen> {
  late String _selectedActivity = loadActivities().first.name;
  int _rangeIndex = 1; // 未來一個月
```
to:
```dart
class _ActivityScreenState extends State<ActivityScreen> {
  final _calendarSync = CalendarSyncService();

  late String _selectedActivity = loadActivities().first.name;
  int _rangeIndex = 1; // 未來一個月
```

Add these two methods anywhere inside `_ActivityScreenState` (e.g. right after `_fortuneScoreOf`):
```dart
  Future<void> _addToCalendar({
    required Activity activity,
    required DateTime date,
    required String reason,
  }) async {
    final added = await _calendarSync.addAllDayEvent(
      date: date,
      title: '${activity.name}（玄曆吉日）',
      description: reason,
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(added ? '已加入你嘅日曆 ✓' : '需要日曆權限先可以加入 — 請去手機設定開返'),
    ));
  }

  Future<void> _showDaySchedule(DateTime date, String dateLabel) async {
    final events = await _calendarSync.eventsOnDay(date);
    if (!mounted) return;
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('$dateLabel 嘅行程'),
        content: events.isEmpty
            ? const Text('呢日冇搵到行程（或者未開日曆權限）')
            : SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (final e in events)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Text(
                          '${e.start.hour.toString().padLeft(2, '0')}:'
                          '${e.start.minute.toString().padLeft(2, '0')} ${e.title}',
                        ),
                      ),
                  ],
                ),
              ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('知道喇'),
          ),
        ],
      ),
    );
  }
```

Change `_buildResultCard` from:
```dart
  Widget _buildResultCard(
    XuanLiColors colors,
    Activity activity,
    ActivityDayResult result, {
    required bool showCalendarActions,
  }) {
    final day = AlmanacDay.forDate(result.date);
    final weekdayChar = _weekdayChars[result.date.weekday - 1];
    final dateLabel =
        '${result.date.month}月${result.date.day}日（$weekdayChar）${day.ganzhiDay}日';
    final subtitleLine = '${day.lunarLabel}・${day.zhiXing}日・${day.chong}';
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
```
to:
```dart
  Widget _buildResultCard(
    XuanLiColors colors,
    Activity activity,
    ActivityDayResult result, {
    required bool showCalendarActions,
  }) {
    final day = AlmanacDay.forDate(result.date);
    final weekdayChar = _weekdayChars[result.date.weekday - 1];
    final dateLabel =
        '${result.date.month}月${result.date.day}日（$weekdayChar）${day.ganzhiDay}日';
    final subtitleLine = '${day.lunarLabel}・${day.zhiXing}日・${day.chong}';
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
      onAddToCalendar: showCalendarActions
          ? () => _addToCalendar(activity: activity, date: result.date, reason: reason)
          : null,
      onViewSchedule: showCalendarActions
          ? () => _showDaySchedule(result.date, dateLabel)
          : null,
    );
  }
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `flutter test test/screens/activity/activity_widgets_test.dart test/screens/activity/activity_screen_test.dart -v`
Expected: PASS (every test in both files, old and new).

- [ ] **Step 5: `flutter analyze` clean, full suite check**

Run: `flutter analyze` → `No issues found!`
Run: `flutter test` → PASS (report the real total count).

- [ ] **Step 6: Commit**

```bash
git add lib/screens/activity/activity_screen.dart lib/screens/activity/activity_widgets.dart test/screens/activity/activity_screen_test.dart test/screens/activity/activity_widgets_test.dart
git commit -m "feat(calendar): wire real device_calendar write into Tab B (加入我嘅日曆/當日行程)"
```

---

### Task 4: Docs + final full-branch verification

**Files:**
- Modify: `CHANGELOG.md`
- Modify: `CLAUDE.md`

- [ ] **Step 1: Update `CHANGELOG.md`**

Read the current `CHANGELOG.md` first (per this repo's CLAUDE.md Standards: changes go at the **top**, never appended elsewhere). Add a new top entry summarizing this plan's work: `CalendarSyncService` added (permission/read/write wrapping `device_calendar`, no new package since it was already in `pubspec.yaml` unused); Tab C's month grid event-dots and day card's "📅 你嘅行程" section now backed by real data instead of the `hasEvents`-always-false stub; Tab B's "＋ 加入我嘅日曆"/"當日行程 ›" now perform real writes/reads instead of showing a stub SnackBar. Note explicitly that this was built and tested via mocked platform channel only (no simulator/device available on this Mac) — real on-device permission-dialog and calendar-app behavior is unverified until tested on a real device.

- [ ] **Step 2: Update `CLAUDE.md`'s Progress section**

Read the current `CLAUDE.md` first. In its `## Progress` section, the line `- [ ] Phase 2 App UI（onboarding + 組合頁 + 3 tabs + 日曆整合）` should now be checked off — this plan was the last unbuilt piece of that line (onboarding, 組合頁, and all 3 tabs' non-calendar functionality were already done in earlier phases; 設定頁 was Phase 2g; 日曆整合 is this plan). Change it to `- [x] Phase 2 App UI（onboarding + 組合頁 + 3 tabs + 日曆整合）`.

Respect CLAUDE.md's own stated size limit for itself (100 lines / 6KB per its own Standards line) — if adding this checkbox flip pushes it over, that's fine (a single-character diff inside an existing line doesn't grow the file), just don't add new prose to this file; anything narrative belongs in `CHANGELOG.md` per Task 4 Step 1.

- [ ] **Step 3: Full verification sweep**

Run, in order, and report the real output of each (not a summary — paste what you actually saw):
```bash
flutter analyze
flutter test
dart test test/engine/
```
All three must be 100% green. If anything fails, fix it before proceeding — do not commit a red build.

Also specifically re-run these three files individually and confirm they're unaffected by this plan's changes (they build full `TabShell`/`CalendarScreen`/`ActivityScreen` trees and are the recurring regression-risk files across this project's Phase 2 work):
```bash
flutter test test/screens/onboarding/onboarding_flow_test.dart
flutter test test/screens/tab_shell_test.dart
```

- [ ] **Step 4: Commit**

```bash
git add CHANGELOG.md CLAUDE.md
git commit -m "docs: update CHANGELOG + close out Phase 2 App UI checklist (日曆整合 done)"
```

---

## Self-Review Notes

**Spec coverage:** all of spec §9.9's bullets are covered — permission-on-first-entry (Task 2), read → grid dots + day card list max 5 (Task 2), write → all-day event with the specified title format and 🔮-prefixed description (Task 3). The one item not literally in §9.9's bullet list ("當日行程 ›") is covered too, per scope decision #6, by reusing the read path rather than inventing new UI.

**No new packages:** `device_calendar` was already in `pubspec.yaml` (added early, unused until this plan) — confirmed by reading the file directly before writing this plan. No other new dependency is introduced; `pubspec.yaml`/`pubspec.lock` should be untouched by every task in this plan.

**Testability given no device/simulator:** every new code path in `CalendarSyncService` is covered by a mocked-platform-channel test in Task 1 (permission granted/denied, write success/no-writable-calendar, read merge-across-calendars/sort/date-range). Tasks 2 and 3's screen-level tests cover both the "no permission" path (which needs no mock — it's this Mac's actual default behavior, verified by reading `device_calendar`'s own source: unhandled platform-channel exceptions are already caught internally and turned into `Result.isSuccess == false`) and the "permission granted, real data" path (which does need a mock, added specifically for that purpose). This is the most thorough verification achievable without a physical device — the plan does not claim more than that.

**Known regression-risk pattern to watch for:** `CalendarScreen` now does real (mockable) async work in `initState()` for the first time. Task 2 Step 5 explicitly requires re-running `onboarding_flow_test.dart` and `tab_shell_test.dart`, both of which build a real `CalendarScreen` via `TabShell`'s `IndexedStack` — this is the same class of regression this project has hit repeatedly whenever a tab screen's internals change.

**Type consistency:** `CalendarSyncEvent`'s fields (`title`, `start`) are used identically across Task 1 (definition), Task 2 (`_selectedDayEvents`/`_daysWithEventsInDisplayedMonth` derivation), and Task 3 (`_showDaySchedule`'s dialog content) — re-checked for drift. `CalendarSyncService`'s method signatures (`hasPermission()`, `requestPermission()`, `addAllDayEvent({date, title, description})`, `eventsInRange({start, end})`, `eventsOnDay(date)`) match their Task 1 definitions exactly at every call site in Tasks 2–3.

**Placeholder scan:** every step has complete, literal code — no "add error handling"/"TBD"/"similar to Task N" placeholders. The only intentionally-limited scope is explicitly named in the "Scope decisions" section above, not silently gapped.

**A suspected bug was investigated during plan-writing, and found NOT to be real — corrected before this note was finalized.** The first draft of `addAllDayEvent` used a custom `_hostFixedOffsetLocation()` to "fix" what looked like a day-off-by-one risk in how `device_calendar-4.3.3`'s `createOrUpdateEvent` normalizes all-day events (it rebuilds the instant via a host-local `DateTime(...)` constructor, then calls `TZDateTime.from(that, event.start!.location)`). That draft was wrong: `TZDateTime.from` (`timezone-0.9.4/lib/src/date_time.dart:219`) is **instant-preserving** — `_native = other.toUtc()` — so the `location` argument only affects later `.year`/`.month`/`.day` *display* getters, never the transported epoch. The custom location had zero effect on the actual bytes sent over the platform channel; the epoch is fully determined by the host-local `DateTime(...)` step alone, before `.from()` runs at all. Working through what that epoch actually represents: for a `+8` host (this dev Mac, Hong Kong), the resulting UTC epoch for "2026-07-20 00:00 host-local" is "2026-07-19 16:00 UTC" — which, read back in the *same device's own local time* (as a real phone running this app would), is exactly "2026-07-20 00:00" again. Because the Dart-side write and the native calendar's own rendering both run on the same physical device sharing one real timezone, there was never an actual cross-timezone mismatch to fix — the plugin's design is self-consistent by construction. The plan now uses plain `TZDateTime(UTC, ...)` (the obvious, simple choice) and the write test asserts the epoch against a portably-computed expected value (`DateTime(2026,7,20).toUtc().millisecondsSinceEpoch`, not a hardcoded day-of-month) so the test passes correctly regardless of which timezone the machine running it happens to be in. This whole chain — draft a fix for a suspected bug, have it independently verified, discover the fix doesn't hold up, trace through the actual mechanism, and simplify back to something both correct and simpler than the "fix" — is recorded here so a future reader doesn't rediscover the same false lead.
