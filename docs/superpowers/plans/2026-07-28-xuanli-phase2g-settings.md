# XuanLi Phase 2g — 設定頁 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build spec §9.8's 設定頁 (settings screen) — 深色模式（跟系統/常開/常關）、每朝通知時間/開關、JSON 匯出/匯入、重新做 onboarding、免責聲明全文、關於 — and wire a persistent settings entry point into `TabShell` (a small ⚙ icon shared by all 3 tabs, per Stephanie's confirmed scope decision). This is the last piece of Phase 2's `- [ ] 設定頁 + JSON 匯出入 + 深色模式` checklist item in `CLAUDE.md`.

**Architecture:** A new `AppSettings` model (`lib/models/settings.dart`) persists via `StorageService` (extended, same `shared_preferences` JSON-string pattern already used for `Profile`). Dark mode needs to take effect **immediately**, app-wide, the instant the user changes it in settings — not just on next cold start — so it's backed by a small global `ValueNotifier<ThemeMode>` (`lib/services/theme_mode_controller.dart`) that `main.dart`'s `XuanLiApp` listens to via `ValueListenableBuilder`, and that `SettingsScreen` writes to directly. `SettingsScreen` itself is a standalone screen (no required constructor params — it loads/saves via `StorageService` internally), reached by tapping a new ⚙ icon added to `TabShell`'s top bar (visible above all 3 tabs).

## Scope decisions already confirmed with Stephanie (don't re-litigate)

1. **All 6 spec §9.8 items ship in this one plan**, including JSON export/import — but export/import follow the exact same stub convention already established for Tab B's "加入我嘅日曆" and the combo page's share icon (`ScaffoldMessenger.showSnackBar` reading "‹feature› — 之後有 device 先驗證"), because the actual OS share-sheet (`share_plus`) and file-picker (`file_picker`) integrations need real device testing this Mac cannot do, and per CLAUDE.md's DoD, nothing ships un-verifiable. **No new packages are added in this plan.** Real `share_plus`/`file_picker` wiring is deferred to a future device-testing sub-plan, same as `device_calendar`.
2. **Notification section is UI + storage only, no real scheduling.** Phase 3 (`flutter_local_notifications` wiring, `zonedSchedule`) isn't built yet — this plan adds a switch + time picker that persists the user's preference (default: on, 07:30, matching spec §9.7's stated default) so Phase 3 has a ready-made preference to consume; it does **not** call any notification-scheduling API.
3. **Settings entry point:** a small ⚙ icon added to `TabShell`'s top bar, shared by all 3 tabs (今日/我想做/月曆) — not duplicated per-screen, not a 4th bottom tab (spec §2 decision #11 locks the tab bar at 3).

---

## File Structure

```
xuanli/
└── lib/
    ├── models/
    │   └── settings.dart                    # NEW — AppSettings model
    ├── services/
    │   ├── storage_service.dart             # MODIFY — loadSettings/saveSettings/clearProfiles
    │   └── theme_mode_controller.dart       # NEW — global ValueNotifier<ThemeMode>
    ├── screens/
    │   ├── tab_shell.dart                   # MODIFY — add ⚙ top bar
    │   └── settings/
    │       └── settings_screen.dart         # NEW — SettingsScreen
    └── main.dart                            # MODIFY — theme-mode-reactive XuanLiApp
└── test/
    ├── services/
    │   └── storage_service_test.dart        # MODIFY — settings/clearProfiles tests
    ├── widget_test.dart                     # MODIFY — bootstrap loads saved theme mode
    ├── screens/
    │   ├── tab_shell_test.dart               # MODIFY — ⚙ icon test, add SharedPreferences mock
    │   └── settings/
    │       └── settings_screen_test.dart    # NEW
```

---

### Task 1: `lib/models/settings.dart` + `StorageService` persistence

**Files:**
- Create: `lib/models/settings.dart`
- Modify: `lib/services/storage_service.dart`
- Modify: `test/services/storage_service_test.dart`

- [ ] **Step 1: Write the failing test**

Add to `test/services/storage_service_test.dart` — read the current file first, then add these imports at the top alongside the existing ones:

```dart
import 'package:flutter/material.dart' show ThemeMode;
import 'package:xuanli/models/settings.dart';
```

Add this new `group` inside `main()`, alongside the existing `group('StorageService', ...)`:

```dart
  group('StorageService — settings', () {
    test('loadSettings() 喺未存過時返回 AppSettings.defaults（跟系統・通知開・07:30）', () async {
      final result = await StorageService().loadSettings();
      expect(result.themeMode, ThemeMode.system);
      expect(result.notificationsEnabled, isTrue);
      expect(result.notificationHour, 7);
      expect(result.notificationMinute, 30);
    });

    test('saveSettings() 之後 loadSettings() 攞返同一組設定', () async {
      final service = StorageService();
      await service.saveSettings(const AppSettings(
        themeMode: ThemeMode.dark,
        notificationsEnabled: false,
        notificationHour: 22,
        notificationMinute: 15,
      ));

      final loaded = await service.loadSettings();
      expect(loaded.themeMode, ThemeMode.dark);
      expect(loaded.notificationsEnabled, isFalse);
      expect(loaded.notificationHour, 22);
      expect(loaded.notificationMinute, 15);
    });

    test('copyWith() 淨係改指定欄位，其餘保留', () async {
      const original = AppSettings(
        themeMode: ThemeMode.system,
        notificationsEnabled: true,
        notificationHour: 7,
        notificationMinute: 30,
      );
      final updated = original.copyWith(themeMode: ThemeMode.light);
      expect(updated.themeMode, ThemeMode.light);
      expect(updated.notificationsEnabled, isTrue);
      expect(updated.notificationHour, 7);
      expect(updated.notificationMinute, 30);
    });
  });

  group('StorageService — clearProfiles', () {
    test('clearProfiles() 之後 loadPrimaryProfile() 返回 null', () async {
      final service = StorageService();
      await service.savePrimaryProfile(_sampleProfile());
      expect(await service.loadPrimaryProfile(), isNotNull);

      await service.clearProfiles();
      expect(await service.loadPrimaryProfile(), isNull);
    });
  });
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/services/storage_service_test.dart`
Expected: FAIL — `Error: Not found: 'package:xuanli/models/settings.dart'` and `The method 'loadSettings' isn't defined for the class 'StorageService'`.

- [ ] **Step 3: Write the implementation**

Create `lib/models/settings.dart`:

```dart
import 'package:flutter/material.dart' show ThemeMode;

/// 用戶設定（spec §9.8）：深色模式跟隨方式、每朝通知開關/時間。
/// 同 [Profile] 一樣用 `shared_preferences` 存做 JSON string——見
/// `StorageService.loadSettings()`/`saveSettings()`。
///
/// [notificationHour]/[notificationMinute] 淨係「用戶想要嘅時間」呢個
/// 偏好本身；Phase 2g 唔會真係用呢兩個值去排通知（`flutter_local_
/// notifications` 嘅 `zonedSchedule` 屬於 Phase 3 先做嘅嘢），淨係存低
/// 畀 Phase 3 起嗰陣讀。
class AppSettings {
  final ThemeMode themeMode;
  final bool notificationsEnabled;
  final int notificationHour;
  final int notificationMinute;

  const AppSettings({
    required this.themeMode,
    required this.notificationsEnabled,
    required this.notificationHour,
    required this.notificationMinute,
  });

  /// 未存過任何設定時嘅預設值——spec §9.7 講嘅預設 07:30、通知預設開。
  static const defaults = AppSettings(
    themeMode: ThemeMode.system,
    notificationsEnabled: true,
    notificationHour: 7,
    notificationMinute: 30,
  );

  AppSettings copyWith({
    ThemeMode? themeMode,
    bool? notificationsEnabled,
    int? notificationHour,
    int? notificationMinute,
  }) {
    return AppSettings(
      themeMode: themeMode ?? this.themeMode,
      notificationsEnabled: notificationsEnabled ?? this.notificationsEnabled,
      notificationHour: notificationHour ?? this.notificationHour,
      notificationMinute: notificationMinute ?? this.notificationMinute,
    );
  }

  Map<String, dynamic> toJson() => {
        'themeMode': themeMode.name,
        'notificationsEnabled': notificationsEnabled,
        'notificationHour': notificationHour,
        'notificationMinute': notificationMinute,
      };

  factory AppSettings.fromJson(Map<String, dynamic> json) => AppSettings(
        themeMode: ThemeMode.values.byName(json['themeMode'] as String),
        notificationsEnabled: json['notificationsEnabled'] as bool,
        notificationHour: json['notificationHour'] as int,
        notificationMinute: json['notificationMinute'] as int,
      );
}
```

In `lib/services/storage_service.dart`, add the import:
```dart
import '../models/settings.dart';
```

Add these members to the `StorageService` class (alongside the existing `_profilesKey`/methods):

```dart
  static const _settingsKey = 'xuanli_settings';

  Future<AppSettings> loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_settingsKey);
    if (raw == null) return AppSettings.defaults;
    return AppSettings.fromJson(json.decode(raw) as Map<String, dynamic>);
  }

  Future<void> saveSettings(AppSettings settings) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_settingsKey, json.encode(settings.toJson()));
  }

  /// 「重新做 Onboarding」用（spec §9.8）：清走已存嘅 profile，等
  /// [_AppBootstrap]／[SettingsScreen] 之後嘅 `loadPrimaryProfile()`
  /// 返回 null，跳返去 onboarding。唔清 settings（深色模式/通知偏好
  /// 呢啲同「你係邊個」冇關，用戶冇必要因為重做 onboarding 而丟失）。
  Future<void> clearProfiles() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_profilesKey);
  }
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/services/storage_service_test.dart -v`
Expected: PASS (all tests, old + 4 new).

- [ ] **Step 5: `flutter analyze` clean**

Run: `flutter analyze` → `No issues found!`

- [ ] **Step 6: Commit**

```bash
git add lib/models/settings.dart lib/services/storage_service.dart test/services/storage_service_test.dart
git commit -m "feat(settings): add AppSettings model + storage persistence"
```

---

### Task 2: `lib/services/theme_mode_controller.dart` + `main.dart` wiring

**Files:**
- Create: `lib/services/theme_mode_controller.dart`
- Modify: `lib/main.dart`
- Modify: `test/widget_test.dart`

- [ ] **Step 1: Write the failing test**

Read the current `test/widget_test.dart` first. Add these imports at the top alongside the existing ones:

```dart
import 'dart:convert';

import 'package:xuanli/models/settings.dart';
import 'package:xuanli/services/theme_mode_controller.dart';
```

Add this new test inside `main()`, alongside the existing `testWidgets` block:

```dart
  testWidgets(
      'XuanLiApp：bootstrap 會由 storage 讀返已存嘅深色模式設定，更新 themeModeController',
      (tester) async {
    await StorageService().saveSettings(const AppSettings(
      themeMode: ThemeMode.dark,
      notificationsEnabled: true,
      notificationHour: 7,
      notificationMinute: 30,
    ));

    await tester.pumpWidget(const XuanLiApp());
    await tester.pump();
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 50));
    });
    await tester.pump();

    expect(themeModeController.value, ThemeMode.dark);
  });
```

You'll also need `import 'package:xuanli/services/storage_service.dart';` and `import 'package:flutter/material.dart' show ThemeMode;` if not already present in the file (check first — `flutter/material.dart` is almost certainly already imported for `MaterialApp`/`Widget` etc., so you likely only need to add `show ThemeMode` awareness via the existing wildcard import, not a second import line).

Add a `tearDown` to reset the global singleton between tests in this file (order-independence — `themeModeController` is a module-level singleton, so a value set by this new test must not leak into the file's other test if tests ever get reordered):

```dart
  tearDown(() {
    themeModeController.value = ThemeMode.system;
  });
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/widget_test.dart`
Expected: FAIL — `Error: Not found: 'package:xuanli/services/theme_mode_controller.dart'` (and `AppSettings`/`saveSettings` not found).

- [ ] **Step 3: Write the implementation**

Create `lib/services/theme_mode_controller.dart`:

```dart
import 'package:flutter/material.dart';

/// 全局深色模式 state（spec §9.8：跟系統/常開/常關）。[XuanLiApp] 監聽
/// 呢個 value 嚟決定 `MaterialApp.themeMode`；[SettingsScreen] 改呢個
/// value 即刻全 app 生效，唔使重新 bootstrap。一個 module-level
/// singleton——呢個 app 淨係呢一個 cross-cutting value 需要咁做，冇必要
/// 因為佢一個引入成套 state management package。
final ValueNotifier<ThemeMode> themeModeController = ValueNotifier(ThemeMode.system);
```

Modify `lib/main.dart`. Read the current file first. Add the import:
```dart
import 'services/theme_mode_controller.dart';
```

Change `XuanLiApp.build()` from:
```dart
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
```
to:
```dart
  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: themeModeController,
      builder: (context, mode, _) {
        return MaterialApp(
          title: '玄曆',
          debugShowCheckedModeBanner: false,
          theme: XuanLiTheme.light(),
          darkTheme: XuanLiTheme.dark(),
          themeMode: mode,
          home: const _AppBootstrap(),
        );
      },
    );
  }
```

Change `_AppBootstrapState._run()` from:
```dart
  Future<Profile?> _run() async {
    await loadEngineData();
    return StorageService().loadPrimaryProfile();
  }
```
to:
```dart
  Future<Profile?> _run() async {
    await loadEngineData();
    final settings = await StorageService().loadSettings();
    themeModeController.value = settings.themeMode;
    return StorageService().loadPrimaryProfile();
  }
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/widget_test.dart -v`
Expected: PASS (both tests — the pre-existing onboarding-routing test and the new theme-mode test).

- [ ] **Step 5: `flutter analyze` clean, full suite check**

Run: `flutter analyze` → `No issues found!`
Run: `flutter test` → PASS (report the real total count you observe).

- [ ] **Step 6: Commit**

```bash
git add lib/services/theme_mode_controller.dart lib/main.dart test/widget_test.dart
git commit -m "feat(settings): wire app-wide ThemeMode controller into XuanLiApp bootstrap"
```

---

### Task 3: `lib/screens/settings/settings_screen.dart` — `SettingsScreen`

**Files:**
- Create: `lib/screens/settings/settings_screen.dart`
- Create: `test/screens/settings/settings_screen_test.dart`

Per spec §9.8: 深色模式（跟系統/常開/常關）three-way selector, 每朝通知開關 + 時間 picker (UI/storage only, no real scheduling), JSON 匯出/匯入 (stub, per confirmed scope), 重新做 onboarding (confirm dialog → clear profile → navigate to fresh `OnboardingFlow`), 免責聲明全文 + 關於 (dialogs).

- [ ] **Step 1: Write the failing test**

Create `test/screens/settings/settings_screen_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:xuanli/models/profile.dart';
import 'package:xuanli/screens/onboarding/onboarding_flow.dart';
import 'package:xuanli/screens/settings/settings_screen.dart';
import 'package:xuanli/services/storage_service.dart';
import 'package:xuanli/services/theme_mode_controller.dart';
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
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  tearDown(() {
    themeModeController.value = ThemeMode.system;
  });

  Widget wrap(Widget child) =>
      MaterialApp(theme: XuanLiTheme.light(), home: child);

  testWidgets('顯示三個外觀選項＋通知開關（預設開・07:30）＋資料/關於嘅動作列', (tester) async {
    await tester.pumpWidget(wrap(const SettingsScreen()));
    await tester.pumpAndSettle();

    expect(find.text('跟系統'), findsOneWidget);
    expect(find.text('常開'), findsOneWidget);
    expect(find.text('常關'), findsOneWidget);
    expect(find.text('07:30'), findsOneWidget);
    expect(find.text('匯出 JSON'), findsOneWidget);
    expect(find.text('匯入 JSON'), findsOneWidget);
    expect(find.text('重新做 Onboarding'), findsOneWidget);
    expect(find.text('免責聲明全文'), findsOneWidget);
    expect(find.text('關於玄曆'), findsOneWidget);
  });

  testWidgets('撳「常開」會即刻更新 themeModeController 並存落 storage', (tester) async {
    await tester.pumpWidget(wrap(const SettingsScreen()));
    await tester.pumpAndSettle();

    await tester.tap(find.text('常開'));
    await tester.pumpAndSettle();

    expect(themeModeController.value, ThemeMode.dark);
    final saved = await StorageService().loadSettings();
    expect(saved.themeMode, ThemeMode.dark);
  });

  testWidgets('關咗「每朝推送」，推送時間列會消失；開返會再顯示', (tester) async {
    await tester.pumpWidget(wrap(const SettingsScreen()));
    await tester.pumpAndSettle();

    expect(find.text('推送時間'), findsOneWidget);

    await tester.tap(find.byType(Switch));
    await tester.pumpAndSettle();
    expect(find.text('推送時間'), findsNothing);

    final saved = await StorageService().loadSettings();
    expect(saved.notificationsEnabled, isFalse);

    await tester.tap(find.byType(Switch));
    await tester.pumpAndSettle();
    expect(find.text('推送時間'), findsOneWidget);
  });

  testWidgets('撳「匯出 JSON」／「匯入 JSON」會顯示 stub SnackBar', (tester) async {
    await tester.pumpWidget(wrap(const SettingsScreen()));
    await tester.pumpAndSettle();

    await tester.tap(find.text('匯出 JSON'));
    await tester.pump();
    expect(find.textContaining('之後有 device 先驗證'), findsOneWidget);

    await tester.pumpAndSettle();
    await tester.tap(find.text('匯入 JSON'));
    await tester.pump();
    expect(find.textContaining('之後有 device 先驗證'), findsOneWidget);
  });

  testWidgets('撳「重新做 Onboarding」→ 確定：清咗 profile 並跳去 OnboardingFlow', (tester) async {
    await StorageService().savePrimaryProfile(_sampleProfile());

    await tester.pumpWidget(wrap(const SettingsScreen()));
    await tester.pumpAndSettle();

    await tester.tap(find.text('重新做 Onboarding'));
    await tester.pumpAndSettle();
    expect(find.text('確定'), findsOneWidget);

    await tester.tap(find.text('確定'));
    await tester.pumpAndSettle();

    expect(find.byType(OnboardingFlow), findsOneWidget);
    expect(await StorageService().loadPrimaryProfile(), isNull);
  });

  testWidgets('撳「重新做 Onboarding」→ 取消：留喺設定頁，profile 冇被清', (tester) async {
    await StorageService().savePrimaryProfile(_sampleProfile());

    await tester.pumpWidget(wrap(const SettingsScreen()));
    await tester.pumpAndSettle();

    await tester.tap(find.text('重新做 Onboarding'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('取消'));
    await tester.pumpAndSettle();

    expect(find.byType(SettingsScreen), findsOneWidget);
    expect(await StorageService().loadPrimaryProfile(), isNotNull);
  });

  testWidgets('撳「免責聲明全文」／「關於玄曆」會彈 dialog，撳「知道喇」會關返', (tester) async {
    await tester.pumpWidget(wrap(const SettingsScreen()));
    await tester.pumpAndSettle();

    await tester.tap(find.text('免責聲明全文'));
    await tester.pumpAndSettle();
    expect(find.textContaining('僅供參考'), findsOneWidget);
    await tester.tap(find.text('知道喇'));
    await tester.pumpAndSettle();
    expect(find.textContaining('僅供參考'), findsNothing);

    await tester.tap(find.text('關於玄曆'));
    await tester.pumpAndSettle();
    expect(find.textContaining('版本'), findsOneWidget);
    await tester.tap(find.text('知道喇'));
    await tester.pumpAndSettle();
    expect(find.textContaining('版本'), findsNothing);
  });

  testWidgets('撳返頭嘅 ‹ 會 pop 返上一頁', (tester) async {
    await tester.pumpWidget(wrap(Builder(builder: (context) {
      return Scaffold(
        body: Center(
          child: ElevatedButton(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const SettingsScreen()),
            ),
            child: const Text('open'),
          ),
        ),
      );
    })));

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.byType(SettingsScreen), findsOneWidget);

    await tester.tap(find.text('‹'));
    await tester.pumpAndSettle();
    expect(find.text('open'), findsOneWidget);
    expect(find.byType(SettingsScreen), findsNothing);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/screens/settings/settings_screen_test.dart`
Expected: FAIL — `Error: Not found: 'package:xuanli/screens/settings/settings_screen.dart'`.

- [ ] **Step 3: Write the implementation**

Create `lib/screens/settings/settings_screen.dart`:

```dart
import 'package:flutter/material.dart';

import '../../models/settings.dart';
import '../../services/storage_service.dart';
import '../../services/theme_mode_controller.dart';
import '../../theme/xuanli_theme.dart';
import '../onboarding/onboarding_flow.dart';

/// 設定頁（spec §9.8）：深色模式、每朝通知偏好（UI/storage only，唔真
/// 係排通知——Phase 3 先起 `flutter_local_notifications` 排程）、JSON
/// 匯出/匯入（stub，同 Tab B 日曆整合一樣要等有 device 先做真整合）、
/// 重新做 onboarding、免責聲明、關於。冇 required constructor 參數——
/// 由 `TabShell` 嘅 ⚙ icon 撳入嚟，自己內部靠 [StorageService] 讀寫。
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  AppSettings? _settings;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final settings = await StorageService().loadSettings();
    if (!mounted) return;
    setState(() => _settings = settings);
  }

  Future<void> _save(AppSettings next) async {
    await StorageService().saveSettings(next);
    if (!mounted) return;
    setState(() => _settings = next);
  }

  Future<void> _setThemeMode(ThemeMode mode) async {
    themeModeController.value = mode;
    await _save(_settings!.copyWith(themeMode: mode));
  }

  Future<void> _setNotificationsEnabled(bool enabled) async {
    await _save(_settings!.copyWith(notificationsEnabled: enabled));
  }

  Future<void> _pickNotificationTime() async {
    final current = _settings!;
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: current.notificationHour, minute: current.notificationMinute),
    );
    if (picked == null) return;
    await _save(current.copyWith(notificationHour: picked.hour, notificationMinute: picked.minute));
  }

  void _stub(String feature) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$feature — 之後有 device 先驗證')),
    );
  }

  Future<void> _confirmRedoOnboarding() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('重新做 Onboarding'),
        content: const Text('呢個動作會清除你而家嘅命理檔案，需要重新輸入出生資料。確定要繼續？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('確定'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await StorageService().clearProfiles();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const OnboardingFlow()),
      (route) => false,
    );
  }

  void _showDisclaimer() {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('免責聲明'),
        content: const SingleChildScrollView(
          child: Text(
            '玄曆所有推薦內容（包括命理分、宜忌、活動建議、行事曆提示等）都係基於傳統曆法同你嘅個人命理'
            '資料自動生成，僅供參考、帶少少玄學生活趣味，並唔代表任何形式嘅專業意見。\n\n'
            '健康、法律、財務等重要決定，請以專業人士（醫生、律師、持牌顧問等）意見為準——玄曆嘅健康'
            '相關內容只會話你邊一日狀態較順，唔會亦唔應該被理解為「唔好睇醫生」嘅建議；財務／投資相關'
            '內容亦只提供宜忌方向，唔構成具體買賣建議。\n\n'
            '你嘅出生資料同命理檔案全部只存喺你部機度，玄曆唔會上傳、分享或者用嚟做任何其他用途。',
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

  void _showAbout() {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('關於玄曆'),
        content: const Text(
          '玄曆 XuanLi\n版本 1.0.0\n\n'
          '中國傳統擇日 × 個人八字五行 × 紫微 × MBTI，全離線運作，你嘅出生資料唔會離開部機。',
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

  @override
  Widget build(BuildContext context) {
    final colors = context.xuanliColors;
    final settings = _settings;
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(colors),
            Expanded(
              child: settings == null
                  ? const Center(child: CircularProgressIndicator())
                  : ListView(
                      padding: const EdgeInsets.fromLTRB(18, 4, 18, 24),
                      children: [
                        _sectionLabel(colors, '外觀'),
                        _themeModeRow(colors, settings),
                        const SizedBox(height: 18),
                        _sectionLabel(colors, '每朝通知'),
                        _notificationCard(colors, settings),
                        const SizedBox(height: 18),
                        _sectionLabel(colors, '資料'),
                        _actionTile(colors, '匯出 JSON', () => _stub('匯出（分享）')),
                        _actionTile(colors, '匯入 JSON', () => _stub('匯入（揀檔）')),
                        _actionTile(colors, '重新做 Onboarding', _confirmRedoOnboarding),
                        const SizedBox(height: 18),
                        _sectionLabel(colors, '關於'),
                        _actionTile(colors, '免責聲明全文', _showDisclaimer),
                        _actionTile(colors, '關於玄曆', _showAbout),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(XuanLiColors colors) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 6, 10, 6),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.of(context).pop(),
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: Text('‹', style: TextStyle(fontSize: 22, color: colors.ink60)),
            ),
          ),
          const SizedBox(width: 4),
          Text(
            '設定',
            style: TextStyle(
              fontFamily: XuanLiFonts.serif,
              fontWeight: FontWeight.w700,
              fontSize: 16,
              color: colors.ink,
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionLabel(XuanLiColors colors, String label) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 0, 0, 8),
      child: Text(
        label,
        style: TextStyle(fontSize: 11, letterSpacing: 2, fontWeight: FontWeight.w700, color: colors.gold),
      ),
    );
  }

  Widget _themeModeRow(XuanLiColors colors, AppSettings settings) {
    Widget chip(String label, ThemeMode mode) {
      final selected = settings.themeMode == mode;
      return Expanded(
        child: GestureDetector(
          onTap: () => _setThemeMode(mode),
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 3),
            padding: const EdgeInsets.symmetric(vertical: 10),
            decoration: BoxDecoration(
              color: selected ? colors.gold : colors.cardSurface,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: selected ? colors.gold : colors.ink12),
            ),
            alignment: Alignment.center,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w400,
                color: selected ? colors.ink : colors.ink60,
              ),
            ),
          ),
        ),
      );
    }

    return Row(
      children: [
        chip('跟系統', ThemeMode.system),
        chip('常開', ThemeMode.dark),
        chip('常關', ThemeMode.light),
      ],
    );
  }

  Widget _notificationCard(XuanLiColors colors, AppSettings settings) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: colors.cardSurface,
        borderRadius: BorderRadius.circular(XuanLiRadii.card),
      ),
      child: Column(
        children: [
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: Text('每朝推送', style: TextStyle(fontSize: 13, color: colors.ink)),
            value: settings.notificationsEnabled,
            activeColor: colors.gold,
            onChanged: _setNotificationsEnabled,
          ),
          if (settings.notificationsEnabled)
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text('推送時間', style: TextStyle(fontSize: 13, color: colors.ink)),
              trailing: Text(
                '${settings.notificationHour.toString().padLeft(2, '0')}:'
                '${settings.notificationMinute.toString().padLeft(2, '0')}',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: colors.gold),
              ),
              onTap: _pickNotificationTime,
            ),
        ],
      ),
    );
  }

  Widget _actionTile(XuanLiColors colors, String label, VoidCallback onTap) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: colors.cardSurface,
        borderRadius: BorderRadius.circular(XuanLiRadii.card),
      ),
      child: ListTile(
        title: Text(label, style: TextStyle(fontSize: 13, color: colors.ink)),
        trailing: Text('›', style: TextStyle(fontSize: 16, color: colors.ink30)),
        onTap: onTap,
      ),
    );
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/screens/settings/settings_screen_test.dart -v`
Expected: PASS (all 8 tests).

- [ ] **Step 5: `flutter analyze` clean, full suite check**

Run: `flutter analyze` → `No issues found!`
Run: `flutter test` → PASS (report the real total count you observe).

- [ ] **Step 6: Commit**

```bash
git add lib/screens/settings/settings_screen.dart test/screens/settings/settings_screen_test.dart
git commit -m "feat(settings): add SettingsScreen (深色模式/通知偏好/JSON匯出入 stub/重做onboarding/免責聲明/關於)"
```

---

### Task 4: Wire the ⚙ settings icon into `TabShell`

**Files:**
- Modify: `lib/screens/tab_shell.dart`
- Modify: `test/screens/tab_shell_test.dart`

- [ ] **Step 1: Write the failing test**

Read the current `test/screens/tab_shell_test.dart` first. It currently has **no** `SharedPreferences.setMockInitialValues` setup (it never touches `StorageService`) — you need to add one, since `SettingsScreen` (now reachable from this screen) calls `StorageService().loadSettings()` internally. Add the import and a `setUp`:

```dart
import 'package:shared_preferences/shared_preferences.dart';
```

```dart
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });
```

(Add this alongside the existing `setUpAll` — `setUp` runs before each test, `setUpAll` runs once; both can coexist in the same `main()`.)

Add this new test:

```dart
  testWidgets('撳右上角 ⚙ 會去 SettingsScreen', (tester) async {
    await tester.pumpWidget(wrap(TabShell(profile: _sampleProfile())));

    await tester.tap(find.text('⚙'));
    await tester.pumpAndSettle();

    expect(find.byType(SettingsScreen), findsOneWidget);
  });
```

Add the import for `SettingsScreen`:
```dart
import 'package:xuanli/screens/settings/settings_screen.dart';
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/screens/tab_shell_test.dart`
Expected: FAIL — `find.text('⚙')` finds nothing (no such widget yet).

- [ ] **Step 3: Write the implementation**

In `lib/screens/tab_shell.dart`, read the current file first. Add the import:
```dart
import 'settings/settings_screen.dart';
```

Change `_TabShellState.build()` from:
```dart
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _index,
        children: [
          TodayScreen(profile: widget.profile),
          ActivityScreen(profile: widget.profile),
          CalendarScreen(profile: widget.profile),
        ],
      ),
      bottomNavigationBar: _TabBar(
        selectedIndex: _index,
        tabs: _tabs,
        onSelect: (i) => setState(() => _index = i),
      ),
    );
  }
```
to:
```dart
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          SafeArea(
            bottom: false,
            child: _SettingsBar(
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const SettingsScreen()),
              ),
            ),
          ),
          Expanded(
            child: IndexedStack(
              index: _index,
              children: [
                TodayScreen(profile: widget.profile),
                ActivityScreen(profile: widget.profile),
                CalendarScreen(profile: widget.profile),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: _TabBar(
        selectedIndex: _index,
        tabs: _tabs,
        onSelect: (i) => setState(() => _index = i),
      ),
    );
  }
```

Add a new `_SettingsBar` widget class (place it near `_TabBar`, e.g. right after `_TabShellState`'s closing brace):

```dart
class _SettingsBar extends StatelessWidget {
  final VoidCallback onTap;

  const _SettingsBar({required this.onTap});

  @override
  Widget build(BuildContext context) {
    final colors = context.xuanliColors;
    return Align(
      alignment: Alignment.centerRight,
      child: GestureDetector(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(10, 6, 14, 4),
          child: Text('⚙', style: TextStyle(fontSize: 20, color: colors.ink60)),
        ),
      ),
    );
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/screens/tab_shell_test.dart -v`
Expected: PASS (all tests, including the new one).

- [ ] **Step 5: `flutter analyze` clean, full suite check**

Run: `flutter analyze` → `No issues found!`
Run: `flutter test` → PASS (report the real total count you observe).

Also re-run `test/screens/onboarding/onboarding_flow_test.dart` specifically — it drives the full onboarding flow ending at a real, fully-built `TabShell` (which `IndexedStack` eagerly builds all children of); confirm the new `_SettingsBar` addition doesn't break it. This exact class of "wiring change breaks a sibling test" regression has recurred multiple times in this project's Phase 2 work — don't skip this check.

- [ ] **Step 6: Attempt a live device run (expected to be unavailable — report honestly either way)**

Run: `flutter devices`. This Mac has no Xcode Simulator, no Android emulator, and no `macos`/`web` platform scaffolding — confirm and report plainly rather than skipping this step silently, matching every prior phase's honest reporting.

- [ ] **Step 7: Commit**

```bash
git add lib/screens/tab_shell.dart test/screens/tab_shell_test.dart
git commit -m "feat(app): add ⚙ settings entry point to TabShell

Reachable from all 3 tabs (今日/我想做/月曆) via a small top-bar icon,
not a 4th bottom tab (spec §2 decision #11 locks the tab bar at 3).
This completes spec §9.8's 設定頁 and closes out the last unchecked
item in Phase 2 (設定頁 + JSON 匯出入 + 深色模式)."
```

---

## Self-Review Notes

**Spec coverage:** all 6 items in §9.8 — 通知時間/開關（UI+storage, no real scheduling per confirmed scope）、深色模式（跟系統/常開/常關, takes effect immediately app-wide）、JSON 匯出（stub per confirmed scope）、JSON 匯入（stub per confirmed scope）、重新做 onboarding（real, with confirm dialog）、免責聲明全文（real disclaimer copy, matching the medical/investment safety-line rules already established in `copywriter.dart`）、關於（real, static). Settings entry point (⚙ in `TabShell`, shared across all 3 tabs) matches the confirmed scope decision.

**No new packages:** confirmed neither `share_plus` nor `file_picker` (nor any other dependency) is added — `pubspec.yaml` is untouched by this plan. JSON export/import ship as UI + stub SnackBar only, exactly matching the established Tab B/combo-page precedent for features needing real-device verification this environment can't provide.

**Known regression-fix pattern to watch for:** Task 4 modifies `TabShell` (now wired/rewired 4 times across Phases 2c/2d/2e/2g) and explicitly calls out the now well-established risk — a sibling test (`onboarding_flow_test.dart`, which builds a full `TabShell` via `IndexedStack`) needing to still pass, plus the *new* risk this task introduces: `tab_shell_test.dart` never had a `SharedPreferences` mock before, and now needs one since `SettingsScreen` touches `StorageService`.

**Global-state test isolation:** `themeModeController` is a module-level singleton `ValueNotifier`, shared across whichever test files exercise it in the same isolate. Both `test/widget_test.dart` and `test/screens/settings/settings_screen_test.dart` include a `tearDown` resetting it to `ThemeMode.system`, so tests remain order-independent within each file (separate test files run in separate isolates in `flutter test`, so no cross-file leakage risk).

**Placeholder scan:** every step has complete, literal code. The only "stub" behavior (JSON export/import SnackBar, no real notification scheduling) is the explicitly confirmed scope, not a plan gap — and both are clearly labeled in-app text/comments, not silently incomplete.

**Type consistency:** `AppSettings`'s fields/`copyWith`/`toJson`/`fromJson` are used identically across Task 1 (definition), Task 2 (`main.dart`'s `_run()`), and Task 3 (`SettingsScreen`) — re-checked for drift. `StorageService.loadSettings()`/`saveSettings()`/`clearProfiles()` signatures match their Task 1 definitions exactly at every call site in Tasks 2–4. `themeModeController` (the exact same global instance) is referenced identically in Task 2 (`main.dart`) and Task 3 (`SettingsScreen._setThemeMode`).
