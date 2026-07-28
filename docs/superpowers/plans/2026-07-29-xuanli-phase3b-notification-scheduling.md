# XuanLi Phase 3b — Notification Scheduling Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build spec §9.7's notification delivery — a `NotificationScheduler` service wrapping `flutter_local_notifications`, scheduling the next 7 days' daily notification (short-form copywriter text, spec-default 07:30 or whatever `AppSettings` says) via `zonedSchedule`, refreshed on every app launch (matching Phase 3a's `WidgetDataBridge` refresh cadence, per spec §9.7: "app 每次打開 refresh").

**Why this was previously deferred (Phase 3a's plan explicitly named this as its own follow-up):** at Phase 3a planning time, `flutter_local_notifications` was assumed to need a fundamentally different testing approach than `device_calendar`/`home_widget`. That assumption was WRONG and has since been disproven by reading the actual installed package source: `flutter_local_notifications-17.2.4`'s `MethodChannelFlutterLocalNotificationsPlugin` (the concrete implementation `FlutterLocalNotificationsPlugin`'s factory constructor auto-registers based on `defaultTargetPlatform`, which defaults to `TargetPlatform.android` in `flutter test`) uses a plain `MethodChannel('dexterous.com/flutter/local_notifications')` internally — the exact same `TestDefaultBinaryMessengerBinding` mocking technique already proven for `device_calendar` (Phase 2h) and `home_widget` (Phase 3a) works here too. The one part of the original deferral that WAS correct: correct notification fire-times genuinely need real device-timezone detection (unlike the calendar all-day-event case, where plain UTC was proven correct — see Phase 2h's CHANGELOG entry — a wrong timezone here would make notifications fire at the wrong wall-clock hour, a real bug). This plan adds `flutter_timezone` (confirmed current API via its installed source, version `5.1.0`) to solve that correctly.

**Architecture:** `NotificationScheduler` wraps `FlutterLocalNotificationsPlugin` (a true singleton behind its own factory — unlike `device_calendar`'s `DeviceCalendarPlugin`, constructing it fresh always returns the same instance, so this is safe to construct per-call like `CalendarSyncService`/`WidgetDataBridge` are). `refreshNext7Days({required Profile, required AppSettings})`: first computes all 7 days' notification text via `buildNotificationText(buildDayReading(...))` — pure Dart, kept outside any try/catch per the lesson from Phase 3a's Task 2 review (a computation bug should surface, not be silently swallowed alongside expected platform-channel failures). Then, inside one try/catch: ensures timezone is set up (`flutter_timezone` → `tz.setLocalLocation`) and the plugin is initialized, cancels the 7 fixed notification IDs (`1000`–`1006`, one per day-offset) so re-running never accumulates duplicates, and — only if `settings.notificationsEnabled` — schedules each of the 7 days at `settings.notificationHour:notificationMinute` via `zonedSchedule`, skipping any day/time combination already in the past (required: the plugin's own `validateDateIsInTheFuture` throws if you don't). Wired into `main.dart`'s bootstrap, fire-and-forget (`unawaited()`), same pattern as `WidgetDataBridge`.

**Tech Stack:** `flutter_local_notifications: ^17.2.0` (already in `pubspec.yaml`, unused until now — same "present but unused" situation as `device_calendar` before Phase 2h). **New dependencies added by this plan** (confirmed necessary, not decorative): `flutter_timezone: ^5.1.0` (device-timezone detection — its own API confirmed by reading the installed source: `FlutterTimezone.getLocalTimezone()` returns `Future<TimezoneInfo>`, `.identifier` is the IANA string e.g. `"Asia/Hong_Kong"`) and `timezone: ^0.9.4` (promoted from an existing transitive dependency — already installed via `device_calendar`, same version, zero version churn — to an explicit direct one, since `NotificationScheduler` uses its `TZDateTime`/`getLocation`/`setLocalLocation` API directly rather than just incidentally). Both already added to `pubspec.yaml`/`pubspec.lock` and verified (`flutter analyze` clean, full suite still green) before this plan was written.

---

## Scope decisions (don't re-litigate)

1. **New packages ARE added this time** (`flutter_timezone`, `timezone` promoted to direct) — unlike every other Phase 2h/3a service, which deliberately used only already-present packages. This is a genuine functional requirement (correct notification fire-time), not scope creep — confirmed by reading `flutter_local_notifications`'s own `zonedSchedule` semantics (a `TZDateTime` in the wrong location fires at the wrong wall-clock time, full stop — there is no "plain UTC happens to work" escape hatch here the way there was for `device_calendar`'s all-day-event write).
2. **Fixed notification IDs 1000–1006** (day-offset 0–6) — chosen to be clearly out of any plausible range other future notification features might use, and cancelled unconditionally at the start of every refresh so re-running (every app launch, per spec) never accumulates duplicates and correctly clears stale schedules if the user just disabled notifications.
3. **`AndroidScheduleMode.inexactAllowWhileIdle`** — Android's `exact`/`exactAllowWhileIdle`/`alarmClock` modes require the `SCHEDULE_EXACT_ALARM` permission (Android 12+) and additional manifest setup neither this plan nor any prior XuanLi phase has done. A daily reminder notification has zero need for to-the-second precision ("每朝 07:30" tolerates being a few minutes off), so `inexact`-family scheduling is the correct, lower-friction choice — not a corner cut.
4. **This plan only wires the refresh into `main.dart`'s bootstrap** (matching spec §9.7's literal "app 每次打開 refresh"), NOT into `SettingsScreen`'s notification toggle/time-picker handlers. Spec doesn't require live rescheduling the instant a user changes the time in Settings — the next app launch's refresh picks up the new `AppSettings` naturally. Wiring a live reschedule from Settings would be scope creep beyond what spec §9.7 actually asks for.
5. **Timezone detection failure degrades gracefully, not fatally.** If `FlutterTimezone.getLocalTimezone()` throws (e.g. platform channel unavailable — this Mac's actual `flutter test` reality), `tz.local` simply stays at its package default (`UTC`) rather than crashing the whole refresh — notifications would fire at the wrong hour in that specific failure case, which is objectively worse than not firing at all, but the alternative (letting the whole `refreshNext7Days` throw) is worse still since Phase 3a's own reviewed design principle is "platform-channel failures must never crash background refreshes." This asymmetry (imperfect-but-running vs. not-running) is judged acceptable for a background daily-reminder feature; flagged explicitly in the code's doc comment, not hidden.

---

## File Structure

```
xuanli/
└── lib/
    ├── services/
    │   └── notification_scheduler.dart      # NEW — NotificationScheduler
    └── main.dart                            # MODIFY — wire refresh into bootstrap
└── test/
    ├── services/
    │   └── notification_scheduler_test.dart # NEW
    └── widget_test.dart                     # MODIFY — bootstrap wiring test
```

---

### Task 1: `NotificationScheduler` — flutter_local_notifications write path

**Files:**
- Create: `lib/services/notification_scheduler.dart`
- Create: `test/services/notification_scheduler_test.dart`

- [ ] **Step 1: Write the failing tests**

Create `test/services/notification_scheduler_test.dart`:

```dart
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xuanli/engine/copywriter.dart';
import 'package:xuanli/engine/profile_builder.dart';
import 'package:xuanli/models/settings.dart';
import 'package:xuanli/services/notification_scheduler.dart';

const _notifChannel = MethodChannel('dexterous.com/flutter/local_notifications');
const _tzChannel = MethodChannel('flutter_timezone');

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    initMbtiTones(File('lib/data/mbti_tones.json').readAsStringSync());
    initActivityCategories(File('lib/data/activity_categories.json').readAsStringSync());
  });

  void mockNotifChannel(Future<dynamic> Function(MethodCall call) handler) {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_notifChannel, handler);
  }

  void mockTzChannel(Future<dynamic> Function(MethodCall call) handler) {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_tzChannel, handler);
  }

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_notifChannel, null);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_tzChannel, null);
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

  group('NotificationScheduler — 冇 platform channel implementation（呢部 Mac 嘅真實情況）', () {
    test('refreshNext7Days() 唔會 throw，靜靜完成', () async {
      final scheduler = NotificationScheduler();
      await scheduler.refreshNext7Days(
        profile: profile,
        settings: AppSettings.defaults,
        today: DateTime(2026, 7, 11),
      );
      // 冇 assertion 爆 = 冇 throw，就係呢個 test 想證明嘅嘢。
    });
  });

  group('NotificationScheduler — mocked platform channel', () {
    test('notificationsEnabled=false → 淨係 cancel 晒 7 個 id，唔會 zonedSchedule', () async {
      final cancelledIds = <int>[];
      var zonedScheduleCalled = false;

      mockTzChannel((call) async => 'Asia/Hong_Kong');
      mockNotifChannel((call) async {
        switch (call.method) {
          case 'initialize':
            return true;
          case 'cancel':
            cancelledIds.add(call.arguments as int);
            return null;
          case 'zonedSchedule':
            zonedScheduleCalled = true;
            return null;
          default:
            return null;
        }
      });

      final scheduler = NotificationScheduler();
      await scheduler.refreshNext7Days(
        profile: profile,
        settings: AppSettings.defaults.copyWith(notificationsEnabled: false),
        today: DateTime(2026, 7, 11),
      );

      expect(cancelledIds.toSet(), {1000, 1001, 1002, 1003, 1004, 1005, 1006});
      expect(zonedScheduleCalled, isFalse);
    });

    test('notificationsEnabled=true → cancel 晒之後，排晒未來嗰幾日，傳啱 id/title/body', () async {
      final scheduledCalls = <Map<dynamic, dynamic>>[];

      mockTzChannel((call) async => 'Asia/Hong_Kong');
      mockNotifChannel((call) async {
        switch (call.method) {
          case 'initialize':
            return true;
          case 'cancel':
            return null;
          case 'zonedSchedule':
            scheduledCalls.add(call.arguments as Map<dynamic, dynamic>);
            return null;
          default:
            return null;
        }
      });

      final scheduler = NotificationScheduler();
      // "today" 用未來日子（相對於 test 執行嗰刻），確保 7 日全部都
      // 未過去，7 個 zonedSchedule call 全部都應該真係發生。用
      // DateTime.now() 加 30 日，避免呢個 test 隨時間推移而失效。
      final farFuture = DateTime.now().add(const Duration(days: 30));
      await scheduler.refreshNext7Days(
        profile: profile,
        settings: AppSettings.defaults,
        today: DateTime(farFuture.year, farFuture.month, farFuture.day),
      );

      expect(scheduledCalls.length, 7);
      final ids = scheduledCalls.map((c) => c['id'] as int).toSet();
      expect(ids, {1000, 1001, 1002, 1003, 1004, 1005, 1006});
      for (final call in scheduledCalls) {
        expect(call['title'], '玄曆');
        expect((call['body'] as String).startsWith('今日'), isTrue);
      }
    });

    test('today 淨係得過去嘅時間（例如 07:30 已經過咗）→ 嗰一日唔會 zonedSchedule，但唔會 throw', () async {
      var zonedScheduleCount = 0;

      mockTzChannel((call) async => 'Asia/Hong_Kong');
      mockNotifChannel((call) async {
        switch (call.method) {
          case 'initialize':
            return true;
          case 'cancel':
            return null;
          case 'zonedSchedule':
            zonedScheduleCount++;
            return null;
          default:
            return null;
        }
      });

      final scheduler = NotificationScheduler();
      // "today" 用好耐之前嘅日子，settings 嘅時間（07:30）實一定已經
      // 過咗（相對於 test 真實執行嘅 wall clock）——7 日全部都應該
      // 俾 validateDateIsInTheFuture 邏輯跳過，唔會 call zonedSchedule，
      // 但都唔應該 throw。
      await scheduler.refreshNext7Days(
        profile: profile,
        settings: AppSettings.defaults,
        today: DateTime(2020, 1, 1),
      );

      expect(zonedScheduleCount, 0);
    });

    test('timezone detection 失敗都唔會令成個 refresh 爆', () async {
      mockTzChannel((call) async {
        throw PlatformException(code: 'ERR', message: 'boom');
      });
      mockNotifChannel((call) async => call.method == 'initialize' ? true : null);

      final scheduler = NotificationScheduler();
      await scheduler.refreshNext7Days(
        profile: profile,
        settings: AppSettings.defaults,
        today: DateTime(2026, 7, 11),
      );
      // 冇 throw 就已經證明咗呢個 test 想要嘅嘢。
    });
  });
}
```

Every test constructs its own `AppSettings` inline via `AppSettings.defaults.copyWith(...)` or uses `AppSettings.defaults` directly — no shared top-level settings binding is needed.

Check `lib/engine/profile_builder.dart`'s `buildProfile(...)` signature matches (same helper used throughout this repo's other service tests, e.g. `test/services/widget_data_bridge_test.dart`).

- [ ] **Step 2: Run tests to verify they fail**

Run: `flutter test test/services/notification_scheduler_test.dart`
Expected: FAIL — `Error: Not found: 'package:xuanli/services/notification_scheduler.dart'`.

- [ ] **Step 3: Write the implementation**

Create `lib/services/notification_scheduler.dart`:

```dart
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import '../engine/copywriter.dart';
import '../engine/day_reading_engine.dart';
import '../models/profile.dart';
import '../models/settings.dart';

/// 排未來 7 日嘅每朝通知（spec §9.7）。設計原則同 `WidgetDataBridge`
/// （Phase 3a）一致：純 Dart 嘅文案計算行喺 try/catch 外面（一個真
/// bug 應該可以喺開發環境睇到，唔應該靜靜俾 platform-channel 嘅
/// try/catch 一齊吞埋）；淨係 platform 互動（timezone 偵測/init/
/// cancel/zonedSchedule）先 best-effort 咁被 catch。
class NotificationScheduler {
  final FlutterLocalNotificationsPlugin _plugin;

  // `FlutterLocalNotificationsPlugin()` 本身係一個 factory 包住嘅
  // singleton（唔似 device_calendar 嘅 DeviceCalendarPlugin，每次
  // `FlutterLocalNotificationsPlugin()` 都係攞返同一個 instance），
  // 所以呢度隨便 construct 都安全，同 CalendarSyncService/
  // WidgetDataBridge 一樣嘅 DI-for-testability pattern。
  NotificationScheduler({FlutterLocalNotificationsPlugin? plugin})
      : _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  static const _channelId = 'xuanli_daily';
  static const _channelName = '每朝通知';
  static const _channelDescription = '每朝一句今日通勝提示（spec §9.7）';

  /// day-offset (0-6) 對應嘅固定 notification id——每次 refresh 都會
  /// 先 cancel 晒呢 7 個 id 先，等重複 refresh（每次開 app 都會做，
  /// spec §9.7）唔會累積重複通知，用戶拒絕/停用通知之後嗰次 refresh
  /// 亦都會正確清走舊排程。
  static int _idFor(int dayOffset) => 1000 + dayOffset;

  bool _timezoneReady = false;

  /// 攞裝置真實 IANA timezone 嚟 setLocalLocation，令 zonedSchedule
  /// 排嘅時間先啱用戶本身嘅牆鐘時間（唔似 Phase 2h 個全日 calendar
  /// event write——嗰度 plain UTC 已經啱，係因為 device_calendar 自己
  /// 內部有一步 host-local 重新解讀邏輯；呢度冇類似機制，錯咗
  /// timezone 就真係會響錯鐘）。偵測唔到就維持 package 預設
  /// （UTC）——好過成個通知功能因為呢一步失敗而全部攞唔到。
  Future<void> _ensureTimezone() async {
    if (_timezoneReady) return;
    tzdata.initializeTimeZones();
    try {
      final info = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(info.identifier));
    } catch (_) {
      // 見上面段註解：維持 UTC 預設，唔好因為呢步失敗累到成個
      // refresh 爆晒。
    }
    _timezoneReady = true;
  }

  Future<void> _ensureInitialized() async {
    await _ensureTimezone();
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings();
    await _plugin.initialize(
      const InitializationSettings(android: androidSettings, iOS: iosSettings),
    );
  }

  /// [today] 得意 test 用嚟固定「而家」係邊一日——冇畀就用返
  /// `DateTime.now()`（同 `WidgetDataBridge.refreshNext7Days` 一致
  /// 嘅慣例）。
  Future<void> refreshNext7Days({
    required Profile profile,
    required AppSettings settings,
    DateTime? today,
  }) async {
    final now = today ?? DateTime.now();
    final startDate = DateTime(now.year, now.month, now.day);

    // 純 Dart 計算行喺 try/catch 外面：一個 buildDayReading/
    // buildNotificationText 嘅真 bug 應該可以喺開發/測試環境俾人
    // 發現，唔應該同下面 platform-channel 嘅 expected failure
    // 一齊被靜靜吞咗。
    final texts = [
      for (var i = 0; i < 7; i++)
        buildNotificationText(buildDayReading(profile: profile, date: startDate.add(Duration(days: i)))),
    ];

    try {
      await _ensureInitialized();

      for (var i = 0; i < 7; i++) {
        await _plugin.cancel(_idFor(i));
      }

      if (!settings.notificationsEnabled) return;

      final nowTz = tz.TZDateTime.now(tz.local);
      for (var i = 0; i < 7; i++) {
        final day = startDate.add(Duration(days: i));
        final scheduled = tz.TZDateTime(
          tz.local,
          day.year,
          day.month,
          day.day,
          settings.notificationHour,
          settings.notificationMinute,
        );
        if (!scheduled.isAfter(nowTz)) continue;

        await _plugin.zonedSchedule(
          _idFor(i),
          '玄曆',
          texts[i],
          scheduled,
          const NotificationDetails(
            android: AndroidNotificationDetails(
              _channelId,
              _channelName,
              channelDescription: _channelDescription,
            ),
            iOS: DarwinNotificationDetails(),
          ),
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
          uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
        );
      }
    } catch (_) {
      // Best-effort：同 WidgetDataBridge 一致嘅哲學——用戶可能未批
      // 通知權限，或者部機 platform channel 未 ready，呢啲都唔應該
      // 累到成個 app 開唔到。
    }
  }
}
```

**Important note if `FlutterLocalNotificationsPlugin`/`AndroidNotificationDetails`/etc.'s exact constructor signatures don't match** (verify against `~/.pub-cache/hosted/pub.dev/flutter_local_notifications-17.2.4/lib/src/` before assuming a mismatch is your error) — this plan's code was written by reading that exact installed source, so a mismatch likely means the wrong file was checked; re-verify against `platform_flutter_local_notifications.dart` (method signatures) and `notification_details.dart`/`initialization_settings.dart` (constructors) before changing the approach.

- [ ] **Step 4: Run tests to verify they pass**

Run: `flutter test test/services/notification_scheduler_test.dart -v`
Expected: PASS (all tests).

- [ ] **Step 5: `flutter analyze` clean, full suite check**

Run: `flutter analyze` → `No issues found!`
Run: `flutter test` → PASS (report the real total count).

- [ ] **Step 6: Commit**

```bash
git add lib/services/notification_scheduler.dart test/services/notification_scheduler_test.dart pubspec.yaml pubspec.lock
git commit -m "feat(notifications): add NotificationScheduler wrapping flutter_local_notifications + flutter_timezone (spec §9.7)"
```

(`pubspec.yaml`/`pubspec.lock` are included in this commit since this is the task that actually introduces the two new dependencies' first real usage — they were pre-added and pre-verified before this plan was written, but the commit should land alongside the code that uses them, not silently before it.)

---

### Task 2: Wire `NotificationScheduler` into app bootstrap

**Files:**
- Modify: `lib/main.dart`
- Modify: `test/widget_test.dart`

Per spec §9.7: "用 zonedSchedule 預排未來 7 日，app 每次打開 refresh."

- [ ] **Step 1: Write the failing test**

Read the current `test/widget_test.dart` first (it already has the `WidgetDataBridge` bootstrap test from Phase 3a — match its exact style). Add this new test, alongside the existing ones:

```dart
  testWidgets(
      'XuanLiApp：有已存 profile 時，bootstrap 會觸發一次 notification refresh',
      (tester) async {
    var initializeCalled = false;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('dexterous.com/flutter/local_notifications'),
      (call) async {
        if (call.method == 'initialize') initializeCalled = true;
        return true;
      },
    );
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('flutter_timezone'),
      (call) async => 'Asia/Hong_Kong',
    );
    addTearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
              const MethodChannel('dexterous.com/flutter/local_notifications'), null);
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(const MethodChannel('flutter_timezone'), null);
    });

    await StorageService().savePrimaryProfile(_sampleProfileForBootstrapTest());

    await tester.pumpWidget(const XuanLiApp());
    await tester.pump();
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 50));
    });
    await tester.pumpAndSettle();

    expect(find.byType(TabShell), findsOneWidget);
    expect(initializeCalled, isTrue);
  });
```

(Reuse the existing `_sampleProfileForBootstrapTest()` helper already added to this file in Phase 3a — don't redefine it.)

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/widget_test.dart`
Expected: FAIL — `initializeCalled` stays `false` since nothing calls `NotificationScheduler` yet.

- [ ] **Step 3: Write the implementation**

In `lib/main.dart`, read the current file first (it already has the `WidgetDataBridge` wiring from Phase 3a). Add the import:
```dart
import 'services/notification_scheduler.dart';
```

Change `_AppBootstrapState._run()` from (current Phase-3a state):
```dart
  Future<Profile?> _run() async {
    await loadEngineData();
    final settings = await StorageService().loadSettings();
    themeModeController.value = settings.themeMode;
    final profile = await StorageService().loadPrimaryProfile();
    if (profile != null) {
      unawaited(WidgetDataBridge().refreshNext7Days(profile));
    }
    return profile;
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
      unawaited(WidgetDataBridge().refreshNext7Days(profile));
      unawaited(NotificationScheduler().refreshNext7Days(profile: profile, settings: settings));
    }
    return profile;
  }
```

(`settings` is already loaded earlier in this same method for `themeModeController` — reuse it, don't reload.)

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
git commit -m "feat(notifications): refresh notification schedule on every app launch (spec §9.7)"
```

---

### Task 3: Docs + final verification

**Files:**
- Modify: `CHANGELOG.md`
- Modify: `CLAUDE.md`

- [ ] **Step 1: Update `CHANGELOG.md`**

Read the current `CHANGELOG.md` first (changes go at the **top**). Add a new entry:

- `NotificationScheduler` added (`lib/services/notification_scheduler.dart`) — wraps `flutter_local_notifications` (already present, unused until now) to schedule the next 7 days' daily notification via `zonedSchedule`, using `buildNotificationText()` (Phase 3a) for content and `AppSettings.notificationHour/Minute/notificationsEnabled` (Phase 2g) for timing/toggle. Wired into `main.dart`'s bootstrap alongside `WidgetDataBridge`, fire-and-forget.
- **Two new packages added**: `flutter_timezone` (device-IANA-timezone detection, needed for correct notification fire-times — confirmed necessary by reading `flutter_local_notifications`' `zonedSchedule` semantics, unlike Phase 2h's calendar-write case where plain UTC was proven sufficient) and `timezone` (promoted from an existing transitive dependency to a direct one, same version, zero churn).
- **Explicitly correct an assumption from Phase 3a's own plan**: that plan deferred notification scheduling because `flutter_local_notifications` was assumed to need "a fundamentally different testing architecture" than `device_calendar`/`home_widget`. That assumption was wrong — verified by reading the installed package source, its concrete platform implementations use plain, mockable `MethodChannel`s exactly like the other two. Recorded here so a future reader doesn't repeat the same over-cautious deferral.
- **Note the scope boundary**: this only wires the refresh into app-launch bootstrap (per spec §9.7's literal text), not into `SettingsScreen`'s notification toggle/time-picker (a live-reschedule-on-settings-change UX, not required by spec — the next app launch picks up new settings naturally). Also note timezone-detection failure degrades to the package's UTC default rather than crashing the refresh — an explicit, documented tradeoff (imperfect-but-running beats not-running for a background daily reminder), not a silent gap.

- [ ] **Step 2: Update `CLAUDE.md`'s Progress section**

Read the current `CLAUDE.md` first. The `- [ ] Phase 3 Widget（iOS/Android 小+中）+ 每日通知` line should **stay unchecked** — this plan builds the Dart-side notification-scheduling half only; the widget UI (native iOS/Android) is still entirely unbuilt (blocked on missing Xcode/Android Studio tooling, tracked separately). Do not check this box. This step is a no-op unless something else in this section is stale.

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
git commit -m "docs: update CHANGELOG for Phase 3b notification scheduling"
```

Also `git add` this plan file itself (`docs/superpowers/plans/2026-07-29-xuanli-phase3b-notification-scheduling.md`, currently untracked), following this project's established convention.

---

## Self-Review Notes

**Spec coverage:** spec §9.7's core requirement — "每朝（預設 07:30）...內容 = copywriter 短版...用 zonedSchedule 預排未來 7 日，app 每次打開 refresh" — is fully covered: default time comes from `AppSettings.defaults` (already 07:30, set in Phase 2g), content from `buildNotificationText` (Phase 3a), 7-day advance scheduling via `zonedSchedule`, refresh-on-launch via bootstrap wiring. Not covered (explicitly, not silently): any Settings-screen live-reschedule UX, and — like every device-dependent feature in this project since Phase 2g — real on-device notification delivery/permission-prompt behavior, which can't be verified without a simulator/device.

**No silent new-package additions:** `flutter_timezone`/`timezone` were added and their necessity justified (not just asserted) by tracing `zonedSchedule`'s actual timezone semantics in the installed package source before this plan was written — this is the same rigor Phase 2h/3a applied to justify NOT adding packages; here the same rigor justifies adding them.

**Testability:** every new code path in `NotificationScheduler` is covered by a mocked-dual-channel test (`dexterous.com/flutter/local_notifications` + `flutter_timezone`) — enabled/disabled toggle, past-vs-future date skipping, timezone-detection-failure resilience — using the exact same `TestDefaultBinaryMessengerBinding` technique already proven in Phase 2h and Phase 3a. The no-mock test proves this Mac's actual `flutter test` environment (no platform implementation registered) doesn't crash the refresh.

**Placeholder scan:** every step has complete, literal code — no placeholders. The one intentional stub-like element (`AndroidInitializationSettings('@mipmap/ic_launcher')` referencing an icon asset that may not be a custom notification icon) matches the exact same spirit as Phase 3a's `_iOSWidgetName`/`_androidWidgetName` TODO placeholders — a reasonable default that doesn't block Dart-side correctness, explicitly nameable as a future polish item (a proper monochrome notification icon is an Android design guideline nicety, not a functional requirement) rather than a silent gap.

**Type consistency:** `NotificationScheduler.refreshNext7Days({required Profile profile, required AppSettings settings, DateTime? today})`'s signature is used identically in its own test file (Task 1) and at its `main.dart` call site (Task 2) — re-checked for drift. `_idFor(int dayOffset) => 1000 + dayOffset` is the single source of truth for notification IDs, referenced identically in both the cancel-loop and schedule-loop within `refreshNext7Days` — no duplicated ID logic to drift.
