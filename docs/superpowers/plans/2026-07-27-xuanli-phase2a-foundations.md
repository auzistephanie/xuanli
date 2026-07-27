# XuanLi Phase 2a — Foundations Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Lay every piece of plumbing the rest of Phase 2 (2b–2g: onboarding, Tab A/B/C, combo page, settings) depends on, so those sub-plans can build screens directly instead of re-deriving infrastructure: bundled offline fonts, a light/dark theme with XuanLi's design tokens, profile persistence, a pure `buildProfile()` engine function, and — critically — fixing the Phase-1-known-TODO where `lib/engine`/`lib/models` JSON loaders use `dart:io File()` with repo-relative paths (works under `dart test`, but silently breaks once the app is compiled and those files become bundled assets instead of filesystem paths).

**Architecture:** Keep `lib/engine/` and `lib/models/combo.dart` 100% Flutter-free and now also 100% `dart:io`-free — they expose `init*(String jsonStr)` setters that populate an internal cache, instead of reading files themselves. A new Flutter-aware `lib/services/data_loader.dart` reads the actual JSON asset strings via `rootBundle` at app startup and feeds them into those setters. This preserves the "pure, testable engine" property (tests just call `init*()` with a string read via `dart:io` — that's fine, test code isn't bound by the no-`dart:io` rule) while making the loaders work correctly once compiled into a real app.

**Tech Stack:** Flutter (Material 3, `NavigationBar`, `ThemeExtension`), `shared_preferences` (profile persistence), bundled Noto Serif TC / Noto Sans TC variable fonts (offline, per spec §13 zero-network rule), existing Phase 1 `lib/engine`/`lib/models` code.

---

## File Structure

```
xuanli/
├── assets/fonts/NotoSerifTC.ttf   # NEW — bundled variable font (headings/numbers/干支)
├── assets/fonts/NotoSansTC.ttf    # NEW — bundled variable font (body text)
├── pubspec.yaml                   # MODIFY — register lib/data/*.json + fonts as assets
├── lib/
│   ├── engine/
│   │   ├── wuxing_tables.dart     # MODIFY — add public zhiToZodiac
│   │   ├── scoring.dart           # MODIFY — reuse public zhiToZodiac (drop private dup)
│   │   ├── almanac.dart           # MODIFY — drop dart:io, add initActivityCategories()
│   │   ├── activity.dart          # MODIFY — drop dart:io, add initActivities()
│   │   ├── copywriter.dart        # MODIFY — drop dart:io, add initMbtiTones()
│   │   └── profile_builder.dart   # NEW — buildProfile(): bazi+ziwei+zodiac → Profile
│   ├── models/
│   │   └── combo.dart             # MODIFY — drop dart:io, add initCombos()
│   ├── services/
│   │   ├── data_loader.dart       # NEW — rootBundle → engine init*() at startup
│   │   └── storage_service.dart   # NEW — profiles list persistence (shared_preferences)
│   ├── theme/
│   │   └── xuanli_theme.dart      # NEW — design tokens + light/dark ThemeData
│   └── main.dart                  # MODIFY — bootstrap + onboarding/tab-shell routing
├── test/
│   ├── engine/
│   │   ├── almanac_test.dart          # MODIFY — setUpAll(initActivityCategories)
│   │   ├── activity_test.dart         # MODIFY — setUpAll(initActivities)
│   │   ├── copywriter_test.dart       # MODIFY — setUpAll(initMbtiTones)
│   │   ├── day_reading_engine_test.dart # MODIFY — setUpAll(both of the above)
│   │   └── profile_builder_test.dart  # NEW
│   ├── models/
│   │   └── combo_test.dart        # MODIFY — setUpAll(initCombos)
│   ├── services/
│   │   ├── data_loader_test.dart      # NEW
│   │   └── storage_service_test.dart  # NEW
│   └── theme/
│       └── xuanli_theme_test.dart     # NEW
└── tool/demo.dart                 # MODIFY — use buildProfile() + new init*() calls
```

---

### Task 1: Public `zhiToZodiac` table (dedupe scoring.dart's private copy)

**Files:**
- Modify: `lib/engine/wuxing_tables.dart`
- Modify: `lib/engine/scoring.dart`

`profile_builder.dart` (Task 3) needs a year-zhi → zodiac lookup to compute `Profile.zodiac`. `scoring.dart` already has one, but it's `const Map<String, String> _zhiToZodiac` — private, and only used for `clashWarning` text. Promote it to `wuxing_tables.dart` (where the other zhi/gan lookup tables already live) and make `scoring.dart` use the shared copy instead of keeping its own.

- [ ] **Step 1: Add the public table to `wuxing_tables.dart`**

Add this after the existing `zhiClash` map (currently ends around line 25):

```dart
/// 地支 → 生肖。
const Map<String, String> zhiToZodiac = {
  '子': '鼠', '丑': '牛', '寅': '虎', '卯': '兔', '辰': '龍', '巳': '蛇',
  '午': '馬', '未': '羊', '申': '猴', '酉': '雞', '戌': '狗', '亥': '豬',
};
```

- [ ] **Step 2: Remove the private duplicate from `scoring.dart` and use the shared one**

`scoring.dart` currently has (around line 15-18):

```dart
/// 地支 → 生肖（用於 clashWarning 文案）。
const Map<String, String> _zhiToZodiac = {
  '子': '鼠', '丑': '牛', '寅': '虎', '卯': '兔', '辰': '龍', '巳': '蛇',
  '午': '馬', '未': '羊', '申': '猴', '酉': '雞', '戌': '狗', '亥': '豬',
};
```

Delete that block entirely. Then find the one usage (inside `computeFortuneScore`, in the `clashWarning` assignment):

```dart
      clashWarning = '今日沖你生肖（${_zhiToZodiac[userYearZhi]}）';
```

Change it to:

```dart
      clashWarning = '今日沖你生肖（${zhiToZodiac[userYearZhi]}）';
```

`scoring.dart` already imports `wuxing_tables.dart` (for `ganWuxing`/`zhiWuxing`/`zhiClash`), so no new import is needed.

- [ ] **Step 3: Run existing tests to confirm no regression**

Run: `dart test test/engine/scoring_test.dart -v`
Expected: PASS, including the existing `'肖龍用戶喺 2026-07-11（沖龍）clashWarning 非空且 -20 已計入'` test — it already asserts `clashWarning` contains `'龍'`, so it guards this refactor.

- [ ] **Step 4: Commit**

```bash
git add lib/engine/wuxing_tables.dart lib/engine/scoring.dart
git commit -m "refactor(engine): promote zhiToZodiac to shared wuxing_tables"
```

---

### Task 2: Remove `dart:io` from `lib/engine`/`lib/models` — explicit `init*()` loaders

**Files:**
- Modify: `lib/engine/almanac.dart`
- Modify: `lib/engine/activity.dart`
- Modify: `lib/engine/copywriter.dart`
- Modify: `lib/models/combo.dart`
- Modify: `test/engine/almanac_test.dart`
- Modify: `test/engine/activity_test.dart`
- Modify: `test/engine/copywriter_test.dart`
- Modify: `test/engine/day_reading_engine_test.dart`
- Modify: `test/models/combo_test.dart`

Each of these 4 production files currently reads its JSON file itself via `File('lib/data/...').readAsStringSync()`. That works when running via `dart test` (plain Dart VM, repo-relative CWD) but **will throw at runtime in the compiled app**, because `lib/data/*.json` becomes a bundled asset (read via `rootBundle`), not a filesystem path. Replace the "read file on first access" pattern with an explicit `init*(String jsonStr)` setter; the caller (tests, `tool/demo.dart`, or — once it exists — `lib/services/data_loader.dart`) is responsible for supplying the JSON string.

- [ ] **Step 1: `almanac.dart` — `activityCategoryWuxing` becomes a guarded getter**

Currently (lines 1-2 and 118-125):

```dart
import 'dart:convert';
import 'dart:io';
```//...
```dart
/// 通勝關鍵字 → 五行親和，源自 `lib/data/activity_categories.json`（spec §7）。
final Map<String, String> activityCategoryWuxing = _loadActivityCategories();

Map<String, String> _loadActivityCategories() {
  final file = File('lib/data/activity_categories.json');
  final jsonMap = json.decode(file.readAsStringSync()) as Map<String, dynamic>;
  return jsonMap.map((k, v) => MapEntry(k, v as String));
}
```

Replace the import block with just:

```dart
import 'dart:convert';
```

And replace the `activityCategoryWuxing`/`_loadActivityCategories` block with:

```dart
Map<String, String>? _activityCategoryWuxing;

/// 通勝關鍵字 → 五行親和，源自 `lib/data/activity_categories.json`（spec §7）。
/// 要喺 app 啟動時 call 過 [initActivityCategories] 先可以用
/// （見 `lib/services/data_loader.dart`；test 就喺 `setUpAll` 度 call）。
Map<String, String> get activityCategoryWuxing {
  final cache = _activityCategoryWuxing;
  if (cache == null) {
    throw StateError(
      'initActivityCategories() must be called before using '
      'activityCategoryWuxing — call it once at app startup '
      '(or in test setUpAll) with lib/data/activity_categories.json\'s contents.',
    );
  }
  return cache;
}

void initActivityCategories(String jsonStr) {
  final jsonMap = json.decode(jsonStr) as Map<String, dynamic>;
  _activityCategoryWuxing = jsonMap.map((k, v) => MapEntry(k, v as String));
}
```

(`activityCategoryWuxing[label]` call sites elsewhere are unaffected — a getter reads exactly like a field.)

- [ ] **Step 2: `activity.dart` — same pattern for `loadActivities()`**

Currently:

```dart
import 'dart:convert';
import 'dart:io';
import 'almanac.dart';
```
```dart
List<Activity> loadActivities() {
  final file = File('lib/data/activities.json');
  final list = json.decode(file.readAsStringSync()) as List;
  return list.map((e) => Activity.fromJson(e as Map<String, dynamic>)).toList();
}
```

Replace the import block with:

```dart
import 'dart:convert';
import 'almanac.dart';
```

Replace the function with:

```dart
List<Activity>? _activitiesCache;

void initActivities(String jsonStr) {
  final list = json.decode(jsonStr) as List;
  _activitiesCache =
      list.map((e) => Activity.fromJson(e as Map<String, dynamic>)).toList();
}

List<Activity> loadActivities() {
  final cache = _activitiesCache;
  if (cache == null) {
    throw StateError(
      'initActivities() must be called before loadActivities() — call it '
      'once at app startup (or in test setUpAll) with '
      'lib/data/activities.json\'s contents.',
    );
  }
  return cache;
}
```

- [ ] **Step 3: `copywriter.dart` — same pattern for the MBTI tones cache**

Currently:

```dart
import 'dart:convert';
import 'dart:io';
import 'almanac.dart';

Map<String, List<String>>? _toneCache;

Map<String, List<String>> _loadMbtiTones() {
  if (_toneCache != null) return _toneCache!;
  final file = File('lib/data/mbti_tones.json');
  final jsonMap = json.decode(file.readAsStringSync()) as Map<String, dynamic>;
  _toneCache = jsonMap.map((k, v) => MapEntry(k, List<String>.from(v as List)));
  return _toneCache!;
}
```

Replace with:

```dart
import 'dart:convert';
import 'almanac.dart';

Map<String, List<String>>? _toneCache;

void initMbtiTones(String jsonStr) {
  final jsonMap = json.decode(jsonStr) as Map<String, dynamic>;
  _toneCache = jsonMap.map((k, v) => MapEntry(k, List<String>.from(v as List)));
}

Map<String, List<String>> _loadMbtiTones() {
  final cache = _toneCache;
  if (cache == null) {
    throw StateError(
      'initMbtiTones() must be called before building advice — call it '
      'once at app startup (or in test setUpAll) with '
      'lib/data/mbti_tones.json\'s contents.',
    );
  }
  return cache;
}
```

- [ ] **Step 4: `lib/models/combo.dart` — same pattern for the combos cache**

Currently:

```dart
import 'dart:convert';
import 'dart:io';

class Combo {
  // ...unchanged...
}

Map<String, Combo>? _cache;

/// 載入 lib/data/combos.json（160 個組合，key = "日主天干_MBTI"）。
Map<String, Combo> loadCombos() {
  if (_cache != null) return _cache!;
  final file = File('lib/data/combos.json');
  final jsonMap = json.decode(file.readAsStringSync()) as Map<String, dynamic>;
  _cache = jsonMap.map((k, v) => MapEntry(k, Combo.fromJson(v as Map<String, dynamic>)));
  return _cache!;
}
```

Replace the import line `import 'dart:io';` with nothing (delete it, keep `import 'dart:convert';`), and replace the loader with:

```dart
Map<String, Combo>? _cache;

void initCombos(String jsonStr) {
  final jsonMap = json.decode(jsonStr) as Map<String, dynamic>;
  _cache = jsonMap.map((k, v) => MapEntry(k, Combo.fromJson(v as Map<String, dynamic>)));
}

/// 載入 lib/data/combos.json（160 個組合，key = "日主天干_MBTI"）。
/// 要喺 app 啟動時 call 過 [initCombos] 先可以用。
Map<String, Combo> loadCombos() {
  final cache = _cache;
  if (cache == null) {
    throw StateError(
      'initCombos() must be called before loadCombos() — call it once at '
      'app startup (or in test setUpAll) with lib/data/combos.json\'s contents.',
    );
  }
  return cache;
}
```

`getCombo()` below it is unchanged (it already just calls `loadCombos()`).

- [ ] **Step 5: Update `test/engine/almanac_test.dart` to init before use**

The `'宜忌個人化排序'` group calls `day.personalizedYi(...)` / `day.personalizedJi(...)`, which now need `initActivityCategories()` to have run. Add near the top of `main()` (right after the opening `void main() {`):

```dart
import 'dart:io';
```

(add to the top imports, alongside the existing `package:test/test.dart` and `package:xuanli/engine/almanac.dart` imports), and inside `main()`, before the first `group(...)`:

```dart
  setUpAll(() {
    initActivityCategories(
      File('lib/data/activity_categories.json').readAsStringSync(),
    );
  });
```

- [ ] **Step 6: Update `test/engine/activity_test.dart` to init before use**

Add `import 'dart:io';` to the imports, and inside `main()` before the `group('反向擇日', ...)` call:

```dart
  setUpAll(() {
    initActivities(File('lib/data/activities.json').readAsStringSync());
  });
```

- [ ] **Step 7: Update `test/engine/copywriter_test.dart` to init before use**

Add `import 'dart:io';`, and inside `main()` before the `group(...)` call:

```dart
  setUpAll(() {
    initMbtiTones(File('lib/data/mbti_tones.json').readAsStringSync());
  });
```

- [ ] **Step 8: Update `test/engine/day_reading_engine_test.dart` to init before use**

`buildDayReading()` transitively calls `buildAdvice()` (needs MBTI tones) and `day.personalizedYi/Ji` (needs activity categories). Add `import 'dart:io';` plus, before the two `test(...)` calls:

```dart
  setUpAll(() {
    initMbtiTones(File('lib/data/mbti_tones.json').readAsStringSync());
    initActivityCategories(
      File('lib/data/activity_categories.json').readAsStringSync(),
    );
  });
```

This also needs `import 'package:xuanli/engine/almanac.dart';` and `import 'package:xuanli/engine/copywriter.dart';` added to the file's imports (currently it only imports `bazi.dart`, `day_reading_engine.dart`, `models/profile.dart`) — those are the files `initActivityCategories`/`initMbtiTones` live in.

- [ ] **Step 9: Rename/move `test/engine/combo_test.dart` to `test/models/combo_test.dart` and init before use**

`combo.dart` lives in `lib/models/`, not `lib/engine/` — the test was just mis-filed under `test/engine/` in Phase 1. Move it now that we're touching it:

```bash
mkdir -p test/models
git mv test/engine/combo_test.dart test/models/combo_test.dart
```

Then add `import 'dart:io';` to its imports, and inside `main()` before the `group(...)` call:

```dart
  setUpAll(() {
    initCombos(File('lib/data/combos.json').readAsStringSync());
  });
```

- [ ] **Step 10: Update `tool/demo.dart` to call the new init functions**

`tool/demo.dart` calls `buildDayReading()`, which needs MBTI tones and activity categories loaded. Add near the top of `main()` (before `computeBazi(...)` is called):

```dart
import 'dart:io';

import 'package:xuanli/engine/almanac.dart';
import 'package:xuanli/engine/copywriter.dart';
```

(add these three imports alongside the existing ones), and as the first lines inside `void main(List<String> args) {`:

```dart
  initMbtiTones(File('lib/data/mbti_tones.json').readAsStringSync());
  initActivityCategories(
    File('lib/data/activity_categories.json').readAsStringSync(),
  );
```

- [ ] **Step 11: Run the full engine test suite and demo CLI to confirm nothing broke**

Run: `dart test test/engine/ test/models/ -v`
Expected: All tests PASS (79 existing + no new ones yet this task — count should match Phase 1's 79, now split across `test/engine/` and the moved `test/models/combo_test.dart`).

Run: `dart run tool/demo.dart 1999-09-20 09:30 ISFP`
Expected: Prints the demo output (四柱/日主/命理分/etc.) with no `StateError` thrown.

- [ ] **Step 12: Commit**

```bash
git add lib/engine/almanac.dart lib/engine/activity.dart lib/engine/copywriter.dart \
        lib/models/combo.dart test/engine/almanac_test.dart test/engine/activity_test.dart \
        test/engine/copywriter_test.dart test/engine/day_reading_engine_test.dart \
        test/models/combo_test.dart tool/demo.dart
git commit -m "refactor(engine): replace dart:io File loaders with explicit init*() setters

JSON data (activities/activity_categories/combos/mbti_tones) was being
read via File('lib/data/...') relative paths, which only works under
'dart test' — the compiled app bundles these as assets, not files on
a filesystem path. Callers (tests, tool/demo.dart, and the upcoming
lib/services/data_loader.dart) now explicitly hand each module its
JSON string via init*()."
```

---

### Task 3: `buildProfile()` — pure engine glue from birth data to `Profile`

**Files:**
- Create: `lib/engine/profile_builder.dart`
- Create: `test/engine/profile_builder_test.dart`
- Modify: `tool/demo.dart`

Onboarding (2b) needs to turn (birth date, birth hour, name, birthPlace, MBTI) into a full `Profile`. Right now that wiring only exists ad-hoc inside `tool/demo.dart` (duplicating a `_zhiToZodiac` table). Extract it into a real, tested, pure engine function.

- [ ] **Step 1: Write the failing test**

Create `test/engine/profile_builder_test.dart`:

```dart
import 'package:test/test.dart';
import 'package:xuanli/engine/profile_builder.dart';

void main() {
  group('buildProfile', () {
    test('阿玄（1999-09-20 09:30 香港 ISFP）— spec §11 golden fixture', () {
      final profile = buildProfile(
        id: 'p1',
        name: '阿玄',
        birthDate: DateTime(1999, 9, 20),
        birthHour: 9,
        birthMinute: 30,
        birthPlace: '香港',
        mbti: 'ISFP',
      );

      expect(profile.pillars, ['己卯', '癸酉', '乙亥', '辛巳']);
      expect(profile.dayMaster, '乙木');
      expect(profile.zodiac, '兔');
      expect(profile.favorable, ['水', '木']);
      expect(profile.unfavorable, ['金', '土']);
      expect(profile.ziweiStar, '太陰');
      expect(profile.completeness, 100);
      expect(profile.name, '阿玄');
      expect(profile.mbti, 'ISFP');
      expect(profile.birthPlace, '香港');
    });

    test('冇時辰（降級模式）：三柱 + 完整度 80%', () {
      final profile = buildProfile(
        id: 'p2',
        name: '無時辰用戶',
        birthDate: DateTime(1999, 9, 20),
        birthHour: null,
        birthPlace: '香港',
        mbti: 'ISFP',
      );

      expect(profile.pillars.length, 3);
      expect(profile.completeness, 80);
      expect(profile.ziweiStar, isNotEmpty);
      expect(profile.zodiac, isNotEmpty);
    });
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `dart test test/engine/profile_builder_test.dart`
Expected: FAIL — `Error: Not found: 'package:xuanli/engine/profile_builder.dart'` (file doesn't exist yet).

- [ ] **Step 3: Write the implementation**

Create `lib/engine/profile_builder.dart`:

```dart
import 'bazi.dart';
import 'wuxing_tables.dart';
import 'ziwei.dart';
import '../models/profile.dart';

/// 由出生資料 + MBTI 組成一個完整 [Profile]（spec §5/§6.1）——
/// 純函數，onboarding（2b）同 `tool/demo.dart` 共用呢個入口，
/// 唔好各自砌一份重複邏輯。
///
/// [birthHour] 為 null = 唔知時辰（三柱降級模式，見 [computeBazi]）。
Profile buildProfile({
  required String id,
  required String name,
  required DateTime birthDate,
  int? birthHour,
  int birthMinute = 0,
  required String birthPlace,
  required String mbti,
}) {
  final bazi = computeBazi(
    birthDate: birthDate,
    birthHour: birthHour,
    birthMinute: birthMinute,
  );
  final userYearZhi = bazi.pillars[0].substring(1);
  final userDayZhi = bazi.pillars[2].substring(1);

  return Profile(
    id: id,
    name: name,
    birthDate: birthDate,
    birthHour: birthHour,
    birthPlace: birthPlace,
    mbti: mbti,
    pillars: bazi.pillars,
    wuxing: bazi.wuxing,
    favorable: bazi.favorable,
    unfavorable: bazi.unfavorable,
    dayMaster: bazi.dayMaster,
    ziweiStar: ziweiStarForDayZhi(userDayZhi),
    zodiac: zhiToZodiac[userYearZhi]!,
  );
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `dart test test/engine/profile_builder_test.dart -v`
Expected: PASS (both tests).

- [ ] **Step 5: Simplify `tool/demo.dart` to use `buildProfile()`**

Replace the whole `_zhiToZodiac` const + manual `Profile(...)` construction in `tool/demo.dart` with a call to `buildProfile()`. The relevant block currently is:

```dart
const _zhiToZodiac = {
  '子': '鼠', '丑': '牛', '寅': '虎', '卯': '兔', '辰': '龍', '巳': '蛇',
  '午': '馬', '未': '羊', '申': '猴', '酉': '雞', '戌': '狗', '亥': '豬',
};

/// Usage: `dart run tool/demo.dart <YYYY-MM-DD> [HH:MM] <MBTI>`
void main(List<String> args) {
  // ...args parsing unchanged...

  final bazi = computeBazi(birthDate: birthDate, birthHour: birthHour, birthMinute: birthMinute);
  final userYearZhi = bazi.pillars[0].substring(1);
  final userDayZhi = bazi.pillars[2].substring(1);

  final profile = Profile(
    id: 'demo',
    name: '我',
    birthDate: birthDate,
    birthHour: birthHour,
    birthPlace: '香港',
    mbti: mbti,
    pillars: bazi.pillars,
    wuxing: bazi.wuxing,
    favorable: bazi.favorable,
    unfavorable: bazi.unfavorable,
    dayMaster: bazi.dayMaster,
    ziweiStar: ziweiStarForDayZhi(userDayZhi),
    zodiac: _zhiToZodiac[userYearZhi]!,
  );
```

Delete the `_zhiToZodiac` const entirely, and replace the `bazi`/`userYearZhi`/`userDayZhi`/`profile` block with:

```dart
  final profile = buildProfile(
    id: 'demo',
    name: '我',
    birthDate: birthDate,
    birthHour: birthHour,
    birthMinute: birthMinute,
    birthPlace: '香港',
    mbti: mbti,
  );
```

Update the imports at the top of `tool/demo.dart`: remove `import 'package:xuanli/engine/bazi.dart';` and `import 'package:xuanli/engine/ziwei.dart';` (no longer called directly), remove `import 'package:xuanli/models/profile.dart';` (no longer constructed directly), and add:

```dart
import 'package:xuanli/engine/profile_builder.dart';
```

Also fix the print line further down that references `bazi.pillars`/`bazi.dayMaster`/`bazi.favorable`/`bazi.unfavorable` — those now come from `profile` directly:

```dart
  print('=== 玄曆 Demo ===');
  print('四柱：${profile.pillars.join(' ')}');
  print('日主：${profile.dayMaster}　肖：${profile.zodiac}　完整度：${profile.completeness}%');
  print('喜：${profile.favorable.join('')}　忌：${profile.unfavorable.join('')}');
```

- [ ] **Step 6: Run the demo CLI to confirm it still works end-to-end**

Run: `dart run tool/demo.dart 1999-09-20 09:30 ISFP`
Expected: Same output shape as before Step 5 (四柱 己卯 癸酉 乙亥 辛巳, 日主 乙木, 肖 兔, etc.), no errors.

- [ ] **Step 7: Run the full engine suite one more time**

Run: `dart test test/engine/ test/models/ -v`
Expected: All PASS.

- [ ] **Step 8: Commit**

```bash
git add lib/engine/profile_builder.dart test/engine/profile_builder_test.dart tool/demo.dart
git commit -m "feat(engine): add buildProfile() — birth data + MBTI -> Profile

Extracts the ad-hoc wiring tool/demo.dart had (duplicate zhi->zodiac
table + manual Profile construction) into a real, tested engine
function onboarding (Phase 2b) will call directly."
```

---

### Task 4: Bundle Noto Serif TC / Noto Sans TC as offline font assets

**Files:**
- Create: `assets/fonts/NotoSerifTC.ttf`
- Create: `assets/fonts/NotoSansTC.ttf`
- Modify: `pubspec.yaml`

Spec §13 (紅線): fonts must be bundled, not fetched at runtime — the whole app must work in airplane mode. `google_fonts` package's default behavior fetches font files over the network on first use, which would violate this. Instead, download the actual variable-weight TTF files (verified reachable; a variable font covers every weight in one file, which is also the most size-efficient option for a full-CJK-glyph-coverage font) and bundle them as real Flutter font assets.

⚠️ Already confirmed during planning: these two files are ~29MB combined (CJK fonts have thousands of glyphs). This eats most of Phase 4's "<40MB APK" target — deliberately deferred (Stephanie's call): ship with full fonts now so Phase 2 UI work isn't blocked, revisit font subsetting only if Phase 4's size check actually fails.

- [ ] **Step 1: Download the font files**

```bash
mkdir -p assets/fonts
curl -sL --max-time 60 -o assets/fonts/NotoSerifTC.ttf \
  "https://raw.githubusercontent.com/google/fonts/main/ofl/notoseriftc/NotoSerifTC%5Bwght%5D.ttf"
curl -sL --max-time 60 -o assets/fonts/NotoSansTC.ttf \
  "https://raw.githubusercontent.com/google/fonts/main/ofl/notosanstc/NotoSansTC%5Bwght%5D.ttf"
file assets/fonts/*.ttf
```

Expected: both `file` outputs say `TrueType Font data`. (Verified working during planning — `NotoSerifTC.ttf` ~16.8MB, `NotoSansTC.ttf` ~11.9MB.)

- [ ] **Step 2: Register the JSON data files and fonts as pubspec assets**

In `pubspec.yaml`, find the commented-out `# assets:` section under `flutter:` (currently all example/commented lines) and add real `assets:` and `fonts:` sections. The `flutter:` section should end up containing:

```yaml
flutter:
  uses-material-design: true

  assets:
    - lib/data/activities.json
    - lib/data/activity_categories.json
    - lib/data/combos.json
    - lib/data/mbti_tones.json

  fonts:
    - family: NotoSerifTC
      fonts:
        - asset: assets/fonts/NotoSerifTC.ttf
          weight: 400
        - asset: assets/fonts/NotoSerifTC.ttf
          weight: 500
        - asset: assets/fonts/NotoSerifTC.ttf
          weight: 600
        - asset: assets/fonts/NotoSerifTC.ttf
          weight: 700
        - asset: assets/fonts/NotoSerifTC.ttf
          weight: 900
    - family: NotoSansTC
      fonts:
        - asset: assets/fonts/NotoSansTC.ttf
          weight: 300
        - asset: assets/fonts/NotoSansTC.ttf
          weight: 400
        - asset: assets/fonts/NotoSansTC.ttf
          weight: 500
        - asset: assets/fonts/NotoSansTC.ttf
          weight: 700
```

(Multiple weight entries pointing at the same variable-font file is the standard Flutter pattern for using variable fonts — the engine picks the right variation instance per requested `FontWeight`. Leave the rest of `pubspec.yaml`, including the existing commented-out example asset/font blocks below this if any remain, untouched — just replace the previously-empty `assets:`/`fonts:` with the above.)

- [ ] **Step 3: Fetch packages and verify the pubspec is valid**

Run: `flutter pub get`
Expected: Completes with no errors (`Got dependencies!`).

- [ ] **Step 4: Commit**

Font files are binary — check they're not already excluded by `.gitignore` before adding:

```bash
git check-ignore assets/fonts/NotoSerifTC.ttf assets/fonts/NotoSansTC.ttf
```

Expected: no output (not ignored). Then:

```bash
git add assets/fonts/NotoSerifTC.ttf assets/fonts/NotoSansTC.ttf pubspec.yaml pubspec.lock
git commit -m "chore: bundle Noto Serif/Sans TC variable fonts + register data assets

Offline-only per spec §13 — no runtime font fetching. ~29MB combined;
deliberately deferred subsetting/optimization to Phase 4's APK-size
check rather than blocking Phase 2 UI work on it now."
```

---

### Task 5: `lib/services/data_loader.dart` — load engine data from real assets at startup

**Files:**
- Create: `lib/services/data_loader.dart`
- Create: `test/services/data_loader_test.dart`

- [ ] **Step 1: Write the failing test**

Create `test/services/data_loader_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:xuanli/engine/activity.dart';
import 'package:xuanli/models/combo.dart';
import 'package:xuanli/services/data_loader.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('loadEngineData() 由真 asset 讀 JSON，令 loadActivities/loadCombos 用得', () async {
    await loadEngineData();

    expect(loadActivities().length, 14);
    expect(loadCombos().length, 160);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/services/data_loader_test.dart`
Expected: FAIL — `Error: Not found: 'package:xuanli/services/data_loader.dart'`.

- [ ] **Step 3: Write the implementation**

Create `lib/services/data_loader.dart`:

```dart
import 'package:flutter/services.dart' show rootBundle;

import '../engine/almanac.dart';
import '../engine/activity.dart';
import '../engine/copywriter.dart';
import '../models/combo.dart';

/// 喺 app 啟動時 call 一次：由 `rootBundle` 讀返 4 個 JSON asset，
/// 餵落 `lib/engine`/`lib/models` 嘅 init*() cache。冇 call 過呢個
/// function 之前，`loadActivities()`／`loadCombos()`／宜忌個人化排序／
/// 貼身建議文案 全部會 throw `StateError`。
Future<void> loadEngineData() async {
  final results = await Future.wait([
    rootBundle.loadString('lib/data/activities.json'),
    rootBundle.loadString('lib/data/activity_categories.json'),
    rootBundle.loadString('lib/data/combos.json'),
    rootBundle.loadString('lib/data/mbti_tones.json'),
  ]);

  initActivities(results[0]);
  initActivityCategories(results[1]);
  initCombos(results[2]);
  initMbtiTones(results[3]);
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/services/data_loader_test.dart -v`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/services/data_loader.dart test/services/data_loader_test.dart
git commit -m "feat(services): add data_loader — rootBundle JSON -> engine init*()"
```

---

### Task 6: `lib/theme/xuanli_theme.dart` — design tokens + light/dark ThemeData

**Files:**
- Create: `lib/theme/xuanli_theme.dart`
- Create: `test/theme/xuanli_theme_test.dart`

Design tokens per spec §12 and `design/design-preview.html`'s `:root` CSS variables:
`paper #f6efe2 / paper2 #efe5d0 / ink #1c2440 / red #b23a3a / gold #c9a24b / jade #3f7d6e`,
dark mode: `bg #131829 / card #1c2440 / paper-text #e9dfc9`, plus `ink60`/`ink30`/`ink12` (ink at 60%/30%/12% opacity, used throughout the design for secondary text/borders). Radii: card 16 / cell(格) 9 / widget 28.

- [ ] **Step 1: Write the failing test**

Create `test/theme/xuanli_theme_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xuanli/theme/xuanli_theme.dart';

void main() {
  group('XuanLiTheme', () {
    test('light() 用淺色 paper 做背景，掛咗 XuanLiColors extension', () {
      final theme = XuanLiTheme.light();
      expect(theme.brightness, Brightness.light);
      expect(theme.scaffoldBackgroundColor, XuanLiColors.light.paper);
      expect(theme.extension<XuanLiColors>(), XuanLiColors.light);
    });

    test('dark() 用深色 bg 做背景，掛咗深色 XuanLiColors extension', () {
      final theme = XuanLiTheme.dark();
      expect(theme.brightness, Brightness.dark);
      expect(theme.scaffoldBackgroundColor, XuanLiColors.dark.paper);
      expect(theme.extension<XuanLiColors>(), XuanLiColors.dark);
    });

    test('XuanLiRadii tokens 同 spec §12 一致（卡16/格9/widget28）', () {
      expect(XuanLiRadii.card, 16.0);
      expect(XuanLiRadii.cell, 9.0);
      expect(XuanLiRadii.widget, 28.0);
    });
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/theme/xuanli_theme_test.dart`
Expected: FAIL — `Error: Not found: 'package:xuanli/theme/xuanli_theme.dart'`.

- [ ] **Step 3: Write the implementation**

Create `lib/theme/xuanli_theme.dart`:

```dart
import 'package:flutter/material.dart';

/// 玄曆設計 tokens（spec §12 + design/design-preview.html 嘅 :root CSS 變量）。
/// 淺色/深色各一份 const 實例，掛喺 [ThemeData.extensions] 度，畫面用
/// `Theme.of(context).extension<XuanLiColors>()!` 攞（`!` 安全，因為
/// [XuanLiTheme.light]/[XuanLiTheme.dark] 一定會掛呢個 extension）。
@immutable
class XuanLiColors extends ThemeExtension<XuanLiColors> {
  final Color paper;
  final Color paper2;
  final Color cardSurface;
  final Color ink;
  final Color ink60;
  final Color ink30;
  final Color ink12;
  final Color red;
  final Color gold;
  final Color jade;

  const XuanLiColors({
    required this.paper,
    required this.paper2,
    required this.cardSurface,
    required this.ink,
    required this.ink60,
    required this.ink30,
    required this.ink12,
    required this.red,
    required this.gold,
    required this.jade,
  });

  static const light = XuanLiColors(
    paper: Color(0xFFF6EFE2),
    paper2: Color(0xFFEFE5D0),
    cardSurface: Color(0xFFFFFDF7), // design html `.card` background
    ink: Color(0xFF1C2440),
    ink60: Color(0x991C2440),
    ink30: Color(0x401C2440),
    ink12: Color(0x1F1C2440),
    red: Color(0xFFB23A3A),
    gold: Color(0xFFC9A24B),
    jade: Color(0xFF3F7D6E),
  );

  static const dark = XuanLiColors(
    paper: Color(0xFF131829), // design html --d-bg
    paper2: Color(0xFF1C2440), // design html --d-card
    cardSurface: Color(0xFF1C2440),
    ink: Color(0xFFE9DFC9), // design html --d-paper (text colour in dark mode)
    ink60: Color(0x99E9DFC9),
    ink30: Color(0x40E9DFC9),
    ink12: Color(0x1FE9DFC9),
    red: Color(0xFFE08484), // design html dark-mode 忌 colour
    gold: Color(0xFFC9A24B),
    jade: Color(0xFF7FC0AB), // design html dark-mode 宜 colour
  );

  @override
  XuanLiColors copyWith({
    Color? paper,
    Color? paper2,
    Color? cardSurface,
    Color? ink,
    Color? ink60,
    Color? ink30,
    Color? ink12,
    Color? red,
    Color? gold,
    Color? jade,
  }) {
    return XuanLiColors(
      paper: paper ?? this.paper,
      paper2: paper2 ?? this.paper2,
      cardSurface: cardSurface ?? this.cardSurface,
      ink: ink ?? this.ink,
      ink60: ink60 ?? this.ink60,
      ink30: ink30 ?? this.ink30,
      ink12: ink12 ?? this.ink12,
      red: red ?? this.red,
      gold: gold ?? this.gold,
      jade: jade ?? this.jade,
    );
  }

  @override
  XuanLiColors lerp(ThemeExtension<XuanLiColors>? other, double t) {
    if (other is! XuanLiColors) return this;
    return XuanLiColors(
      paper: Color.lerp(paper, other.paper, t)!,
      paper2: Color.lerp(paper2, other.paper2, t)!,
      cardSurface: Color.lerp(cardSurface, other.cardSurface, t)!,
      ink: Color.lerp(ink, other.ink, t)!,
      ink60: Color.lerp(ink60, other.ink60, t)!,
      ink30: Color.lerp(ink30, other.ink30, t)!,
      ink12: Color.lerp(ink12, other.ink12, t)!,
      red: Color.lerp(red, other.red, t)!,
      gold: Color.lerp(gold, other.gold, t)!,
      jade: Color.lerp(jade, other.jade, t)!,
    );
  }
}

/// 圓角 tokens（spec §12：卡 16 / 格 9 / widget 28）。
class XuanLiRadii {
  static const card = 16.0;
  static const cell = 9.0;
  static const widget = 28.0;
}

/// 字體 family 名（要同 pubspec.yaml 嘅 `fonts:` 段 family 名一致）。
class XuanLiFonts {
  /// 標題／數字／干支（design html `.serif` class）。
  static const serif = 'NotoSerifTC';

  /// 正文（design html body 預設字體）。
  static const sans = 'NotoSansTC';
}

class XuanLiTheme {
  static ThemeData light() => _build(XuanLiColors.light, Brightness.light);
  static ThemeData dark() => _build(XuanLiColors.dark, Brightness.dark);

  static ThemeData _build(XuanLiColors colors, Brightness brightness) {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: colors.ink,
      brightness: brightness,
      primary: colors.ink,
      secondary: colors.gold,
      error: colors.red,
      surface: colors.paper,
    );

    final base = ThemeData(brightness: brightness);
    final textTheme = base.textTheme
        .apply(
          fontFamily: XuanLiFonts.sans,
          bodyColor: colors.ink,
          displayColor: colors.ink,
        )
        .copyWith(
          headlineMedium: TextStyle(
            fontFamily: XuanLiFonts.serif,
            fontWeight: FontWeight.w700,
            color: colors.ink,
          ),
          headlineSmall: TextStyle(
            fontFamily: XuanLiFonts.serif,
            fontWeight: FontWeight.w700,
            color: colors.ink,
          ),
          titleLarge: TextStyle(
            fontFamily: XuanLiFonts.serif,
            fontWeight: FontWeight.w700,
            color: colors.ink,
          ),
        );

    return ThemeData(
      brightness: brightness,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: colors.paper,
      fontFamily: XuanLiFonts.sans,
      textTheme: textTheme,
      cardTheme: CardThemeData(
        color: colors.cardSurface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(XuanLiRadii.card),
        ),
        elevation: 0,
      ),
      extensions: [colors],
    );
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/theme/xuanli_theme_test.dart -v`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/theme/xuanli_theme.dart test/theme/xuanli_theme_test.dart
git commit -m "feat(theme): add XuanLiTheme — design tokens + light/dark ThemeData"
```

---

### Task 7: `lib/services/storage_service.dart` — profile persistence

**Files:**
- Create: `lib/services/storage_service.dart`
- Create: `test/services/storage_service_test.dart`

Per spec §5: storage is a `profiles: [Profile]` list (MVP only ever uses `profiles[0]`), via `shared_preferences` + JSON (`Profile.toJson`/`fromJson` already exist from Phase 1).

- [ ] **Step 1: Write the failing test**

Create `test/services/storage_service_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:xuanli/models/profile.dart';
import 'package:xuanli/services/storage_service.dart';

Profile _sampleProfile({String id = 'p1'}) => Profile(
      id: id,
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
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('StorageService', () {
    test('loadPrimaryProfile() 喺未存過任何嘢時返回 null', () async {
      final result = await StorageService().loadPrimaryProfile();
      expect(result, isNull);
    });

    test('savePrimaryProfile() 之後 loadPrimaryProfile() 攞返同一個 profile', () async {
      final service = StorageService();
      await service.savePrimaryProfile(_sampleProfile());

      final loaded = await service.loadPrimaryProfile();
      expect(loaded, isNotNull);
      expect(loaded!.id, 'p1');
      expect(loaded.name, '阿玄');
      expect(loaded.pillars, ['己卯', '癸酉', '乙亥', '辛巳']);
      expect(loaded.wuxing, {'木': 30, '火': 14, '土': 13, '金': 15, '水': 28});
    });

    test('savePrimaryProfile() 覆蓋舊 profile（MVP 淨係用 profiles[0]）', () async {
      final service = StorageService();
      await service.savePrimaryProfile(_sampleProfile(id: 'first'));
      await service.savePrimaryProfile(_sampleProfile(id: 'second'));

      final profiles = await service.loadProfiles();
      expect(profiles.length, 1);
      expect(profiles.first.id, 'second');
    });
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/services/storage_service_test.dart`
Expected: FAIL — `Error: Not found: 'package:xuanli/services/storage_service.dart'`.

- [ ] **Step 3: Write the implementation**

Create `lib/services/storage_service.dart`:

```dart
import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/profile.dart';

/// Profile 持久化（spec §5：`profiles: [Profile]`，MVP 淨係用 `profiles[0]`）。
/// 用 `shared_preferences` 存一個 JSON-encoded list string。
class StorageService {
  static const _profilesKey = 'xuanli_profiles';

  Future<List<Profile>> loadProfiles() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_profilesKey);
    if (raw == null) return [];
    final list = json.decode(raw) as List;
    return list
        .map((e) => Profile.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<void> saveProfiles(List<Profile> profiles) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = json.encode(profiles.map((p) => p.toJson()).toList());
    await prefs.setString(_profilesKey, raw);
  }

  /// MVP 用戶入口：淨係讀/寫 `profiles[0]`。
  Future<Profile?> loadPrimaryProfile() async {
    final profiles = await loadProfiles();
    return profiles.isEmpty ? null : profiles.first;
  }

  /// MVP 用戶入口：覆蓋成個 profiles list 做淨係得一個 profile
  /// （未來多檔案支援 —— spec §2 決定 11 講嘅第二版功能 —— 先會有第二個）。
  Future<void> savePrimaryProfile(Profile profile) async {
    await saveProfiles([profile]);
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/services/storage_service_test.dart -v`
Expected: PASS (all 3 tests).

- [ ] **Step 5: Commit**

```bash
git add lib/services/storage_service.dart test/services/storage_service_test.dart
git commit -m "feat(services): add StorageService — profiles[0] persistence via shared_preferences"
```

---

### Task 8: Navigation shell — `lib/main.dart` bootstrap + onboarding/tab routing

**Files:**
- Modify: `lib/main.dart`

Wire everything together: on launch, load engine data from assets (Task 5), check for a saved profile (Task 7); if none, show an onboarding placeholder (real onboarding flow is Task 2b's job); if one exists, show the tab shell (bottom nav with 3 placeholder bodies — real content is 2c/2d/2e's job). This task's purpose is proving the plumbing works end-to-end, not final pixel-perfect UI.

- [ ] **Step 1: Replace `lib/main.dart` entirely**

The current file is the unmodified `flutter create` counter-app demo. Replace its full contents with:

```dart
import 'package:flutter/material.dart';

import 'models/profile.dart';
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
          return const _OnboardingPlaceholder();
        }
        return const TabShell();
      },
    );
  }
}

/// 2b 先起真正嘅 onboarding 三步流程（出生資料/MBTI/檔案卡）；
/// 呢度暫時得個殼，證明「冇 profile → 跳 onboarding」路由行得通。
class _OnboardingPlaceholder extends StatelessWidget {
  const _OnboardingPlaceholder();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(child: Text('Onboarding — 2b 起')),
    );
  }
}

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

- [ ] **Step 2: `flutter analyze` must be clean**

Run: `flutter analyze`
Expected: `No issues found!`

- [ ] **Step 3: Full test suite must stay green**

Run: `dart test test/engine/ test/models/`
Expected: PASS.

Run: `flutter test`
Expected: PASS (includes the new `test/services/`, `test/theme/` tests plus every existing Phase 1 test — `flutter test` runs everything under `test/`, both plain-Dart and Flutter-widget tests).

- [ ] **Step 4: Manually run the app to confirm the shell boots**

Run: `flutter run -d <device-or-simulator-id>` (or `flutter run` and pick a connected device/simulator interactively)
Expected: App launches with no red error screen. Since no profile is saved yet, it shows "Onboarding — 2b 起" centered on a paper-coloured (`#F6EFE2`) background. Confirm this now — this is the first point in Phase 2a where there's an actual screen to look at, satisfying this repo's DoD checklist item 2 ("UI 有改 → 肉眼查") even though there's no real design-html screen to compare against yet (that starts in earnest with 2b's onboarding).

- [ ] **Step 5: Commit**

```bash
git add lib/main.dart
git commit -m "feat(app): wire bootstrap + onboarding/tab-shell routing in main.dart

Loads engine data from real assets, checks for a saved profile, and
routes to a placeholder onboarding screen or the 3-tab shell
accordingly. Screen content itself is 2b (onboarding) and 2c/2d/2e
(Tab A/B/C) — this just proves the plumbing end-to-end."
```

---

## Self-Review Notes

**Spec coverage:** This sub-plan doesn't implement any spec §9 screen content (that's 2b–2g) — it covers the cross-cutting infrastructure spec §3 (packages), §4 (repo structure: `services/`, `theme/`), §5 (Profile persistence + `buildProfile`), and the "唔准簡體字/零網絡" red lines as they apply to fonts (§13). Every item in the Stephanie-approved 2a scope (theme/storage/navigation shell/JSON loader→asset/buildProfile glue) has a task.

**Placeholder scan:** No TBD/"add error handling later"/"similar to Task N" — every step has literal code, verified against the actual installed Flutter 3.44.7 / Dart 3.12.2 / shared_preferences 2.5.5 APIs on this machine (checked `CardThemeData` vs deprecated `CardTheme`, `ColorScheme.fromSeed` param names, `NavigationBar` constructor, `SharedPreferences.setMockInitialValues`/`getInstance` availability) rather than assumed from memory.

**Type consistency:** `buildProfile()` (Task 3) returns `Profile` matching the exact field names Task 7's `StorageService` round-trips via `toJson`/`fromJson` (both already existed from Phase 1, unmodified here). `XuanLiColors`/`XuanLiRadii`/`XuanLiFonts` names introduced in Task 6 are the names Task 8's `main.dart` actually imports and uses (`XuanLiTheme.light()`/`.dark()`). `loadEngineData()` (Task 5) calls exactly the four `init*()` setter names Task 2 defines (`initActivities`, `initActivityCategories`, `initCombos`, `initMbtiTones`) — no drift.
