# XuanLi Phase 3c — Widget Deep Link Routing Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build spec §9.6's widget deep link — "撳 widget → deep link `xuanli://day/2026-07-11`" — so a cold app launch via that URI opens directly to Tab C (月曆) with that specific day selected and its `DayCard` expanded, instead of the normal default (今日 tab, today's date).

**Scope boundary (read this first):** Like Phase 3a/3b, this builds the Dart-side routing logic plus the native manifest/plist registration text (both writable without Xcode/Android Studio), while genuinely NOT verifiable end-to-end (a real device/simulator tapping an actual home-screen widget) since neither is installed on this Mac. This plan ALSO deliberately scopes to the **cold-start case only** — parsing the deep link URI that launched the app from a fully-stopped state. It does NOT wire live re-navigation for a deep link received while the app is already running in the foreground/background (`AppLinks().uriLinkStream`, for the case where the OS reuses an existing app instance rather than cold-launching a new one). That warm-app case needs its own navigation-stack-aware design (what happens if the user is mid-interaction on Settings or a dialog when a new deep link arrives?) — a real design question, not a mechanical extension of this plan, and deferred as its own follow-up rather than rushed in here. There is currently no native widget to actually send either kind of link (Phase 3a's `WidgetDataBridge` writes data nothing reads yet), so cold-start-only coverage is not a meaningful loss of real-world capability today.

**Architecture:** `DeepLinkRouter` wraps `AppLinks()` (a new dependency, confirmed necessary and already added to `pubspec.yaml`) and exposes one method, `getInitialDayLink()`, that fetches the app's cold-start launch URI and parses it against the exact `xuanli://day/YYYY-MM-DD` shape spec §9.6 specifies, returning a `DateTime?` (null for "no link" or "link didn't match the expected shape" — both treated identically, since an app that was just cold-launched normally has no deep link at all, the overwhelmingly common case). `main.dart`'s bootstrap calls this once, threads the result through `TabShell` (new optional `deepLinkDate` parameter — when non-null, `TabShell` starts on Tab C instead of Tab A) into `CalendarScreen` (new optional `initialSelectedDate` parameter, used instead of "today" to seed which month/day is initially selected — completely separate from the existing `today` parameter, which continues to mean "what date is `DateTime.now()` for this render" and must keep controlling the grid's `isToday` highlighting regardless of which day is initially selected).

**Tech Stack:** `app_links: ^7.2.1` (new dependency — confirmed necessary, no existing package in this app covers URI-launch handling; already added to `pubspec.yaml`/resolved). Its `AppLinksPlatform.instance` is a settable static field (confirmed by reading the installed `app_links_platform_interface-2.0.4` source) — tests inject a fake `AppLinksPlatform` subclass directly rather than mocking a raw `MethodChannel`, a cleaner seam than `device_calendar`/`home_widget`/`flutter_local_notifications` needed, though the real default implementation (`AppLinksMethodChannel`) does still use a plain `MethodChannel('com.llfbandit.app_links/messages')` + `EventChannel('com.llfbandit.app_links/events')` under the hood, confirming (again) this whole family of plugins is uniformly testable without a real device.

---

## Scope decisions (don't re-litigate)

1. **Cold-start only** (see Scope boundary above) — `uriLinkStream` (the warm-app case) is explicitly out of scope for this plan.
2. **New dependency (`app_links`) is justified**, not decorative — no existing package in this app parses incoming launch URIs; this is the standard, actively-maintained package for exactly this purpose (confirmed via its pub.dev page and installed source before this plan was written).
3. **Malformed/non-matching URIs are silently treated as "no deep link"** (`getInitialDayLink()` returns `null`), not surfaced as an error — a user's normal app icon tap produces no deep link at all, which must be indistinguishable in behavior from a deep link that happened to fail to parse (both should just show the normal default 今日 tab). There's no user-facing "bad link" state to design for.
4. **`CalendarScreen`'s existing `today` parameter is untouched in meaning.** A new, separate `initialSelectedDate` parameter is added — conflating the two (e.g., overloading `today` to also mean "initially selected day") would break the grid's `isToday` gold-border highlighting whenever a deep link's date differs from the real current date, which is the whole point of a deep link (jumping to some OTHER day than today).
5. **Native manifest/plist registration is written but unverifiable.** Both `android/app/src/main/AndroidManifest.xml` (an `<intent-filter>` on `MainActivity` for the `xuanli://` scheme) and `ios/Runner/Info.plist` (`CFBundleURLTypes`) are edited with the standard, correct declarations for this — but actually tapping a `xuanli://day/...` link on a real device/simulator to confirm the OS routes it to this app at all cannot be tested without one, same caveat as Phase 3b's notification manifest work.

---

## File Structure

```
xuanli/
└── lib/
    ├── services/
    │   └── deep_link_router.dart        # NEW — DeepLinkRouter
    ├── screens/
    │   ├── tab_shell.dart               # MODIFY — deepLinkDate param
    │   └── calendar/
    │       └── calendar_screen.dart     # MODIFY — initialSelectedDate param
    └── main.dart                        # MODIFY — wire cold-start link into bootstrap
└── android/app/src/main/
    └── AndroidManifest.xml              # MODIFY — xuanli:// intent-filter
└── ios/Runner/
    └── Info.plist                       # MODIFY — CFBundleURLTypes
└── test/
    ├── services/
    │   └── deep_link_router_test.dart   # NEW
    ├── screens/
    │   ├── tab_shell_test.dart          # MODIFY
    │   └── calendar/
    │       └── calendar_screen_test.dart # MODIFY
    └── widget_test.dart                 # MODIFY — bootstrap wiring test
```

---

### Task 1: `DeepLinkRouter` — parse the cold-start launch URI

**Files:**
- Create: `lib/services/deep_link_router.dart`
- Create: `test/services/deep_link_router_test.dart`

- [ ] **Step 1: Write the failing tests**

Create `test/services/deep_link_router_test.dart`:

```dart
import 'package:app_links/app_links.dart';
import 'package:app_links_platform_interface/app_links_platform_interface.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xuanli/services/deep_link_router.dart';

/// 假嘅 [AppLinksPlatform]，直接控制 getInitialLink() 想要嘅 URI，
/// 唔使 mock 底層 MethodChannel（`AppLinksPlatform.instance` 本身
/// 就係一個特登開俾人 inject 嘅 static setter，呢個先係佢自己
/// 推薦嘅測試方式）。
class _FakeAppLinksPlatform extends AppLinksPlatform {
  final Uri? initialLink;
  _FakeAppLinksPlatform(this.initialLink);

  @override
  Future<Uri?> getInitialLink() async => initialLink;
}

void main() {
  tearDown(() {
    AppLinksPlatform.instance = AppLinksPlatform.instance;
  });

  group('DeepLinkRouter.getInitialDayLink', () {
    test('冇 launch URI（一般開 app 嘅情況）→ null', () async {
      AppLinksPlatform.instance = _FakeAppLinksPlatform(null);
      final router = DeepLinkRouter();
      expect(await router.getInitialDayLink(), isNull);
    });

    test('啱嘅 xuanli://day/2026-07-11 → DateTime(2026, 7, 11)', () async {
      AppLinksPlatform.instance =
          _FakeAppLinksPlatform(Uri.parse('xuanli://day/2026-07-11'));
      final router = DeepLinkRouter();
      expect(await router.getInitialDayLink(), DateTime(2026, 7, 11));
    });

    test('其他 scheme 嘅 URI（例如普通 http link）→ null', () async {
      AppLinksPlatform.instance =
          _FakeAppLinksPlatform(Uri.parse('https://example.com/day/2026-07-11'));
      final router = DeepLinkRouter();
      expect(await router.getInitialDayLink(), isNull);
    });

    test('啱嘅 scheme 但 host 唔啱（唔係 "day"）→ null', () async {
      AppLinksPlatform.instance =
          _FakeAppLinksPlatform(Uri.parse('xuanli://settings'));
      final router = DeepLinkRouter();
      expect(await router.getInitialDayLink(), isNull);
    });

    test('path 唔係啱嘅日期格式 → null，唔會 throw', () async {
      AppLinksPlatform.instance =
          _FakeAppLinksPlatform(Uri.parse('xuanli://day/not-a-date'));
      final router = DeepLinkRouter();
      expect(await router.getInitialDayLink(), isNull);
    });

    test('多過一個 path segment → null', () async {
      AppLinksPlatform.instance =
          _FakeAppLinksPlatform(Uri.parse('xuanli://day/2026-07-11/extra'));
      final router = DeepLinkRouter();
      expect(await router.getInitialDayLink(), isNull);
    });
  });
}
```

Note: the `tearDown`'s self-assignment (`AppLinksPlatform.instance = AppLinksPlatform.instance`) is a placeholder — `AppLinksPlatform` has no built-in "reset to default" method, and since each test explicitly sets its own fake instance before use, no reset is strictly required between tests for correctness (each test overwrites it fresh). If `flutter analyze` or a linter flags the self-assignment as a no-op, remove the `tearDown` entirely rather than working around the warning — it's not load-bearing.

### Step 2: Run tests to verify they fail

Run: `flutter test test/services/deep_link_router_test.dart`
Expected: FAIL — `Error: Not found: 'package:xuanli/services/deep_link_router.dart'`.

- [ ] **Step 3: Write the implementation**

Create `lib/services/deep_link_router.dart`:

```dart
import 'package:app_links/app_links.dart';

/// 解析 app 冷啟動嗰陣嘅 launch URI（spec §9.6：撳 widget → deep link
/// `xuanli://day/2026-07-11`）。淨係處理冷啟動嗰刻嘅 link——app 已經
/// 開緊嗰陣先收到嘅新 link（`AppLinks().uriLinkStream`）呢個 plan
/// 未處理，係刻意嘅 follow-up（見 plan 文件嘅 scope decision #1）。
///
/// 任何唔啱嘅 URI（冇 link、唔啱 scheme/host、日期格式錯）一律靜靜
/// 返 null，唔會 throw——普通開 app（冇經 widget）本身就冇 link，
/// 同「有 link 但格式錯」呢兩種情況對用戶嚟講應該一樣：跳去正常嘅
/// 今日 tab，冇分別。
class DeepLinkRouter {
  final AppLinks _appLinks;

  DeepLinkRouter({AppLinks? appLinks}) : _appLinks = appLinks ?? AppLinks();

  Future<DateTime?> getInitialDayLink() async {
    final uri = await _appLinks.getInitialLink();
    if (uri == null) return null;
    if (uri.scheme != 'xuanli' || uri.host != 'day') return null;
    if (uri.pathSegments.length != 1) return null;

    try {
      return DateTime.parse(uri.pathSegments.first);
    } on FormatException {
      return null;
    }
  }
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `flutter test test/services/deep_link_router_test.dart -v`
Expected: PASS (all 6 tests).

- [ ] **Step 5: `flutter analyze` clean, full suite check**

Run: `flutter analyze` → `No issues found!`
Run: `flutter test` → PASS (report the real total count).

- [ ] **Step 6: Commit**

```bash
git add lib/services/deep_link_router.dart test/services/deep_link_router_test.dart pubspec.yaml pubspec.lock
git commit -m "feat(deeplink): add DeepLinkRouter parsing cold-start xuanli://day/YYYY-MM-DD (spec §9.6)"
```

---

### Task 2: Wire into `TabShell`/`CalendarScreen`/bootstrap + native URI scheme registration

**Files:**
- Modify: `lib/screens/tab_shell.dart`
- Modify: `lib/screens/calendar/calendar_screen.dart`
- Modify: `lib/main.dart`
- Modify: `android/app/src/main/AndroidManifest.xml`
- Modify: `ios/Runner/Info.plist`
- Modify: `test/screens/tab_shell_test.dart`
- Modify: `test/screens/calendar/calendar_screen_test.dart`
- Modify: `test/widget_test.dart`

- [ ] **Step 1: Write the failing tests**

Read the current `test/screens/calendar/calendar_screen_test.dart` first. Add this new test, alongside the existing ones:

```dart
  testWidgets('initialSelectedDate 提供咗 → 一開始就顯示嗰個月、揀咗嗰日（唔係今日）', (tester) async {
    await tester.pumpWidget(wrap(CalendarScreen(
      profile: profile,
      today: DateTime(2026, 7, 11),
      initialSelectedDate: DateTime(2026, 8, 20),
    )));

    expect(find.textContaining('2026年8月'), findsOneWidget);
    expect(find.textContaining('8月20日'), findsOneWidget);
  });
```

Read the current `test/screens/tab_shell_test.dart` first. Add this new test:

```dart
  testWidgets('deepLinkDate 提供咗 → 一開始就喺月曆 tab（唔係今日 tab），CalendarScreen 收到嗰個日期', (tester) async {
    await tester.pumpWidget(wrap(TabShell(
      profile: _sampleProfile(),
      deepLinkDate: DateTime(2026, 8, 20),
    )));

    // 月曆 tab 應該已經係揀緊嗰個（bottom nav 嘅「月曆」着咗色，"今日" 冇）。
    final calendarScreenFinder = find.byType(CalendarScreen);
    expect(calendarScreenFinder, findsOneWidget);
    final calendarScreen = tester.widget<CalendarScreen>(calendarScreenFinder);
    expect(calendarScreen.initialSelectedDate, DateTime(2026, 8, 20));
  });
```

(Check this file's existing imports already include `package:xuanli/screens/calendar/calendar_screen.dart` — add it if not, since the test above references `CalendarScreen` directly.)

Read the current `test/widget_test.dart` first. Add these imports if not already present:
```dart
import 'package:app_links/app_links.dart';
import 'package:app_links_platform_interface/app_links_platform_interface.dart';
```

Add this fake class near the top of the file (module level, alongside any other test helpers already there):
```dart
class _FakeAppLinksPlatform extends AppLinksPlatform {
  final Uri? initialLink;
  _FakeAppLinksPlatform(this.initialLink);

  @override
  Future<Uri?> getInitialLink() async => initialLink;
}
```

Add this new test:

```dart
  testWidgets('XuanLiApp：冷啟動有 xuanli://day/... link → 直接去月曆 tab 揀咗嗰日',
      (tester) async {
    AppLinksPlatform.instance =
        _FakeAppLinksPlatform(Uri.parse('xuanli://day/2026-08-20'));
    addTearDown(() {
      AppLinksPlatform.instance = _FakeAppLinksPlatform(null);
    });

    await StorageService().savePrimaryProfile(_sampleProfileForBootstrapTest());

    await tester.pumpWidget(const XuanLiApp());
    await tester.pump();
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 50));
    });
    await tester.pumpAndSettle();

    final calendarScreenFinder = find.byType(CalendarScreen);
    expect(calendarScreenFinder, findsOneWidget);
    final calendarScreen = tester.widget<CalendarScreen>(calendarScreenFinder);
    expect(calendarScreen.initialSelectedDate, DateTime(2026, 8, 20));
  });
```

(Reuse the existing `_sampleProfileForBootstrapTest()` helper already in this file. Add `import 'package:xuanli/screens/calendar/calendar_screen.dart';` if not already present.)

- [ ] **Step 2: Run tests to verify they fail**

Run: `flutter test test/screens/calendar/calendar_screen_test.dart test/screens/tab_shell_test.dart test/widget_test.dart`
Expected: FAIL — `initialSelectedDate`/`deepLinkDate` parameters don't exist yet.

- [ ] **Step 3: Write the implementation**

In `lib/screens/calendar/calendar_screen.dart`, read the current file first. Change the widget class from:
```dart
class CalendarScreen extends StatefulWidget {
  final Profile profile;
  final DateTime? today;

  const CalendarScreen({super.key, required this.profile, this.today});
```
to:
```dart
class CalendarScreen extends StatefulWidget {
  final Profile profile;
  final DateTime? today;
  final DateTime? initialSelectedDate;

  const CalendarScreen({
    super.key,
    required this.profile,
    this.today,
    this.initialSelectedDate,
  });
```

Change `_CalendarScreenState.initState()` from:
```dart
  @override
  void initState() {
    super.initState();
    final today = _today;
    _displayedMonth = DateTime(today.year, today.month);
    _selectedDay = today.day;
    _initCalendarSync();
  }
```
to:
```dart
  @override
  void initState() {
    super.initState();
    final initial = widget.initialSelectedDate ?? _today;
    _displayedMonth = DateTime(initial.year, initial.month);
    _selectedDay = initial.day;
    _initCalendarSync();
  }
```

(`_today` — the getter used elsewhere for `isToday` grid highlighting — is untouched; only what seeds the INITIAL `_displayedMonth`/`_selectedDay` changes.)

In `lib/screens/tab_shell.dart`, read the current file first. Change the widget class from:
```dart
class TabShell extends StatefulWidget {
  final Profile profile;

  const TabShell({super.key, required this.profile});
```
to:
```dart
class TabShell extends StatefulWidget {
  final Profile profile;
  final DateTime? deepLinkDate;

  const TabShell({super.key, required this.profile, this.deepLinkDate});
```

Change `_TabShellState`'s index field from:
```dart
class _TabShellState extends State<TabShell> {
  int _index = 0;
```
to:
```dart
class _TabShellState extends State<TabShell> {
  late int _index = widget.deepLinkDate != null ? 2 : 0;
```

Change the `CalendarScreen` construction inside `build()`'s `IndexedStack` from:
```dart
                  CalendarScreen(profile: widget.profile),
```
to:
```dart
                  CalendarScreen(
                    profile: widget.profile,
                    initialSelectedDate: widget.deepLinkDate,
                  ),
```

In `lib/main.dart`, read the current file first (it already has `WidgetDataBridge`/`NotificationScheduler` wiring from Phase 3a/3b). Add the import:
```dart
import 'services/deep_link_router.dart';
```

Add a field to `_AppBootstrapState` to carry the parsed deep link date from `_run()` to `build()`:
```dart
class _AppBootstrapState extends State<_AppBootstrap> {
  late final Future<Profile?> _bootstrap = _run();
  DateTime? _deepLinkDate;
```

Change `_run()` — add the deep link fetch (this one IS awaited, unlike the widget/notification refreshes, since it must complete before `TabShell` is built with the right initial tab — but it's a single fast local platform call, not a loop of engine computation, so it doesn't meaningfully affect the "<2s cold start" budget the fire-and-forget calls were protecting):

```dart
  Future<Profile?> _run() async {
    await loadEngineData();
    final settings = await StorageService().loadSettings();
    themeModeController.value = settings.themeMode;
    _deepLinkDate = await DeepLinkRouter().getInitialDayLink();
    final profile = await StorageService().loadPrimaryProfile();
    if (profile != null) {
      unawaited(WidgetDataBridge().refreshNext7Days(profile));
      unawaited(NotificationScheduler()
          .refreshNext7Days(profile: profile, settings: settings));
    }
    return profile;
  }
```

Change `build()`'s `TabShell` construction from:
```dart
        return TabShell(profile: profile);
```
to:
```dart
        return TabShell(profile: profile, deepLinkDate: _deepLinkDate);
```

In `android/app/src/main/AndroidManifest.xml`, read the current file first (it already has the `RECEIVE_BOOT_COMPLETED` permission and two notification `<receiver>`s from Phase 3b). Add a new `<intent-filter>` inside the existing `<activity android:name=".MainActivity" ...>` element (as an ADDITIONAL intent-filter alongside the existing `MAIN`/`LAUNCHER` one, not replacing it):

```xml
            <intent-filter>
                <action android:name="android.intent.action.VIEW" />
                <category android:name="android.intent.category.DEFAULT" />
                <category android:name="android.intent.category.BROWSABLE" />
                <data android:scheme="xuanli" android:host="day" />
            </intent-filter>
```

In `ios/Runner/Info.plist`, read the current file first. Add this key/value pair as a new top-level entry inside the outer `<dict>` (anywhere among the existing `<key>`/`<value>` pairs — conventionally near `CFBundleIdentifier`, but exact position doesn't matter for plist correctness):

```xml
	<key>CFBundleURLTypes</key>
	<array>
		<dict>
			<key>CFBundleURLName</key>
			<string>com.xuanli.deeplink</string>
			<key>CFBundleURLSchemes</key>
			<array>
				<string>xuanli</string>
			</array>
		</dict>
	</array>
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `flutter test test/screens/calendar/calendar_screen_test.dart test/screens/tab_shell_test.dart test/widget_test.dart -v`
Expected: PASS (every test in all three files, old and new).

- [ ] **Step 5: `flutter analyze` clean, full suite check**

Run: `flutter analyze` → `No issues found!`
Run: `flutter test` → PASS (report the real total count).

Also re-run `test/screens/onboarding/onboarding_flow_test.dart` specifically — it builds a full, real `TabShell` and is this project's recurring regression-risk file whenever `TabShell`'s constructor/state changes.

Validate both native config files are well-formed: `xmllint --noout android/app/src/main/AndroidManifest.xml` and, if `plutil` is available on this Mac (it should be, it's a standard macOS command-line tool), `plutil -lint ios/Runner/Info.plist`.

- [ ] **Step 6: Commit**

```bash
git add lib/screens/tab_shell.dart lib/screens/calendar/calendar_screen.dart lib/main.dart android/app/src/main/AndroidManifest.xml ios/Runner/Info.plist test/screens/tab_shell_test.dart test/screens/calendar/calendar_screen_test.dart test/widget_test.dart
git commit -m "feat(deeplink): route cold-start xuanli://day/... to Calendar tab + register URI scheme natively (spec §9.6)"
```

---

### Task 3: Docs + final verification

**Files:**
- Modify: `CHANGELOG.md`
- Modify: `CLAUDE.md`

- [ ] **Step 1: Update `CHANGELOG.md`**

Read the current `CHANGELOG.md` first (changes go at the **top**). Add a new entry summarizing:
- `DeepLinkRouter` added (`lib/services/deep_link_router.dart`) — wraps the newly-added `app_links` package to parse `xuanli://day/YYYY-MM-DD` cold-start launch URIs per spec §9.6.
- `TabShell`/`CalendarScreen` gained `deepLinkDate`/`initialSelectedDate` parameters so a matched link opens directly to Tab C with that day selected; wired into `main.dart`'s bootstrap (this one IS awaited, unlike the fire-and-forget widget/notification refreshes, since the initial tab/day must be known before `TabShell` builds).
- Native URI-scheme registration added to `AndroidManifest.xml` (`<intent-filter>` for `xuanli://day/...` on `MainActivity`) and `Info.plist` (`CFBundleURLTypes`) — both well-formed-XML/plist-validated but, like every native-config addition since Phase 2h, unverifiable end-to-end without a real device/simulator.
- **Explicit scope boundary**: cold-start only — a deep link received while the app is already running (`AppLinks().uriLinkStream`) is NOT handled by this plan; that's a genuinely separate design problem (what happens to whatever screen/dialog is currently on top?) deferred to its own follow-up. There is also no native widget yet to actually send either kind of link (Phase 3a's data bridge writes JSON nothing reads), so this gap has no real-world impact today.

- [ ] **Step 2: Update `CLAUDE.md`'s Progress section**

Read the current `CLAUDE.md` first. The `- [ ] Phase 3 Widget（iOS/Android 小+中）+ 每日通知` line should **stay unchecked** — this plan is a further Dart-side slice (deep link routing), not the native widget UI itself, which remains entirely unbuilt pending Xcode/Android Studio. Do not check this box.

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
flutter test test/screens/calendar/calendar_screen_test.dart
flutter test test/widget_test.dart
xmllint --noout android/app/src/main/AndroidManifest.xml
plutil -lint ios/Runner/Info.plist
```

- [ ] **Step 4: Commit**

```bash
git add CHANGELOG.md CLAUDE.md
git commit -m "docs: update CHANGELOG for Phase 3c deep link routing"
```

Also `git add` the plan file itself (`docs/superpowers/plans/2026-07-29-xuanli-phase3c-deep-link-routing.md`, currently untracked), following this project's established convention.

---

## Self-Review Notes

**Spec coverage:** covers spec §9.6's deep link requirement exactly for the cold-start case — `xuanli://day/2026-07-11` opens directly to that day in Tab C. Not covered (explicitly, not silently): warm-app/already-running deep link handling (scope decision #1), and — like every native-config change since Phase 2h — real on-device URI-scheme dispatch, which can't be verified without hardware/simulator.

**Justified new dependency:** `app_links` is the only new package this plan adds; confirmed no existing dependency already covers incoming-URI parsing before adding it.

**Testability:** `DeepLinkRouter`'s tests use `AppLinksPlatform.instance` direct fake-injection (a cleaner seam than `MethodChannel` mocking, confirmed available by reading the installed platform-interface source). `TabShell`/`CalendarScreen`'s new parameters are tested via plain widget construction (no platform mocking needed — they're just Dart parameters). The bootstrap test reuses the same fake-platform-injection technique at the `AppLinksPlatform.instance` level, consistent with `DeepLinkRouter`'s own test file.

**Placeholder scan:** every step has complete, literal code. The `tearDown`'s self-assignment placeholder in Task 1's test is explicitly flagged as removable if a linter objects — not a hidden gap, a documented judgment call about whether it's needed at all.

**Type consistency:** `DeepLinkRouter.getInitialDayLink()`'s `Future<DateTime?>` return type flows unchanged through `_AppBootstrapState._deepLinkDate` → `TabShell.deepLinkDate` → `CalendarScreen.initialSelectedDate` — same nullable `DateTime` the whole way, no silent type coercion. `CalendarScreen`'s pre-existing `today` parameter's meaning and all its existing call sites (tests, `TabShell`'s own construction) are unchanged — re-checked for drift.
