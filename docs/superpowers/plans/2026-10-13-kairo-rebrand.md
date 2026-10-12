# Kairo 改名 × 3D／動態 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 用家睇到嘅品牌由「玄曆」改做 Kairo（吉時），並加入天體儀、立體籤筒、傾斜全息卡、星空、翻卡、過場等 3D／動態效果。

**Architecture:** 全部 3D 用 Flutter `CustomPainter`＋`Matrix4` 自己畫；投影／傾斜／搖動偵測抽成純 Dart 函數做 unit test。持續循環嘅「環境動畫」經 `Motion` 閘門控制：測試（`test/flutter_test_config.dart`）同「減少動態效果」都會停晒，避免 `pumpAndSettle` 卡死。內部識別（package、bundle ID、App Group、URL scheme、prefs key、備份格式、日曆識別碼）一律唔改。

**Tech Stack:** Flutter stable、`sensors_plus`（新）、Cormorant Garamond（OFL，subset bundle）、`flutter_launcher_icons`。

**Spec:** `docs/superpowers/specs/2026-10-13-kairo-rebrand-design.md`・**視覺參考：** `design/kairo-preview.html`

**Branch:** `feat/kairo-rebrand`（已開）。每個 task 完一個 commit，英文 message，結尾加 `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`。

**常用指令：**
- 單一測試：`flutter test test/path/x_test.dart`
- 全套：`dart test test/engine/ && flutter analyze && flutter test`

---

## File Structure

| 檔案 | 狀態 | 職責 |
|---|---|---|
| `lib/theme/motion.dart` | 新 | `Motion` 閘門：環境動畫／感應器開唔開 |
| `test/flutter_test_config.dart` | 新 | 全部測試預設關環境動畫 |
| `lib/theme/brand.dart` | 新 | 品牌字串＋`KairoPalette` 裝飾色 |
| `lib/widgets/brand.dart` | 新 | `BrandSeal`、`Wordmark` |
| `assets/fonts/CormorantGaramond-SemiBold.ttf` | 新 | Wordmark 字體（拉丁 subset） |
| `lib/widgets/starfield.dart` | 新 | 星空背景 |
| `lib/widgets/orrery_geometry.dart` | 新 | 純函數：環上點嘅 3D 投影 |
| `lib/widgets/orrery.dart` | 新 | 天體儀 widget（後層環＋核心球＋前層環） |
| `lib/widgets/tilt_math.dart` | 新 | 純函數：傾斜角、重力→傾斜 |
| `lib/services/shake_detector.dart` | 新 | 純 Dart：搖動偵測 |
| `lib/widgets/tilt_card.dart` | 新 | 傾斜＋全息反光卡 |
| `lib/widgets/wuxing_orbs.dart` | 新 | 五行晶球列 |
| `lib/widgets/flip_reveal.dart` | 新 | 3D 翻卡 |
| `lib/theme/page_transitions.dart` | 新 | 淡入＋輕放大過場 |
| `tool/render_icon_test.dart` | 新 | 用 Orrery 畫 icon PNG（手動 `--update-goldens`，唔喺 test/ 所以平時唔跑） |
| `lib/theme/xuanli_theme.dart` | 改 | 夜空深色 palette、過場 |
| `lib/models/settings.dart`、`lib/services/theme_mode_controller.dart` | 改 | 預設深色 |
| `lib/widgets/stick_cylinder.dart` | 改 | 立體籤筒 |
| 各畫面／service／原生／web | 改 | 品牌字串 |

---

### Task 1: Motion 閘門＋測試設定

**Files:**
- Create: `lib/theme/motion.dart`
- Create: `test/flutter_test_config.dart`
- Test: `test/theme/motion_test.dart`

- [ ] **Step 1: Write the failing test**

```dart
// test/theme/motion_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xuanli/theme/motion.dart';

void main() {
  tearDown(() => Motion.ambientEnabled = false);

  Future<bool> ambientIn(WidgetTester tester, {required bool disable}) async {
    late bool result;
    await tester.pumpWidget(MediaQuery(
      data: MediaQueryData(disableAnimations: disable),
      child: Builder(builder: (c) {
        result = Motion.ambient(c);
        return const SizedBox();
      }),
    ));
    return result;
  }

  testWidgets('測試環境預設關環境動畫（flutter_test_config）', (tester) async {
    expect(Motion.ambientEnabled, isFalse);
    expect(await ambientIn(tester, disable: false), isFalse);
  });

  testWidgets('開咗 ambientEnabled、冇減少動態 → true', (tester) async {
    Motion.ambientEnabled = true;
    expect(await ambientIn(tester, disable: false), isTrue);
  });

  testWidgets('系統減少動態效果 → 永遠 false', (tester) async {
    Motion.ambientEnabled = true;
    expect(await ambientIn(tester, disable: true), isFalse);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/theme/motion_test.dart`
Expected: FAIL（`motion.dart` 唔存在）

- [ ] **Step 3: Implement**

```dart
// lib/theme/motion.dart
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/widgets.dart';

/// 持續循環嘅「環境動畫」（天體儀轉、星閃、感應器傾斜）嘅總閘。
/// 一次性動畫（搖籤、翻卡、淡入）唔經呢度，照舊睇 `disableAnimations`。
/// 測試由 `test/flutter_test_config.dart` 關咗佢，否則 `pumpAndSettle` 會永遠等唔完。
class Motion {
  static bool ambientEnabled = true;

  static bool ambient(BuildContext context) =>
      ambientEnabled && !MediaQuery.of(context).disableAnimations;

  /// 陀螺儀／加速計：web 冇可靠權限流程，一律用拖動代替。
  static bool sensors(BuildContext context) => ambient(context) && !kIsWeb;
}
```

```dart
// test/flutter_test_config.dart
import 'dart:async';

import 'package:xuanli/theme/motion.dart';

Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  Motion.ambientEnabled = false;
  await testMain();
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/theme/motion_test.dart`
Expected: 3 tests PASS

- [ ] **Step 5: Commit**

```bash
git add lib/theme/motion.dart test/flutter_test_config.dart test/theme/motion_test.dart
git commit -m "feat: add Motion gate for ambient animations"
```

---

### Task 2: 品牌常數、Wordmark 字體、BrandSeal／Wordmark widget

**Files:**
- Create: `lib/theme/brand.dart`
- Create: `lib/widgets/brand.dart`
- Create: `assets/fonts/CormorantGaramond-SemiBold.ttf`、`assets/fonts/OFL-CormorantGaramond.txt`
- Modify: `pubspec.yaml`（`fonts:` 段）、`lib/theme/xuanli_theme.dart`（`XuanLiFonts`）
- Test: `test/widgets/brand_test.dart`

- [ ] **Step 1: 問 Stephanie 准唔准下載字體**

講明：由 `github.com/google/fonts`（官方 Google Fonts repo）下載 `CormorantGaramond[wght].ttf`（約 500KB）同 `OFL.txt`，subset 後入 app 約 30KB。冇批准就停。

- [ ] **Step 2: 下載、固定字重、subset**

```bash
S=/private/tmp/claude-503/-Users-stephanieau-dev-xuanli/fontwork; mkdir -p $S
python3 -m venv $S/venv && $S/venv/bin/pip -q install fonttools
curl -L -o $S/cg.ttf "https://github.com/google/fonts/raw/main/ofl/cormorantgaramond/CormorantGaramond%5Bwght%5D.ttf"
curl -L -o assets/fonts/OFL-CormorantGaramond.txt "https://github.com/google/fonts/raw/main/ofl/cormorantgaramond/OFL.txt"
$S/venv/bin/fonttools varLib.instancer $S/cg.ttf wght=600 -o $S/cg600.ttf
$S/venv/bin/pyftsubset $S/cg600.ttf --unicodes="U+0020-007E" --output-file=assets/fonts/CormorantGaramond-SemiBold.ttf
ls -la assets/fonts/CormorantGaramond-SemiBold.ttf
```
Expected: 檔案存在，< 100KB。

- [ ] **Step 3: pubspec 加 font family**

喺 `pubspec.yaml` 嘅 `fonts:` 段最尾加：

```yaml
    - family: CormorantGaramond
      fonts:
        - asset: assets/fonts/CormorantGaramond-SemiBold.ttf
          weight: 600
```

`lib/theme/xuanli_theme.dart` 嘅 `XuanLiFonts` 加：

```dart
  /// Kairo 品牌字（只有拉丁字 subset，唔好用嚟顯示中文）。
  static const wordmark = 'CormorantGaramond';
```

- [ ] **Step 4: Write the failing test**

```dart
// test/widgets/brand_test.dart
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xuanli/theme/brand.dart';
import 'package:xuanli/widgets/brand.dart';

void main() {
  Widget wrap(Widget c) => MaterialApp(home: Scaffold(body: Center(child: c)));

  test('品牌常數', () {
    expect(kBrandName, 'Kairo');
    expect(kBrandSeal, '吉時');
    expect(kBrandSealShort, '吉');
  });

  test('Wordmark 字體已 bundle 而且細過 100KB', () {
    final f = File('assets/fonts/CormorantGaramond-SemiBold.ttf');
    expect(f.existsSync(), isTrue);
    expect(f.lengthSync(), lessThan(100 * 1024));
  });

  testWidgets('BrandSeal 單字：顯示一個字，尺寸跟 size', (tester) async {
    await tester.pumpWidget(wrap(const BrandSeal(text: '吉', size: 34)));
    expect(find.text('吉'), findsOneWidget);
    expect(tester.getSize(find.byType(BrandSeal)), const Size(34, 34));
  });

  testWidgets('BrandSeal 兩字：直排兩個字', (tester) async {
    await tester.pumpWidget(wrap(const BrandSeal(text: '吉時', size: 64)));
    expect(find.text('吉'), findsOneWidget);
    expect(find.text('時'), findsOneWidget);
    expect(tester.getTopLeft(find.text('時')).dy,
        greaterThan(tester.getTopLeft(find.text('吉')).dy));
  });

  testWidgets('Wordmark 顯示 Kairo', (tester) async {
    await tester.pumpWidget(wrap(const Wordmark(fontSize: 24)));
    expect(find.text('Kairo'), findsOneWidget);
  });
}
```

- [ ] **Step 5: Run test to verify it fails**

Run: `flutter test test/widgets/brand_test.dart`
Expected: FAIL（`brand.dart` 唔存在）

- [ ] **Step 6: Implement**

```dart
// lib/theme/brand.dart
import 'package:flutter/painting.dart';

/// 用家睇到嘅品牌名。內部識別（package／bundle ID／prefs key／備份格式／
/// 日曆識別碼「玄曆識別碼」）刻意保留 xuanli／玄曆，見 Kairo design spec D1。
const kBrandName = 'Kairo';
const kBrandSeal = '吉時';
const kBrandSealShort = '吉';

/// Kairo 裝飾色（唔入 XuanLiColors，因為深淺模式都一樣）。
class KairoPalette {
  static const night = Color(0xFF0D1120);
  static const night2 = Color(0xFF141A2E);
  static const navy = Color(0xFF1C2440);
  static const gold = Color(0xFFC9A24B);
  static const goldBright = Color(0xFFF0D78C);
  static const goldDeep = Color(0xFF8A6A28);
  static const jadeBright = Color(0xFF6FC3AD);
  static const sealRed = Color(0xFFB23A3A);
  static const paper = Color(0xFFE9DFC9);
}
```

```dart
// lib/widgets/brand.dart
import 'package:flutter/material.dart';

import '../theme/brand.dart';
import '../theme/xuanli_theme.dart';

/// 朱紅印章：一個字置中，兩個字直排。
class BrandSeal extends StatelessWidget {
  final String text;
  final double size;

  const BrandSeal({super.key, this.text = kBrandSealShort, this.size = 34});

  @override
  Widget build(BuildContext context) {
    final chars = text.split('');
    final fontSize = chars.length == 1 ? size * 0.5 : size * 0.34;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: KairoPalette.sealRed,
        borderRadius: BorderRadius.circular(size * 0.2),
        boxShadow: [
          BoxShadow(color: KairoPalette.sealRed.withValues(alpha: 0.35), blurRadius: size * 0.35),
        ],
      ),
      child: Container(
        margin: EdgeInsets.all(size * 0.08),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          border: Border.all(color: KairoPalette.paper.withValues(alpha: 0.85), width: size > 40 ? 1.2 : 0.8),
          borderRadius: BorderRadius.circular(size * 0.12),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final c in chars)
              Text(
                c,
                style: TextStyle(
                  fontFamily: XuanLiFonts.serif,
                  fontWeight: FontWeight.w900,
                  fontSize: fontSize,
                  height: 1.05,
                  color: KairoPalette.paper,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// 金色漸變「Kairo」字。
class Wordmark extends StatelessWidget {
  final double fontSize;

  const Wordmark({super.key, this.fontSize = 22});

  @override
  Widget build(BuildContext context) {
    return ShaderMask(
      blendMode: BlendMode.srcIn,
      shaderCallback: (rect) => const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [KairoPalette.goldBright, KairoPalette.gold, KairoPalette.goldDeep],
        stops: [0, 0.6, 1],
      ).createShader(rect),
      child: Text(
        kBrandName,
        style: TextStyle(
          fontFamily: XuanLiFonts.wordmark,
          fontWeight: FontWeight.w600,
          fontSize: fontSize,
          letterSpacing: fontSize * 0.1,
          height: 1.1,
          color: Colors.white,
        ),
      ),
    );
  }
}
```

- [ ] **Step 7: Run test to verify it passes**

Run: `flutter test test/widgets/brand_test.dart`
Expected: 5 tests PASS

- [ ] **Step 8: Commit**

```bash
git add lib/theme/brand.dart lib/widgets/brand.dart lib/theme/xuanli_theme.dart pubspec.yaml assets/fonts/CormorantGaramond-SemiBold.ttf assets/fonts/OFL-CormorantGaramond.txt test/widgets/brand_test.dart
git commit -m "feat: add Kairo brand constants, seal and wordmark"
```

---

### Task 3: Dart UI 字串改 Kairo＋防回退測試

**Files:**
- Modify: `lib/main.dart:29`、`lib/screens/settings/settings_screen.dart:107,123,191,193,196,204,206,238,245,247,254`、`lib/screens/activity/activity_screen.dart:76,86,156-181`、`lib/screens/today/today_screen.dart:150-183`、`lib/screens/onboarding/reveal_step.dart:245`、`lib/screens/onboarding/profile_card_step.dart:102`、`lib/screens/onboarding/welcome_step.dart:91-145`、`lib/services/data_transfer_service.dart:60`、`lib/services/share_card_service.dart:57`、`lib/services/notification_scheduler.dart:128`、`lib/widgets/share_parts.dart:50-90,122,147`
- Modify tests: `test/screens/settings/settings_screen_test.dart`、`test/screens/today/daily_stick_card_test.dart:200`、`test/services/notification_scheduler_test.dart:133`
- Create: `test/brand_strings_test.dart`

**唔改：** `lib/services/calendar_sync.dart:99` 嘅 `玄曆識別碼`（用嚟認返用家日曆入面已加嘅舊 event，改咗會重複加）；`combos.json`（「燭照玄機」「玄璧深藏」係組合名）。

- [ ] **Step 1: Write the failing guard test**

```dart
// test/brand_strings_test.dart
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// 用家睇到嘅字串唔可以再有「玄曆」。comment 唔計；日曆去重識別碼係刻意保留。
void main() {
  test('lib/ 嘅 Dart 字串冇「玄曆」（除咗日曆識別碼）', () {
    final offenders = <String>[];
    for (final f in Directory('lib').listSync(recursive: true).whereType<File>()) {
      if (!f.path.endsWith('.dart')) continue;
      final lines = f.readAsLinesSync();
      for (var i = 0; i < lines.length; i++) {
        final code = lines[i].split('//').first;
        if (code.contains('玄曆') && !code.contains('玄曆識別碼')) {
          offenders.add('${f.path}:${i + 1}');
        }
      }
    }
    expect(offenders, isEmpty);
  });

  test('印章唔再用單字「玄」', () {
    final offenders = <String>[];
    for (final f in Directory('lib').listSync(recursive: true).whereType<File>()) {
      if (!f.path.endsWith('.dart')) continue;
      final lines = f.readAsLinesSync();
      for (var i = 0; i < lines.length; i++) {
        if (lines[i].split('//').first.contains("'玄'")) offenders.add('${f.path}:${i + 1}');
      }
    }
    expect(offenders, isEmpty);
  });
}
```

- [ ] **Step 2: Run to verify it fails**

Run: `flutter test test/brand_strings_test.dart`
Expected: FAIL，列出約 25 個位置

- [ ] **Step 3: 改字串（逐個）**

`lib/main.dart`：加 `import 'theme/brand.dart';`，`title: '玄曆',` → `title: kBrandName,`

`lib/screens/settings/settings_screen.dart`（純文字替換，`玄曆` → `Kairo`，中英之間加半形空格）：
- `'玄曆資料已成功匯入 ✓'` → `'Kairo 資料已成功匯入 ✓'`
- `'匯入玄曆資料？'` → `'匯入 Kairo 資料？'`
- `'玄曆所有推薦內容（` → `'Kairo 所有推薦內容（`
- `——玄曆嘅健康'` → `——Kairo 嘅健康'`
- `，玄曆唔會上傳` → `，Kairo 唔會上傳`
- `'關於玄曆'`（兩處） → `'關於 Kairo'`
- `'玄曆 XuanLi\n版本 1.0.0\n\n'` → `'Kairo・吉時\n版本 1.0.0\n\n'`
- `'匯出玄曆資料'` → `'匯出 Kairo 資料'`；`'匯入玄曆資料'` → `'匯入 Kairo 資料'`
- `'從玄曆 JSON 備份還原'` → `'從 Kairo JSON 備份還原'`

`lib/services/data_transfer_service.dart:60`：`'匯出玄曆資料'` → `'匯出 Kairo 資料'`
`lib/services/share_card_service.dart:57`：`'玄曆・我嘅組合'` → `'Kairo・我嘅組合'`
`lib/services/notification_scheduler.dart:128`：加 `import '../theme/brand.dart';`，`'玄曆',` → `kBrandName,`
`lib/screens/activity/activity_screen.dart:76`：`'${activity.name}（玄曆吉日）'` → `'${activity.name}（Kairo 吉日）'`；`:86` `'呢個玄曆吉日已經加入過日曆'` → `'呢個 Kairo 吉日已經加入過日曆'`
`lib/screens/onboarding/reveal_step.dart:245`、`lib/screens/onboarding/profile_card_step.dart:102`：`'玄'` → `'吉'`

`lib/screens/activity/activity_screen.dart` 同 `lib/screens/today/today_screen.dart` 嘅 34×34「玄／曆」印章 `Container(...)`（成個 Container，連 child Column）換成：

```dart
const BrandSeal(size: 34),
```
並加 `import '../../widgets/brand.dart';`。

`lib/screens/onboarding/welcome_step.dart` 嘅 `_brand()` 成個 method 換成：

```dart
  Widget _brand() {
    return const Column(
      children: [
        BrandSeal(text: kBrandSeal, size: 64),
        SizedBox(height: 14),
        Wordmark(fontSize: 40),
      ],
    );
  }
```
加 `import '../../theme/brand.dart';` 同 `import '../../widgets/brand.dart';`；刪走變咗冇用嘅 `_sealRed` const（如果 analyzer 報 unused）。

`lib/widgets/share_parts.dart`：`ShareBrand.build` 換成：

```dart
  @override
  Widget build(BuildContext context) {
    return const Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        BrandSeal(size: 30),
        SizedBox(width: 10),
        Wordmark(fontSize: 26),
      ],
    );
  }
```
doc comment 改 `/// 卡頂：朱紅「吉」印＋Kairo。`；加 `import 'brand.dart';`；`semanticsLabel: '玄曆網站 QR code'` → `'Kairo 網站 QR code'`；`'玄曆 XuanLi・僅供參考'` → `'Kairo・僅供參考'`。

- [ ] **Step 4: 更新現有測試嘅期望字串**

- `test/screens/settings/settings_screen_test.dart`：全檔 `匯出玄曆資料`→`匯出 Kairo 資料`、`匯入玄曆資料`→`匯入 Kairo 資料`（包括 `匯入玄曆資料？`→`匯入 Kairo 資料？`）、`從玄曆 JSON 備份還原`→`從 Kairo JSON 備份還原`、`關於玄曆`→`關於 Kairo`
- `test/screens/today/daily_stick_card_test.dart:200`：`'玄曆網站 QR code'` → `'Kairo 網站 QR code'`
- `test/services/notification_scheduler_test.dart:133`：`'玄曆'` → `'Kairo'`
- `test/screens/onboarding/welcome_step_test.dart`：`find.text('玄曆')` → `find.text('Kairo')`；test 名「封面講清楚玄曆係咩」→「封面講清楚 Kairo 係咩」

- [ ] **Step 5: Run full suite**

Run: `flutter analyze && flutter test`
Expected: 0 issue；全部 PASS（包括 `brand_strings_test.dart`）。如有其他 test 搵 `'玄曆'` 字而 fail，照上面規則改期望值。

- [ ] **Step 6: Commit**

```bash
git add -A lib test
git commit -m "feat: rename user-facing brand to Kairo"
```

---

### Task 4: 原生／web 顯示名

**Files:**
- Modify: `android/app/src/main/AndroidManifest.xml:6`、`android/app/src/main/res/values/strings.xml:3,5`、`ios/Runner/Info.plist:10,41,43`、`web/index.html:21,26,32`、`web/manifest.json:2-3`、`ios/XuanLiWidget/XuanLiWidget.swift`（`configurationDisplayName`）

- [ ] **Step 1: 改**

- AndroidManifest：`android:label="玄曆"` → `android:label="Kairo"`
- strings.xml：`玄曆・今日` → `Kairo・今日`；`玄曆・今日宜忌` → `Kairo・今日宜忌`
- Info.plist：`CFBundleDisplayName` 值 `玄曆` → `Kairo`；兩句日曆權限 `玄曆需要…` → `Kairo 需要…`
- web/index.html：description `玄曆 XuanLi — 中國傳統擇日…` → `Kairo 吉時 — 中國傳統擇日…`；`apple-mobile-web-app-title` → `Kairo`；`<title>` → `Kairo 吉時`
- web/manifest.json：`"name": "Kairo 吉時"`、`"short_name": "Kairo"`
- `ios/XuanLiWidget/XuanLiWidget.swift`：`grep -n "玄曆" ios/XuanLiWidget/*.swift`，每個用家睇到嘅 `玄曆` → `Kairo`（`kind` 字串 `XuanLiWidget` 唔改）

- [ ] **Step 2: Verify**

Run: `grep -rn "玄曆" android/app/src ios/Runner ios/XuanLiWidget web`
Expected: 冇輸出

Run: `plutil -lint ios/Runner/Info.plist ios/XuanLiWidget/Info.plist && python3 -c "import json;json.load(open('web/manifest.json'))" && xmllint --noout android/app/src/main/AndroidManifest.xml android/app/src/main/res/values/strings.xml`
Expected: 全部 OK，冇 error

- [ ] **Step 3: Commit**

```bash
git add android/app/src ios/Runner/Info.plist ios/XuanLiWidget web/index.html web/manifest.json
git commit -m "feat: rename native and web display names to Kairo"
```

---

### Task 5: 夜空深色 palette＋新用戶預設深色

**Files:**
- Modify: `lib/theme/xuanli_theme.dart`（`XuanLiColors.dark`）
- Modify: `lib/models/settings.dart:26`、`lib/services/theme_mode_controller.dart:8`
- Modify tests: `test/theme/xuanli_theme_test.dart:40-50`、`test/services/storage_service_test.dart:61-63`、`test/services/data_transfer_service_test.dart:76`

- [ ] **Step 1: 改測試期望（先 fail）**

`test/theme/xuanli_theme_test.dart` 嘅 dark hex test 改成：

```dart
    test('XuanLiColors.dark 係 Kairo 夜空 palette', () {
      expect(XuanLiColors.dark.paper, const Color(0xFF0D1120));
      expect(XuanLiColors.dark.paper2, const Color(0xFF141A2E));
      expect(XuanLiColors.dark.cardSurface, const Color(0xFF1C2440));
      expect(XuanLiColors.dark.ink, const Color(0xFFE9DFC9));
      expect(XuanLiColors.dark.ink60, const Color(0x99E9DFC9));
      expect(XuanLiColors.dark.ink30, const Color(0x40E9DFC9));
      expect(XuanLiColors.dark.ink12, const Color(0x1FE9DFC9));
      expect(XuanLiColors.dark.red, const Color(0xFFE57A6F));
      expect(XuanLiColors.dark.gold, const Color(0xFFC9A24B));
      expect(XuanLiColors.dark.jade, const Color(0xFF6FC3AD));
    });
```
（保留原 test 入面其他斷言；如原本有 red／gold／jade 行，用上面嘅值取代。）

`test/services/storage_service_test.dart`：test 名改「…（深色・通知開・07:30）」，`expect(result.themeMode, ThemeMode.system);` → `ThemeMode.dark`。
`test/services/data_transfer_service_test.dart:76`：先睇 context（`sed -n 60,80p`）——如果嗰行係驗「匯入後 settings 還原做預設」，改做 `ThemeMode.dark`。

Run: `flutter test test/theme test/services/storage_service_test.dart test/services/data_transfer_service_test.dart`
Expected: FAIL（顏色同預設值未改）

- [ ] **Step 2: Implement**

`lib/theme/xuanli_theme.dart` `XuanLiColors.dark`：

```dart
  static const dark = XuanLiColors(
    paper: Color(0xFF0D1120), // Kairo night
    paper2: Color(0xFF141A2E), // Kairo night2
    cardSurface: Color(0xFF1C2440),
    ink: Color(0xFFE9DFC9),
    ink60: Color(0x99E9DFC9),
    ink30: Color(0x40E9DFC9),
    ink12: Color(0x1FE9DFC9),
    red: Color(0xFFE57A6F), // kairo-preview 忌
    gold: Color(0xFFC9A24B),
    jade: Color(0xFF6FC3AD), // kairo-preview 宜
  );
```
頂部 doc comment 加一句：`/// 深色 palette 跟 design/kairo-preview.html（2026-10-13 Kairo 改版）。`

`lib/models/settings.dart:26`：`themeMode: ThemeMode.system,` → `themeMode: ThemeMode.dark,`
`lib/services/theme_mode_controller.dart:8`：`ValueNotifier(ThemeMode.system)` → `ValueNotifier(ThemeMode.dark)`

- [ ] **Step 3: Run full suite**

Run: `flutter analyze && flutter test`
Expected: 全 PASS。`test/widget_test.dart:74` 同 `settings_screen_test.dart:39` 嘅 tearDown 將 controller 設返 `system` 只係清理，唔使改。

- [ ] **Step 4: Commit**

```bash
git add lib/theme/xuanli_theme.dart lib/models/settings.dart lib/services/theme_mode_controller.dart test
git commit -m "feat: Kairo night palette and dark mode by default"
```

---

### Task 6: Starfield

**Files:**
- Create: `lib/widgets/starfield.dart`
- Test: `test/widgets/starfield_test.dart`

- [ ] **Step 1: Write the failing test**

```dart
// test/widgets/starfield_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xuanli/theme/motion.dart';
import 'package:xuanli/widgets/starfield.dart';

void main() {
  tearDown(() => Motion.ambientEnabled = false);

  test('starSpecs deterministic，位置喺 0–1', () {
    final a = starSpecs(46);
    final b = starSpecs(46);
    expect(a.length, 46);
    for (var i = 0; i < a.length; i++) {
      expect(a[i].x, b[i].x);
      expect(a[i].y, b[i].y);
      expect(a[i].x, inInclusiveRange(0, 1));
      expect(a[i].y, inInclusiveRange(0, 1));
    }
  });

  testWidgets('環境動畫關咗 → 靜止，冇 running animation', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: Starfield()));
    expect(find.byType(Starfield), findsOneWidget);
    expect(tester.hasRunningAnimations, isFalse);
  });

  testWidgets('環境動畫開咗 → 會閃', (tester) async {
    Motion.ambientEnabled = true;
    await tester.pumpWidget(const MaterialApp(home: Starfield()));
    await tester.pump(const Duration(milliseconds: 100));
    expect(tester.hasRunningAnimations, isTrue);
    await tester.pumpWidget(const SizedBox()); // dispose ticker
  });
}
```

- [ ] **Step 2: Run to verify it fails**

Run: `flutter test test/widgets/starfield_test.dart`
Expected: FAIL（檔案唔存在）

- [ ] **Step 3: Implement**

```dart
// lib/widgets/starfield.dart
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/motion.dart';

class StarSpec {
  final double x, y, phase, speed, radius;
  const StarSpec(this.x, this.y, this.phase, this.speed, this.radius);
}

/// 固定公式（唔用 Random），每次 render 一樣。
List<StarSpec> starSpecs(int count) => [
      for (var i = 0; i < count; i++)
        StarSpec(
          (i * 37.7 % 100) / 100,
          (i * 61.3 % 100) / 100,
          (i % 7) / 7,
          0.6 + (i % 5) * 0.25,
          i % 9 == 0 ? 1.4 : 0.9,
        ),
    ];

/// 閃爍星空背景。放喺 Stack 最底，填滿父層。
class Starfield extends StatefulWidget {
  final int count;
  final Color color;

  const Starfield({super.key, this.count = 46, this.color = Colors.white});

  @override
  State<Starfield> createState() => _StarfieldState();
}

class _StarfieldState extends State<Starfield> with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: const Duration(seconds: 6));
  late final List<StarSpec> _stars = starSpecs(widget.count);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (Motion.ambient(context)) {
      if (!_c.isAnimating) _c.repeat();
    } else {
      _c.stop();
      _c.value = 0.25;
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: RepaintBoundary(
        child: CustomPaint(
          size: Size.infinite,
          painter: _StarPainter(_stars, _c, widget.color),
        ),
      ),
    );
  }
}

class _StarPainter extends CustomPainter {
  final List<StarSpec> stars;
  final Animation<double> t;
  final Color color;

  _StarPainter(this.stars, this.t, this.color) : super(repaint: t);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint();
    for (final s in stars) {
      final wave = 0.5 + 0.5 * math.sin(2 * math.pi * (t.value * s.speed + s.phase));
      paint.color = color.withValues(alpha: 0.08 + 0.7 * wave);
      canvas.drawCircle(Offset(s.x * size.width, s.y * size.height), s.radius, paint);
    }
  }

  @override
  bool shouldRepaint(_StarPainter old) => old.stars != stars || old.color != color;
}
```

- [ ] **Step 4: Run to verify it passes**

Run: `flutter test test/widgets/starfield_test.dart`
Expected: 3 PASS

- [ ] **Step 5: Commit**

```bash
git add lib/widgets/starfield.dart test/widgets/starfield_test.dart
git commit -m "feat: add deterministic twinkling starfield"
```

---

### Task 7: 天體儀投影數學（純函數）

**Files:**
- Create: `lib/widgets/orrery_geometry.dart`
- Test: `test/widgets/orrery_geometry_test.dart`

- [ ] **Step 1: Write the failing test**

```dart
// test/widgets/orrery_geometry_test.dart
import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:xuanli/widgets/orrery_geometry.dart';

void main() {
  const c = Offset(100, 100);

  test('冇傾斜：每點距中心 = 半徑，depth 0', () {
    for (final p in projectRing(radius: 50, pose: const RingPose(), center: c)) {
      expect((p.offset - c).distance, closeTo(50, 1e-9));
      expect(p.depth, closeTo(0, 1e-9));
    }
  });

  test('繞 X 傾斜 90°：全部點落喺水平線', () {
    final pose = const RingPose(tiltX: math.pi / 2);
    for (final p in projectRing(radius: 50, pose: pose, center: c)) {
      expect(p.offset.dy, closeTo(c.dy, 1e-9));
    }
  });

  test('depth > 0 嘅點（近鏡頭）投影會放大', () {
    final pose = const RingPose(tiltX: math.pi / 2, tiltY: 0.3);
    final near = projectRingPoint(radius: 50, angle: math.pi / 2, pose: pose, center: c);
    final far = projectRingPoint(radius: 50, angle: -math.pi / 2, pose: pose, center: c);
    expect(near.depth, greaterThan(0));
    expect(far.depth, lessThan(0));
    expect((near.offset - c).distance, greaterThan((far.offset - c).distance));
  });

  test('spin 只係沿環轉，唔改環形狀', () {
    final a = projectRing(radius: 50, pose: const RingPose(tiltX: 1.1), center: c, segments: 360);
    final b = projectRing(radius: 50, pose: const RingPose(tiltX: 1.1, spin: 2 * math.pi / 360), center: c, segments: 360);
    expect(b[0].offset.dx, closeTo(a[1].offset.dx, 1e-9));
    expect(b[0].offset.dy, closeTo(a[1].offset.dy, 1e-9));
  });

  test('segments + 1 個點（頭尾相接）', () {
    expect(projectRing(radius: 10, pose: const RingPose(), center: c, segments: 24).length, 25);
  });
}
```

- [ ] **Step 2: Run to verify it fails**

Run: `flutter test test/widgets/orrery_geometry_test.dart`
Expected: FAIL（檔案唔存在）

- [ ] **Step 3: Implement**

```dart
// lib/widgets/orrery_geometry.dart
import 'dart:math' as math;
import 'dart:ui';

/// 投影後嘅點：畫面位置＋depth（> 0 = 向住鏡頭，即「前面」）。
class ProjectedPoint {
  final Offset offset;
  final double depth;
  const ProjectedPoint(this.offset, this.depth);
}

/// 一個環嘅姿勢：環原本喺畫面平面（XY），先沿自己圓周轉 [spin]，
/// 再繞 X 軸傾 [tiltX]，最後繞 Y 軸轉 [tiltY]（全部弧度）。
class RingPose {
  final double tiltX, tiltY, spin;
  const RingPose({this.tiltX = 0, this.tiltY = 0, this.spin = 0});
}

ProjectedPoint projectRingPoint({
  required double radius,
  required double angle,
  required RingPose pose,
  required Offset center,
  double perspective = 900,
}) {
  final a = angle + pose.spin;
  var x = radius * math.cos(a);
  var y = radius * math.sin(a);
  var z = 0.0;

  final cx = math.cos(pose.tiltX), sx = math.sin(pose.tiltX);
  final y1 = y * cx - z * sx;
  final z1 = y * sx + z * cx;
  y = y1;
  z = z1;

  final cy = math.cos(pose.tiltY), sy = math.sin(pose.tiltY);
  final x2 = x * cy + z * sy;
  final z2 = -x * sy + z * cy;
  x = x2;
  z = z2;

  final s = perspective / (perspective - z);
  return ProjectedPoint(center + Offset(x * s, y * s), z);
}

List<ProjectedPoint> projectRing({
  required double radius,
  required RingPose pose,
  required Offset center,
  int segments = 96,
  double perspective = 900,
}) =>
    [
      for (var i = 0; i <= segments; i++)
        projectRingPoint(
          radius: radius,
          angle: 2 * math.pi * i / segments,
          pose: pose,
          center: center,
          perspective: perspective,
        ),
    ];
```

- [ ] **Step 4: Run to verify it passes**

Run: `flutter test test/widgets/orrery_geometry_test.dart`
Expected: 5 PASS

- [ ] **Step 5: Commit**

```bash
git add lib/widgets/orrery_geometry.dart test/widgets/orrery_geometry_test.dart
git commit -m "feat: add orrery ring projection math"
```

---

### Task 8: Orrery widget

**Files:**
- Create: `lib/widgets/orrery.dart`
- Test: `test/widgets/orrery_test.dart`

- [ ] **Step 1: Write the failing test**

```dart
// test/widgets/orrery_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xuanli/theme/motion.dart';
import 'package:xuanli/widgets/orrery.dart';

void main() {
  tearDown(() => Motion.ambientEnabled = false);
  Widget wrap(Widget c) => MaterialApp(home: Scaffold(body: Center(child: c)));

  testWidgets('尺寸跟 size；核心 child 顯示喺中間', (tester) async {
    await tester.pumpWidget(wrap(const Orrery(size: 220, core: Text('86'))));
    expect(tester.getSize(find.byType(Orrery)), const Size(220, 220));
    expect(find.text('86'), findsOneWidget);
    expect(tester.getCenter(find.text('86')).dx,
        closeTo(tester.getCenter(find.byType(Orrery)).dx, 1));
  });

  testWidgets('冇 core 都 render 到（開機畫面用）', (tester) async {
    await tester.pumpWidget(wrap(const Orrery(size: 160)));
    expect(find.byType(Orrery), findsOneWidget);
  });

  testWidgets('環境動畫關咗：靜止', (tester) async {
    await tester.pumpWidget(wrap(const Orrery()));
    expect(tester.hasRunningAnimations, isFalse);
  });

  testWidgets('環境動畫開咗：轉緊', (tester) async {
    Motion.ambientEnabled = true;
    await tester.pumpWidget(wrap(const Orrery()));
    await tester.pump(const Duration(milliseconds: 200));
    expect(tester.hasRunningAnimations, isTrue);
    await tester.pumpWidget(const SizedBox());
  });
}
```

- [ ] **Step 2: Run to verify it fails**

Run: `flutter test test/widgets/orrery_test.dart`
Expected: FAIL

- [ ] **Step 3: Implement**

```dart
// lib/widgets/orrery.dart
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/brand.dart';
import '../theme/motion.dart';
import 'orrery_geometry.dart';

/// 天體儀：後層環 → 核心球（可放 [core]）→ 前層環，做出環繞住球嘅遮擋感。
/// 一圈 38 秒；環境動畫關咗就停喺固定角度。
class Orrery extends StatefulWidget {
  final double size;
  final Widget? core;

  /// 核心球直徑佔 [size] 嘅比例。
  final double coreFraction;

  const Orrery({super.key, this.size = 220, this.core, this.coreFraction = 0.5});

  @override
  State<Orrery> createState() => _OrreryState();
}

class _OrreryState extends State<Orrery> with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: const Duration(seconds: 38));

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (Motion.ambient(context)) {
      if (!_c.isAnimating) _c.repeat();
    } else {
      _c.stop();
      _c.value = 0.12;
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.size;
    return SizedBox.square(
      dimension: s,
      child: Stack(
        alignment: Alignment.center,
        children: [
          ExcludeSemantics(
            child: RepaintBoundary(
              child: CustomPaint(size: Size.square(s), painter: _OrreryPainter(_c, front: false)),
            ),
          ),
          OrreryCore(diameter: s * widget.coreFraction, child: widget.core),
          IgnorePointer(
            child: ExcludeSemantics(
              child: RepaintBoundary(
                child: CustomPaint(size: Size.square(s), painter: _OrreryPainter(_c, front: true)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 立體深藍球＋金邊光暈。
class OrreryCore extends StatelessWidget {
  final double diameter;
  final Widget? child;

  const OrreryCore({super.key, required this.diameter, this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: diameter,
      height: diameter,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: const RadialGradient(
          center: Alignment(-0.1, 0.1),
          colors: [Color(0xFF3A4677), KairoPalette.navy, Color(0xFF0E1328)],
          stops: [0, 0.62, 1],
        ),
        border: Border.all(color: KairoPalette.gold.withValues(alpha: 0.6)),
        boxShadow: [
          BoxShadow(color: KairoPalette.gold.withValues(alpha: 0.35), blurRadius: diameter * 0.35),
        ],
      ),
      foregroundDecoration: const BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          center: Alignment(-0.35, -0.45),
          radius: 0.45,
          colors: [Color(0x80FFFFFF), Color(0x00FFFFFF)],
        ),
      ),
      child: child,
    );
  }
}

class _RingSpec {
  final double radius; // 佔半邊 size 比例
  final RingPose Function(double t) pose;
  final Color color;
  final double width;
  final bool dashed;
  const _RingSpec(this.radius, this.pose, this.color, this.width, {this.dashed = false});
}

const _tilt = 1.12; // ≈ 64°

final _rings = <_RingSpec>[
  _RingSpec(0.84, (t) => RingPose(tiltX: _tilt, spin: t * 2 * math.pi), KairoPalette.gold, 1.6),
  _RingSpec(1.0, (t) => RingPose(tiltX: _tilt, spin: -t * 2 * math.pi), KairoPalette.gold.withValues(alpha: 0.45), 1.0, dashed: true),
  _RingSpec(0.78, (t) => RingPose(tiltX: 0.25, tiltY: t * 4 * math.pi), KairoPalette.goldBright.withValues(alpha: 0.7), 1.2),
  _RingSpec(0.72, (t) => RingPose(tiltX: 0.6, tiltY: -t * 3 * math.pi), KairoPalette.jadeBright.withValues(alpha: 0.7), 1.2),
];

class _OrreryPainter extends CustomPainter {
  final Animation<double> t;
  final bool front;

  _OrreryPainter(this.t, {required this.front}) : super(repaint: t);

  bool _mine(double depth) => front ? depth >= 0 : depth < 0;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final half = size.width / 2 * 0.92;
    final v = t.value;

    for (final ring in _rings) {
      final pts = projectRing(radius: half * ring.radius, pose: ring.pose(v), center: c);
      final paint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeWidth = ring.width
        ..color = front ? ring.color : ring.color.withValues(alpha: ring.color.a * 0.4);
      for (var i = 0; i < pts.length - 1; i++) {
        if (ring.dashed && i.isOdd) continue;
        if (!_mine((pts[i].depth + pts[i + 1].depth) / 2)) continue;
        canvas.drawLine(pts[i].offset, pts[i + 1].offset, paint);
      }
    }

    // 主環刻度（24 格）。
    final main = _rings.first;
    final tickPaint = Paint()
      ..color = KairoPalette.gold.withValues(alpha: front ? 0.9 : 0.35)
      ..strokeWidth = 1;
    for (var k = 0; k < 24; k++) {
      final a = 2 * math.pi * k / 24;
      final p1 = projectRingPoint(radius: half * main.radius, angle: a, pose: main.pose(v), center: c);
      if (!_mine(p1.depth)) continue;
      final p2 = projectRingPoint(radius: half * main.radius * 1.06, angle: a, pose: main.pose(v), center: c);
      canvas.drawLine(p1.offset, p2.offset, tickPaint);
    }

    // 兩粒行星。
    _planet(canvas, c, half * _rings[0].radius, _rings[0].pose(v), v * 8 * math.pi, KairoPalette.goldBright, KairoPalette.gold, 7);
    _planet(canvas, c, half * _rings[1].radius, _rings[1].pose(v), -v * 5 * math.pi, const Color(0xFFD9FFF4), KairoPalette.jadeBright, 4.5);
  }

  void _planet(Canvas canvas, Offset c, double r, RingPose pose, double angle, Color hi, Color base, double radius) {
    final p = projectRingPoint(radius: r, angle: angle, pose: pose, center: c);
    if (!_mine(p.depth)) return;
    final rect = Rect.fromCircle(center: p.offset, radius: radius);
    canvas.drawCircle(p.offset, radius * 1.8, Paint()..color = base.withValues(alpha: 0.25));
    canvas.drawCircle(
      p.offset,
      radius,
      Paint()
        ..shader = RadialGradient(center: const Alignment(-0.4, -0.4), colors: [hi, base, Color.lerp(base, Colors.black, 0.6)!], stops: const [0, 0.45, 1])
            .createShader(rect),
    );
  }

  @override
  bool shouldRepaint(_OrreryPainter old) => old.front != front;
}
```

- [ ] **Step 4: Run to verify it passes**

Run: `flutter test test/widgets/orrery_test.dart`
Expected: 4 PASS

- [ ] **Step 5: 肉眼檢查**

加暫時 golden（唔 commit）：

```bash
cat > /private/tmp/claude-503/-Users-stephanieau-dev-xuanli/orrery_peek_test.dart <<'EOF'
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xuanli/widgets/orrery.dart';
void main() {
  testWidgets('peek', (t) async {
    await t.pumpWidget(const MaterialApp(home: ColoredBox(color: Color(0xFF0D1120), child: Center(child: RepaintBoundary(child: Orrery(size: 300))))));
    await expectLater(find.byType(Orrery), matchesGoldenFile('orrery_peek.png'));
  });
}
EOF
cp /private/tmp/claude-503/-Users-stephanieau-dev-xuanli/orrery_peek_test.dart test/orrery_peek_test.dart
flutter test --update-goldens test/orrery_peek_test.dart
```
用 Read 睇 `test/orrery_peek.png`：要見到傾斜金環、刻度、兩粒行星、核心球同前／後層遮擋。唔靚就調 `_rings` 參數再睇。睇完：`mv test/orrery_peek_test.dart test/orrery_peek.png _to_delete/`

- [ ] **Step 6: Commit**

```bash
git add lib/widgets/orrery.dart test/widgets/orrery_test.dart
git commit -m "feat: add 3D orrery widget"
```

---

### Task 9: 開機畫面＋封面加天體儀

**Files:**
- Modify: `lib/main.dart`（`_AppBootstrapState.build` loading 分支）
- Modify: `lib/screens/onboarding/welcome_step.dart`（`build`、`_brand`）
- Modify: `test/widget_test.dart:86`
- Test: `test/screens/onboarding/welcome_step_test.dart`（加一個 test）

- [ ] **Step 1: 改測試（先 fail）**

`test/widget_test.dart:86`：

```dart
    expect(find.byType(Orrery), findsOneWidget);
    expect(find.text('Kairo'), findsOneWidget);
```
加 `import 'package:xuanli/widgets/orrery.dart';`

`test/screens/onboarding/welcome_step_test.dart` 加：

```dart
  testWidgets('封面有天體儀、Kairo 字同吉時印', (tester) async {
    await tester.pumpWidget(wrap());
    await tester.pumpAndSettle();
    expect(find.byType(Orrery), findsOneWidget);
    expect(find.text('Kairo'), findsOneWidget);
    expect(find.text('吉'), findsOneWidget);
    expect(find.text('時'), findsOneWidget);
  });
```
（用該檔現有 `wrap({onStart, disableAnimations})`。加 `import 'package:xuanli/widgets/orrery.dart';`）

Run: `flutter test test/widget_test.dart test/screens/onboarding/welcome_step_test.dart`
Expected: FAIL

- [ ] **Step 2: Implement**

`lib/main.dart` loading 分支換成：

```dart
        if (snapshot.connectionState != ConnectionState.done) {
          return const Scaffold(
            backgroundColor: KairoPalette.night,
            body: Stack(
              children: [
                Positioned.fill(child: Starfield()),
                Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Orrery(size: 220, coreFraction: 0.36),
                      SizedBox(height: 18),
                      Wordmark(fontSize: 44),
                    ],
                  ),
                ),
              ],
            ),
          );
        }
```
加 imports：`theme/brand.dart`、`widgets/brand.dart`、`widgets/orrery.dart`、`widgets/starfield.dart`。

`lib/screens/onboarding/welcome_step.dart`：
- `build` 入面 `ColoredBox(color: revealBackground, child: SafeArea(...))` 改成 `ColoredBox(color: revealBackground, child: Stack(children: [const Positioned.fill(child: Starfield()), SafeArea(...)]))`
- `_brand()` 改成：

```dart
  Widget _brand() {
    return const Column(
      children: [
        Orrery(size: 170, coreFraction: 0.34, core: BrandSeal(text: kBrandSeal, size: 40)),
        SizedBox(height: 10),
        Wordmark(fontSize: 40),
      ],
    );
  }
```
加 imports：`../../widgets/orrery.dart`、`../../widgets/starfield.dart`。

- [ ] **Step 3: Run**

Run: `flutter test test/widget_test.dart test/screens/onboarding/`
Expected: PASS。如果 welcome 喺 360×640 overflow test fail，將 `_brand` 之後嘅 `SizedBox(height: 34)` 減到 22。

- [ ] **Step 4: Commit**

```bash
git add lib/main.dart lib/screens/onboarding/welcome_step.dart test/widget_test.dart test/screens/onboarding/welcome_step_test.dart
git commit -m "feat: orrery splash and welcome hero"
```

---

### Task 10: 今日頁 — 天體儀分數、品牌 header、立體 7 日條、星空

**Files:**
- Modify: `lib/screens/today/today_widgets.dart`（`ScoreRing` 加 `size`；`Week7Strip._buildDay`）
- Modify: `lib/screens/today/today_screen.dart`（分數區、header、星空）
- Test: `test/screens/today/today_widgets_test.dart`、`test/screens/today/today_screen_test.dart`

- [ ] **Step 1: Write failing tests**

`test/screens/today/today_widgets_test.dart` 嘅 `group('ScoreRing')` 加：

```dart
    testWidgets('size 參數控制尺寸', (tester) async {
      await tester.pumpWidget(wrap(
        const ScoreRing(score: 75, ringColor: Colors.teal, label: '契合', size: 72),
      ));
      expect(tester.getSize(find.byType(ScoreRing)), const Size(72, 72));
    });
```

`test/screens/today/today_screen_test.dart` 加（用該檔現有 `wrap`／`profile`）：

```dart
  testWidgets('今日頁：天體儀中心顯示命理分，旁邊細環顯示契合度，header 有 Kairo', (tester) async {
    await tester.pumpWidget(wrap(TodayScreen(profile: profile, initialDate: DateTime(2026, 7, 20))));
    await tester.pumpAndSettle();
    expect(find.byType(Orrery), findsOneWidget);
    expect(find.descendant(of: find.byType(Orrery), matching: find.textContaining('命理分')), findsOneWidget);
    expect(find.textContaining('狀態契合'), findsOneWidget);
    expect(find.text('Kairo'), findsOneWidget);
  });

  testWidgets('今日頁 360×640 唔 overflow', (tester) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(wrap(TodayScreen(profile: profile, initialDate: DateTime(2026, 7, 20))));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
```
加 `import 'package:xuanli/widgets/orrery.dart';`

Run: `flutter test test/screens/today/`
Expected: FAIL

- [ ] **Step 2: `ScoreRing` 加 size**

`lib/screens/today/today_widgets.dart` `ScoreRing`：加欄位 `final double size;`、constructor `this.size = 104,`；`build` 內兩個 `104` 改 `size`；`strokeWidth: 9` → `strokeWidth: size * 0.087`；分數 `fontSize: 30` → `fontSize: size * 0.29`；label `fontSize: 10` → `fontSize: size < 90 ? 8.5 : 10`。`backgroundColor: colors.paper2` 保留。

- [ ] **Step 3: 分數區換天體儀**

`lib/screens/today/today_screen.dart`，將現有 `Container(padding: …, decoration: …, child: Row(… ScoreRing … ScoreRing …))` 成段換成：

```dart
            SizedBox(
              height: 250,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Orrery(
                    size: 240,
                    core: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '${reading.fortuneScore}',
                          style: const TextStyle(
                            fontFamily: XuanLiFonts.serif,
                            fontSize: 44,
                            fontWeight: FontWeight.w900,
                            height: 1,
                            color: KairoPalette.goldBright,
                            shadows: [Shadow(color: Color(0x99C9A24B), blurRadius: 12)],
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          '命理分・${reading.band}',
                          style: const TextStyle(fontSize: 10, letterSpacing: 1.5, color: KairoPalette.paper),
                        ),
                      ],
                    ),
                  ),
                  Positioned(
                    right: 0,
                    bottom: 0,
                    child: Column(
                      children: [
                        ScoreRing(score: reading.mbtiScore, ringColor: colors.jade, label: '契合', size: 70),
                        const SizedBox(height: 4),
                        Text(
                          '狀態契合・${widget.profile.mbti}',
                          style: TextStyle(fontSize: 9.5, color: colors.ink60),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
```
（核心球永遠係深藍，所以核心字用固定亮色，唔跟淺色主題 ink。）

- [ ] **Step 4: Header**

`_buildHeader` 嘅 Row children 換成：

```dart
        const BrandSeal(size: 30),
        const SizedBox(width: 8),
        const Wordmark(fontSize: 22),
        const Spacer(),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              '${_selectedDate.month}月${_selectedDate.day}日 星期$weekdayChar',
              style: TextStyle(
                fontFamily: XuanLiFonts.serif,
                fontWeight: FontWeight.w700,
                fontSize: 14,
                letterSpacing: 1.5,
                color: colors.ink,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              '${reading.lunarLabel}・${reading.ganzhiDay}日・${reading.chong}',
              style: TextStyle(fontSize: 10.5, color: colors.ink60),
            ),
          ],
        ),
```
（原本右邊嘅 menu 圓掣只彈「設定 — 2g 起」placeholder snackbar，設定已經喺 TabShell 頂 bar，刪走佢。如有 test 撳嗰粒掣，一併刪該 test。）

- [ ] **Step 5: 星空背景（只喺深色）**

`build` 最外層 `return SafeArea(...)` 改成：

```dart
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Stack(
      children: [
        if (isDark) const Positioned.fill(child: Starfield()),
        SafeArea(
          // …原本內容不變…
        ),
      ],
    );
```

- [ ] **Step 6: 7 日條立體感**

`Week7Strip._buildDay` 最後 `return GestureDetector(...)` 改成包一層 Transform：

```dart
    final cell = GestureDetector(
      onTap: () => onSelect(reading.date),
      child: Container(/* …原本 Container 不變… */),
    );
    return Transform(
      alignment: Alignment.bottomCenter,
      transform: Matrix4.identity()
        ..setEntry(3, 2, 0.002)
        ..translate(0.0, isToday ? -5.0 : 0.0)
        ..rotateX(isToday ? 0 : 0.3),
      child: cell,
    );
```
Today 格 Container 加 `boxShadow: isToday ? [BoxShadow(color: colors.gold.withValues(alpha: 0.3), blurRadius: 14, offset: const Offset(0, 6))] : null`。

today_screen.dart 加 imports：`../../theme/brand.dart`、`../../widgets/orrery.dart`、`../../widgets/starfield.dart`（`brand.dart` widget import Task 3 已加）。

- [ ] **Step 7: Run**

Run: `flutter analyze && flutter test test/screens/today/ test/screens/tab_shell_test.dart`
Expected: PASS。如果 7 日條舊 test 用 `tap` 撳格因 Transform 偏移失手，改用 `tester.tap(find.text('21'))` 之類搵字撳。

- [ ] **Step 8: Commit**

```bash
git add lib/screens/today test/screens/today
git commit -m "feat: orrery score hero, brand header and 3D week strip on Today"
```

---

### Task 11: 傾斜數學＋搖動偵測＋sensors_plus

**Files:**
- Create: `lib/widgets/tilt_math.dart`、`lib/services/shake_detector.dart`
- Modify: `pubspec.yaml`（`sensors_plus`）
- Test: `test/widgets/tilt_math_test.dart`、`test/services/shake_detector_test.dart`

- [ ] **Step 1: 加 dependency**

Run: `flutter pub add sensors_plus`
Expected: pubspec 多咗 `sensors_plus: ^x.y.z`。確認佢 README 冇任何網絡行為（純本機感應器）。

- [ ] **Step 2: Write failing tests**

```dart
// test/widgets/tilt_math_test.dart
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:xuanli/widgets/tilt_math.dart';

void main() {
  test('中間 → 冇傾斜', () {
    final a = tiltAngles(Offset.zero);
    expect(a.rotateX, 0);
    expect(a.rotateY, 0);
  });

  test('右邊 → 繞 Y 正轉；上面 → 繞 X 正轉；夾喺最大值', () {
    final a = tiltAngles(const Offset(1, -1));
    expect(a.rotateY, closeTo(kMaxTiltY, 1e-9));
    expect(a.rotateX, closeTo(kMaxTiltX, 1e-9));
    final b = tiltAngles(const Offset(5, 5));
    expect(b.rotateY, closeTo(kMaxTiltY, 1e-9));
    expect(b.rotateX, closeTo(-kMaxTiltX, 1e-9));
  });

  test('pointerToNormalized：框內位置 → -1..1', () {
    const size = Size(200, 100);
    expect(pointerToNormalized(const Offset(100, 50), size), Offset.zero);
    expect(pointerToNormalized(const Offset(200, 0), size), const Offset(1, -1));
  });

  test('gravityToNormalized：平放手機（ax 0, ay ~6.5）≈ 中間', () {
    final n = gravityToNormalized(0, 6.5);
    expect(n.dx, closeTo(0, 1e-9));
    expect(n.dy, closeTo(0, 1e-9));
  });

  test('gravityToNormalized：向左側 ax>0 → dx<0，夾喺 -1..1', () {
    final n = gravityToNormalized(20, 6.5);
    expect(n.dx, -1);
  });
}
```

```dart
// test/services/shake_detector_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:xuanli/services/shake_detector.dart';

void main() {
  test('單次大力 → 唔算搖', () {
    final d = ShakeDetector();
    expect(d.add(magnitude: 20, at: const Duration(milliseconds: 0)), isFalse);
  });

  test('1 秒內兩次超過門檻 → 搖', () {
    final d = ShakeDetector();
    d.add(magnitude: 15, at: const Duration(milliseconds: 0));
    expect(d.add(magnitude: 15, at: const Duration(milliseconds: 400)), isTrue);
  });

  test('相隔太耐 → 唔算', () {
    final d = ShakeDetector();
    d.add(magnitude: 15, at: const Duration(milliseconds: 0));
    expect(d.add(magnitude: 15, at: const Duration(milliseconds: 1500)), isFalse);
  });

  test('觸發後冷卻 2 秒', () {
    final d = ShakeDetector();
    d.add(magnitude: 15, at: Duration.zero);
    d.add(magnitude: 15, at: const Duration(milliseconds: 300));
    d.add(magnitude: 15, at: const Duration(milliseconds: 600));
    expect(d.add(magnitude: 15, at: const Duration(milliseconds: 900)), isFalse);
  });

  test('細力唔計', () {
    final d = ShakeDetector();
    d.add(magnitude: 5, at: Duration.zero);
    expect(d.add(magnitude: 5, at: const Duration(milliseconds: 200)), isFalse);
  });
}
```

Run: `flutter test test/widgets/tilt_math_test.dart test/services/shake_detector_test.dart`
Expected: FAIL

- [ ] **Step 3: Implement**

```dart
// lib/widgets/tilt_math.dart
import 'dart:ui';

const kMaxTiltX = 0.19; // ≈ 11°
const kMaxTiltY = 0.23; // ≈ 13°

class TiltAngles {
  final double rotateX, rotateY;
  const TiltAngles(this.rotateX, this.rotateY);
}

/// [n] 係 -1..1 嘅位置（右／下為正）。上面向住你 → rotateX 正。
TiltAngles tiltAngles(Offset n) => TiltAngles(
      -n.dy.clamp(-1.0, 1.0) * kMaxTiltX,
      n.dx.clamp(-1.0, 1.0) * kMaxTiltY,
    );

Offset pointerToNormalized(Offset local, Size size) => Offset(
      (local.dx / size.width * 2 - 1).clamp(-1.0, 1.0),
      (local.dy / size.height * 2 - 1).clamp(-1.0, 1.0),
    );

/// 加速計重力（m/s²）→ -1..1。手機自然拎住（約 40° 斜）時 ay ≈ 6.5 當中間。
Offset gravityToNormalized(double ax, double ay) => Offset(
      (-ax / 4).clamp(-1.0, 1.0),
      ((ay - 6.5) / 4).clamp(-1.0, 1.0),
    );
```

```dart
// lib/services/shake_detector.dart

/// 純 Dart 搖動偵測：餵入「去咗重力」嘅加速度大小（m/s²）同時間。
/// [window] 內有 [hits] 次超過 [threshold] 就算搖一次，之後冷卻 [cooldown]。
class ShakeDetector {
  final double threshold;
  final int hits;
  final Duration window;
  final Duration cooldown;

  final List<Duration> _peaks = [];
  Duration? _lastShake;

  ShakeDetector({
    this.threshold = 12,
    this.hits = 2,
    this.window = const Duration(seconds: 1),
    this.cooldown = const Duration(seconds: 2),
  });

  bool add({required double magnitude, required Duration at}) {
    if (_lastShake != null && at - _lastShake! < cooldown) return false;
    if (magnitude < threshold) return false;
    _peaks.add(at);
    _peaks.removeWhere((t) => at - t > window);
    if (_peaks.length >= hits) {
      _peaks.clear();
      _lastShake = at;
      return true;
    }
    return false;
  }
}
```

- [ ] **Step 4: Run**

Run: `flutter test test/widgets/tilt_math_test.dart test/services/shake_detector_test.dart`
Expected: 10 PASS

- [ ] **Step 5: Commit**

```bash
git add pubspec.yaml pubspec.lock lib/widgets/tilt_math.dart lib/services/shake_detector.dart test/widgets/tilt_math_test.dart test/services/shake_detector_test.dart
git commit -m "feat: tilt math, shake detector and sensors_plus"
```

---

### Task 12: TiltCard＋五行晶球＋組合卡

**Files:**
- Create: `lib/widgets/tilt_card.dart`、`lib/widgets/wuxing_orbs.dart`
- Modify: `lib/screens/combo/combo_screen.dart`（`_buildNameCard`）
- Test: `test/widgets/tilt_card_test.dart`、`test/widgets/wuxing_orbs_test.dart`、`test/screens/combo/combo_screen_test.dart`

- [ ] **Step 1: Write failing tests**

```dart
// test/widgets/tilt_card_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xuanli/widgets/tilt_card.dart';

void main() {
  Widget wrap(Widget c) => MaterialApp(home: Scaffold(body: Center(child: c)));

  Matrix4 transformOf(WidgetTester t) =>
      t.widget<Transform>(find.byKey(TiltCard.transformKey)).transform;

  testWidgets('初始冇傾斜', (tester) async {
    await tester.pumpWidget(wrap(const TiltCard(child: SizedBox(width: 200, height: 120))));
    expect(transformOf(tester).entry(0, 2), 0);
  });

  testWidgets('拖去右邊 → 繞 Y 轉；放手回正', (tester) async {
    await tester.pumpWidget(wrap(const TiltCard(child: SizedBox(width: 200, height: 120))));
    final center = tester.getCenter(find.byType(TiltCard));
    final g = await tester.startGesture(center);
    await g.moveTo(center + const Offset(90, 0));
    await tester.pump();
    expect(transformOf(tester).entry(0, 2), isNot(0));
    await g.up();
    await tester.pumpAndSettle();
    expect(transformOf(tester).entry(0, 2), closeTo(0, 1e-6));
  });

  testWidgets('child 照常顯示', (tester) async {
    await tester.pumpWidget(wrap(const TiltCard(child: Text('組合'))));
    expect(find.text('組合'), findsOneWidget);
  });
}
```

```dart
// test/widgets/wuxing_orbs_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xuanli/widgets/wuxing_orbs.dart';

void main() {
  testWidgets('五個晶球按木火土金水排，顯示百分比，大細跟比例', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(body: WuxingOrbs(wuxing: {'木': 40, '火': 10, '土': 20, '金': 10, '水': 20})),
    ));
    for (final e in ['木', '火', '土', '金', '水']) {
      expect(find.text(e), findsOneWidget);
    }
    expect(find.text('40%'), findsOneWidget);
    final wood = tester.getSize(find.byKey(const ValueKey('orb-木')));
    final fire = tester.getSize(find.byKey(const ValueKey('orb-火')));
    expect(wood.width, greaterThan(fire.width));
    expect(tester.getCenter(find.text('木')).dx, lessThan(tester.getCenter(find.text('水')).dx));
  });

  testWidgets('缺咗某行當 0%', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: Scaffold(body: WuxingOrbs(wuxing: {'木': 100}))));
    expect(find.text('0%'), findsNWidgets(4));
  });
}
```

`test/screens/combo/combo_screen_test.dart` 加（用該檔現有 `wrap`／`profile`）：

```dart
  testWidgets('組合名卡可傾斜，有五行晶球', (tester) async {
    await tester.pumpWidget(wrap(ComboDetailScreen(profile: profile)));
    expect(find.byType(TiltCard), findsOneWidget);
    expect(find.byType(WuxingOrbs), findsOneWidget);
  });
```
（imports：`package:xuanli/widgets/tilt_card.dart`、`package:xuanli/widgets/wuxing_orbs.dart`）

Run: `flutter test test/widgets/tilt_card_test.dart test/widgets/wuxing_orbs_test.dart test/screens/combo/`
Expected: FAIL

- [ ] **Step 2: Implement TiltCard**

```dart
// lib/widgets/tilt_card.dart
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:sensors_plus/sensors_plus.dart';

import '../theme/brand.dart';
import '../theme/motion.dart';
import 'tilt_math.dart';

/// 跟手指（或手機傾斜）微微轉動嘅卡，加一條會游走嘅全息反光。
/// 環境動畫關咗：唔聽感應器，但手指拖動仍然有效（使用者主動操作）。
class TiltCard extends StatefulWidget {
  static const transformKey = ValueKey('tilt-card-transform');

  final Widget child;
  final BorderRadius borderRadius;

  const TiltCard({super.key, required this.child, this.borderRadius = const BorderRadius.all(Radius.circular(24))});

  @override
  State<TiltCard> createState() => _TiltCardState();
}

class _TiltCardState extends State<TiltCard> with SingleTickerProviderStateMixin {
  Offset _target = Offset.zero;
  Offset _current = Offset.zero;
  bool _dragging = false;
  StreamSubscription<AccelerometerEvent>? _sub;
  late final AnimationController _settle =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 350))
        ..addListener(() => setState(() => _current = Offset.lerp(_current, _target, _settle.value)!));

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _sub?.cancel();
    _sub = null;
    if (Motion.sensors(context)) {
      try {
        _sub = accelerometerEventStream(samplingPeriod: SensorInterval.uiInterval).listen(
          (e) {
            if (_dragging) return;
            _target = gravityToNormalized(e.x, e.y);
            setState(() => _current = Offset.lerp(_current, _target, 0.15)!);
          },
          onError: (_) {},
          cancelOnError: true,
        );
      } catch (_) {
        // 冇感應器（模擬器／桌面）：靠拖動就得。
      }
    }
  }

  @override
  void dispose() {
    _sub?.cancel();
    _settle.dispose();
    super.dispose();
  }

  void _move(Offset local, Size size) {
    _dragging = true;
    setState(() => _current = _target = pointerToNormalized(local, size));
  }

  void _release() {
    _dragging = false;
    _target = Offset.zero;
    _settle.forward(from: 0);
  }

  @override
  Widget build(BuildContext context) {
    final a = tiltAngles(_current);
    return LayoutBuilder(
      builder: (context, constraints) => GestureDetector(
        onPanDown: (d) => _move(d.localPosition, context.size!),
        onPanUpdate: (d) => _move(d.localPosition, context.size!),
        onPanEnd: (_) => _release(),
        onPanCancel: _release,
        child: Transform(
          key: TiltCard.transformKey,
          alignment: Alignment.center,
          transform: Matrix4.identity()
            ..setEntry(3, 2, 0.0012)
            ..rotateX(a.rotateX)
            ..rotateY(a.rotateY),
          child: ClipRRect(
            borderRadius: widget.borderRadius,
            child: Stack(
              children: [
                widget.child,
                Positioned.fill(
                  child: IgnorePointer(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment(-1.6 + _current.dx, -1),
                          end: Alignment(1.6 + _current.dx, 1),
                          colors: [
                            Colors.transparent,
                            KairoPalette.goldBright.withValues(alpha: 0.16),
                            KairoPalette.jadeBright.withValues(alpha: 0.12),
                            const Color(0x1FE57A6F),
                            Colors.transparent,
                          ],
                          stops: const [0.35, 0.45, 0.5, 0.55, 0.65],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
```

（注意：`SensorInterval.uiInterval`／`accelerometerEventStream` 係 sensors_plus 4.0+ API；如 `flutter pub add` 裝到嘅版本 API 名唔同，跟 package README 改。）

- [ ] **Step 3: Implement WuxingOrbs**

```dart
// lib/widgets/wuxing_orbs.dart
import 'package:flutter/material.dart';

import '../theme/xuanli_theme.dart';

const _order = ['木', '火', '土', '金', '水'];
const _orbColors = {
  '木': [Color(0xFFE9FFE0), Color(0xFF6FBF5A), Color(0xFF1F4D1A)],
  '火': [Color(0xFFFFE2D6), Color(0xFFE5604F), Color(0xFF5C1A12)],
  '土': [Color(0xFFFFF6D8), Color(0xFFD1A650), Color(0xFF5A4314)],
  '金': [Color(0xFFFFFFFF), Color(0xFFC8CCD8), Color(0xFF4B5068)],
  '水': [Color(0xFFDFF3FF), Color(0xFF4F8FD6), Color(0xFF132C55)],
};

/// 五行晶球：球直徑 18–40 跟百分比（0–100）。
class WuxingOrbs extends StatelessWidget {
  final Map<String, int> wuxing;
  final Color labelColor;

  const WuxingOrbs({super.key, required this.wuxing, this.labelColor = const Color(0xFFE9DFC9)});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        for (final e in _order) _orb(e, wuxing[e] ?? 0),
      ],
    );
  }

  Widget _orb(String element, int pct) {
    final d = 18 + 22 * (pct.clamp(0, 100) / 100);
    final c = _orbColors[element]!;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          key: ValueKey('orb-$element'),
          width: d,
          height: d,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(center: const Alignment(-0.36, -0.44), colors: c, stops: const [0, 0.42, 1]),
            boxShadow: const [BoxShadow(color: Color(0x73000000), blurRadius: 14, offset: Offset(0, 8))],
          ),
        ),
        const SizedBox(height: 6),
        Text(element, style: TextStyle(fontFamily: XuanLiFonts.serif, fontWeight: FontWeight.w700, fontSize: 13, color: labelColor)),
        Text('$pct%', style: TextStyle(fontSize: 10.5, color: labelColor.withValues(alpha: 0.62))),
      ],
    );
  }
}
```

- [ ] **Step 4: 組合名卡包 TiltCard、加晶球**

`lib/screens/combo/combo_screen.dart` `_buildNameCard`：外層 `Container(...)` 包入 `TiltCard(child: ...)`；Container decoration 改成深藍漸變（兩個主題都一樣，似 preview 全息卡）：

```dart
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF25305C), Color(0xFF141A33), Color(0xFF0F1328)],
        ),
        borderRadius: BorderRadius.all(Radius.circular(24)),
      ),
```
卡內文字顏色：`combo.name` 嘅 `colors.ink` → `KairoPalette.paper`；`combo.description` 嘅 `colors.ink60` → `KairoPalette.paper.withValues(alpha: 0.65)`；MBTI chip 字 `colors.ink` → `KairoPalette.night`。喺 `combo.motto` Text 之後、description 之前加：

```dart
          const SizedBox(height: 18),
          WuxingOrbs(wuxing: profile.wuxing),
```
imports：`../../theme/brand.dart`、`../../widgets/tilt_card.dart`、`../../widgets/wuxing_orbs.dart`。

- [ ] **Step 5: Run**

Run: `flutter analyze && flutter test test/widgets/ test/screens/combo/`
Expected: PASS。如果 combo 頁原有 test 因卡入面可以拖而影響 scroll（`drag` 喺卡上面），將嗰個 test 嘅 drag 起點移去卡外。

- [ ] **Step 6: Commit**

```bash
git add lib/widgets/tilt_card.dart lib/widgets/wuxing_orbs.dart lib/screens/combo/combo_screen.dart test/widgets test/screens/combo
git commit -m "feat: holographic tilt combo card with wuxing orbs"
```

---

### Task 13: 立體籤筒、搖手機抽籤、翻卡揭曉

**Files:**
- Modify: `lib/widgets/stick_cylinder.dart`（重寫 painter）
- Create: `lib/widgets/flip_reveal.dart`
- Modify: `lib/screens/today/daily_stick_card.dart`
- Test: `test/widgets/flip_reveal_test.dart`、`test/widgets/stick_cylinder_test.dart`、`test/screens/today/daily_stick_card_test.dart`

- [ ] **Step 1: Write failing tests**

```dart
// test/widgets/flip_reveal_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xuanli/widgets/flip_reveal.dart';

void main() {
  Widget wrap(Widget c) => MaterialApp(home: Scaffold(body: Center(child: c)));

  testWidgets('開始顯示背面，翻完顯示正面', (tester) async {
    await tester.pumpWidget(wrap(const FlipReveal(back: Text('背'), front: Text('正'))));
    expect(find.text('背'), findsOneWidget);
    expect(find.text('正'), findsNothing);
    await tester.pumpAndSettle();
    expect(find.text('正'), findsOneWidget);
    expect(find.text('背'), findsNothing);
  });

  testWidgets('減少動態效果 → 即刻正面', (tester) async {
    await tester.pumpWidget(wrap(const MediaQuery(
      data: MediaQueryData(disableAnimations: true),
      child: FlipReveal(back: Text('背'), front: Text('正')),
    )));
    expect(find.text('正'), findsOneWidget);
  });
}
```

```dart
// test/widgets/stick_cylinder_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xuanli/widgets/stick_cylinder.dart';

void main() {
  testWidgets('任何 angle／pop 都 render 到，冇 exception', (tester) async {
    for (final pop in [0.0, 0.5, 1.0]) {
      await tester.pumpWidget(MaterialApp(home: Center(child: StickCylinder(angle: 0.2, pop: pop, spin: pop))));
      expect(tester.takeException(), isNull);
    }
    expect(find.bySemanticsLabel('籤筒'), findsOneWidget);
  });
}
```

`test/screens/today/daily_stick_card_test.dart` 加：

```dart
    testWidgets('搖完之後用 FlipReveal 翻出籤', (tester) async {
      await tester.pumpWidget(wrap(card()));
      await tester.tap(find.text('搖籤'));
      await tester.pump(const Duration(milliseconds: 1500));
      expect(find.byType(FlipReveal), findsOneWidget);
      await tester.pumpAndSettle();
    });
```
（放入 `group('DailyStickCard', …)` 入面；import `package:xuanli/widgets/flip_reveal.dart`）

Run: `flutter test test/widgets/flip_reveal_test.dart test/widgets/stick_cylinder_test.dart test/screens/today/daily_stick_card_test.dart`
Expected: FAIL

- [ ] **Step 2: FlipReveal**

```dart
// lib/widgets/flip_reveal.dart
import 'dart:math' as math;

import 'package:flutter/material.dart';

/// 一出現就由 [back] 3D 翻去 [front]（約 0.9 秒，帶少少回彈）。
class FlipReveal extends StatefulWidget {
  final Widget back;
  final Widget front;

  const FlipReveal({super.key, required this.back, required this.front});

  @override
  State<FlipReveal> createState() => _FlipRevealState();
}

class _FlipRevealState extends State<FlipReveal> with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 900));
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    if (MediaQuery.of(context).disableAnimations) {
      _c.value = 1;
    } else {
      _c.forward();
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (context, _) {
        final t = Curves.easeOutBack.transform(_c.value);
        final angle = (1 - t) * math.pi;
        final showFront = angle < math.pi / 2;
        return Transform(
          alignment: Alignment.center,
          transform: Matrix4.identity()
            ..setEntry(3, 2, 0.0015)
            ..rotateY(angle)
            ..scale(0.7 + 0.3 * _c.value),
          child: showFront
              ? widget.front
              : Transform(
                  alignment: Alignment.center,
                  transform: Matrix4.rotationY(math.pi),
                  child: widget.back,
                ),
        );
      },
    );
  }
}
```

- [ ] **Step 3: 立體籤筒**

`lib/widgets/stick_cylinder.dart`：`StickCylinder` 加欄位 `final double spin;`（0–1，筒身花紋水平移位，模擬轉動），constructor `this.spin = 0,`；painter 變 `_CylinderPainter(pop, spin)`，`shouldRepaint` 比較兩個值。`paint` 入面「筒身」嗰段（`canvas.drawRRect(body, Paint()..color = _tube);` 同下一個深色 drawRRect）換成圓柱光影：

```dart
    // 圓柱光影：左暗、中亮、右暗，做出立體感。
    canvas.drawRRect(
      body,
      Paint()
        ..shader = const LinearGradient(
          colors: [Color(0xFF6A1E1E), _tube, Color(0xFFD46060), _tube, Color(0xFF5E1A1A)],
          stops: [0, 0.3, 0.45, 0.65, 1],
        ).createShader(body.outerRect),
    );
    // 直條紋隨 spin 移動（似轉緊）。
    final stripe = Paint()..color = const Color(0x22000000);
    for (var k = 0; k < 6; k++) {
      final u = ((k / 6 + spin) % 1.0);
      final x = w * 0.18 + (w * 0.64) * (0.5 - 0.5 * math.cos(u * math.pi));
      canvas.drawLine(Offset(x, bodyTop + 6), Offset(x, h - 6), stripe..strokeWidth = 1.2);
    }
```
筒口橢圓改用徑向漸變（內黑外紅金邊）：

```dart
    final mouth = Rect.fromLTWH(w * 0.18, bodyTop - 6, w * 0.64, 12);
    canvas.drawOval(
      mouth,
      Paint()
        ..shader = const RadialGradient(colors: [Color(0xFF2B1010), _tubeDark, _gold], stops: [0.5, 0.85, 1])
            .createShader(mouth),
    );
```
底部加陰影：喺 `paint` 一開頭：

```dart
    canvas.drawOval(
      Rect.fromCenter(center: Offset(w / 2, h - 2), width: w * 0.9, height: 10),
      Paint()..color = const Color(0x66000000)..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
    );
```

- [ ] **Step 4: DailyStickCard：搖手機＋spin＋翻卡**

`lib/screens/today/daily_stick_card.dart`：

1. imports 加：`dart:async`、`package:sensors_plus/sensors_plus.dart`、`../../services/shake_detector.dart`、`../../theme/motion.dart`、`../../widgets/flip_reveal.dart`、`../../widgets/brand.dart`
2. State 加：

```dart
  StreamSubscription<UserAccelerometerEvent>? _shakeSub;
  final _shake = ShakeDetector();
  final _clock = Stopwatch()..start();

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _shakeSub?.cancel();
    _shakeSub = null;
    if (!_revealed && Motion.sensors(context)) {
      try {
        _shakeSub = userAccelerometerEventStream().listen(
          (e) {
            final m = math.sqrt(e.x * e.x + e.y * e.y + e.z * e.z);
            if (_shake.add(magnitude: m, at: _clock.elapsed)) _draw();
          },
          onError: (_) {},
          cancelOnError: true,
        );
      } catch (_) {}
    }
  }
```
`dispose` 加 `_shakeSub?.cancel();`；`_finish` 入面 `setState` 前加 `_shakeSub?.cancel();`。
3. `AnimatedBuilder` 入面 `StickCylinder(angle: angle, pop: pop)` → `StickCylinder(angle: angle, pop: pop, spin: t * 2)`。
4. idle 副題 Text 改成：
```dart
        Text(
          Motion.sensors(context) ? '靜心諗住一件事，搖一搖手機或者撳一下' : '靜心諗住一件事，撳一下搖籤',
          style: TextStyle(fontSize: 12, color: colors.ink60),
        ),
```
（測試入面 sensors 一定 false，所以現有 test 搵原句會繼續過。）
5. 加 `_flipResult` method：

```dart
  Widget _flipResult(XuanLiColors colors) {
    return FlipReveal(
      key: const ValueKey('result'),
      back: Container(
        height: 260,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: colors.gold, width: 1.5),
          gradient: const LinearGradient(colors: [Color(0xFF7A2222), Color(0xFF8F2B2B)]),
        ),
        child: const BrandSeal(size: 44),
      ),
      front: _result(colors),
    );
  }
```
`_result` 嘅 Column key `ValueKey('result')` 改 `ValueKey('result-front')`（避免同 FlipReveal 撞 key）。

重開 app（`alreadyDrawn` 為 true）唔使再翻卡：State 加 `bool _flipOnReveal = false;`，`_finish()` 入面 `setState(() => _revealed = true);` 改成 `setState(() { _revealed = true; _flipOnReveal = true; });`；AnimatedSwitcher 嘅 child 最終寫法：
```dart
        child: _revealed
            ? (_flipOnReveal ? _flipResult(colors) : _result(colors))
            : _idle(colors),
```

- [ ] **Step 5: Run**

Run: `flutter analyze && flutter test test/widgets/ test/screens/today/`
Expected: PASS。現有「搖完見籤詩」test 如因翻卡未完而搵唔到字，喺 `pump(1500ms)` 之後加 `await tester.pumpAndSettle();`。

- [ ] **Step 6: Commit**

```bash
git add lib/widgets/stick_cylinder.dart lib/widgets/flip_reveal.dart lib/screens/today/daily_stick_card.dart test/widgets test/screens/today
git commit -m "feat: 3D stick cylinder, shake-to-draw and flip reveal"
```

---

### Task 14: 頁面過場

**Files:**
- Create: `lib/theme/page_transitions.dart`
- Modify: `lib/theme/xuanli_theme.dart`（`_build` 加 `pageTransitionsTheme`）
- Test: `test/theme/page_transitions_test.dart`

- [ ] **Step 1: Write failing test**

```dart
// test/theme/page_transitions_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xuanli/theme/page_transitions.dart';
import 'package:xuanli/theme/xuanli_theme.dart';

void main() {
  test('light／dark 主題全平台用 KairoPageTransitionsBuilder', () {
    for (final theme in [XuanLiTheme.light(), XuanLiTheme.dark()]) {
      for (final p in [TargetPlatform.android, TargetPlatform.iOS]) {
        expect(theme.pageTransitionsTheme.builders[p], isA<KairoPageTransitionsBuilder>());
      }
    }
  });

  testWidgets('push 新頁：過場中途係淡入，完咗完全顯示', (tester) async {
    await tester.pumpWidget(MaterialApp(
      theme: XuanLiTheme.dark(),
      home: Builder(builder: (c) => TextButton(
        onPressed: () => Navigator.of(c).push(MaterialPageRoute(builder: (_) => const Text('新頁'))),
        child: const Text('去'),
      )),
    ));
    await tester.tap(find.text('去'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    final fade = tester.widget<FadeTransition>(find.ancestor(of: find.text('新頁'), matching: find.byType(FadeTransition)).first);
    expect(fade.opacity.value, lessThan(1));
    await tester.pumpAndSettle();
    expect(find.text('新頁'), findsOneWidget);
  });
}
```

Run: `flutter test test/theme/page_transitions_test.dart`
Expected: FAIL

- [ ] **Step 2: Implement**

```dart
// lib/theme/page_transitions.dart
import 'package:flutter/material.dart';

/// Kairo 過場：新頁淡入＋由 96% 放大到 100%，舊頁輕微淡出。
class KairoPageTransitionsBuilder extends PageTransitionsBuilder {
  const KairoPageTransitionsBuilder();

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    final inCurve = CurvedAnimation(parent: animation, curve: Curves.easeOutCubic);
    final outCurve = CurvedAnimation(parent: secondaryAnimation, curve: Curves.easeIn);
    return FadeTransition(
      opacity: inCurve,
      child: ScaleTransition(
        scale: Tween(begin: 0.96, end: 1.0).animate(inCurve),
        child: FadeTransition(
          opacity: Tween(begin: 1.0, end: 0.6).animate(outCurve),
          child: child,
        ),
      ),
    );
  }
}

const kairoPageTransitions = PageTransitionsTheme(builders: {
  TargetPlatform.android: KairoPageTransitionsBuilder(),
  TargetPlatform.iOS: KairoPageTransitionsBuilder(),
  TargetPlatform.macOS: KairoPageTransitionsBuilder(),
  TargetPlatform.linux: KairoPageTransitionsBuilder(),
  TargetPlatform.windows: KairoPageTransitionsBuilder(),
  TargetPlatform.fuchsia: KairoPageTransitionsBuilder(),
});
```

`lib/theme/xuanli_theme.dart` `_build` 嘅 `return ThemeData(` 入面加 `pageTransitionsTheme: kairoPageTransitions,`，頂部加 `import 'page_transitions.dart';`。

（iOS 原生 swipe-back 手勢會冇咗——呢個係取捨；如 Stephanie 介意，iOS 改返 `CupertinoPageTransitionsBuilder()`。喺完成報告講明。）

- [ ] **Step 3: Run**

Run: `flutter test test/theme/ && flutter test`
Expected: 全 PASS

- [ ] **Step 4: Commit**

```bash
git add lib/theme/page_transitions.dart lib/theme/xuanli_theme.dart test/theme/page_transitions_test.dart
git commit -m "feat: Kairo fade-scale page transitions"
```

---

### Task 15: App icon A＋原生 widget 配色

**Files:**
- Create: `tool/render_icon_test.dart`（放 `tool/` 唔放 `test/`：平時 `flutter test` 唔會跑）
- Modify: `assets/icon/icon.png`、`icon_foreground.png`、`icon_mono.png`（生成）、`pubspec.yaml`（`flutter_launcher_icons` 底色）
- Modify: `android/app/src/main/res/values-night/colors.xml`、`ios/XuanLiWidget/XuanLiWidget.swift`（深色背景色）

- [ ] **Step 1: Icon 渲染 test**

```dart
// tool/render_icon_test.dart
// 生成 app icon：flutter test --update-goldens tool/render_icon_test.dart
// 唔喺 test/ 入面，所以 `flutter test` 全套唔會跑佢。

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xuanli/theme/brand.dart';
import 'package:xuanli/theme/motion.dart';
import 'package:xuanli/theme/xuanli_theme.dart';
import 'package:xuanli/widgets/orrery.dart';

Widget _k(Color color) => Text('K',
    style: TextStyle(fontFamily: XuanLiFonts.wordmark, fontWeight: FontWeight.w600, fontSize: 470, height: 1, color: color));

Widget _canvas({required bool background, required Widget child}) => MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Center(
        child: RepaintBoundary(
          key: const ValueKey('icon'),
          child: Container(
            width: 1024,
            height: 1024,
            decoration: background
                ? const BoxDecoration(
                    gradient: RadialGradient(center: Alignment(0, -0.4), colors: [Color(0xFF2B376A), KairoPalette.night], stops: [0, 0.75]))
                : null,
            alignment: Alignment.center,
            child: child,
          ),
        ),
      ),
    );

void main() {
  setUpAll(() async {
    Motion.ambientEnabled = false;
    final loader = FontLoader(XuanLiFonts.wordmark)
      ..addFont(rootBundle.load('assets/fonts/CormorantGaramond-SemiBold.ttf'));
    await loader.load();
  });

  Future<void> render(WidgetTester tester, Widget w, String file) async {
    tester.view.physicalSize = const Size(1024, 1024);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(w);
    await expectLater(find.byKey(const ValueKey('icon')), matchesGoldenFile('../assets/icon/$file'));
  }

  testWidgets('icon.png（完整）', (tester) async {
    await render(tester, _canvas(background: true, child: Stack(alignment: Alignment.center, children: [
      const Orrery(size: 760, coreFraction: 0.001),
      _k(KairoPalette.goldBright),
    ])), 'icon.png');
  });

  testWidgets('icon_foreground.png（Android adaptive 前景，透明底，留安全區）', (tester) async {
    await render(tester, _canvas(background: false, child: Stack(alignment: Alignment.center, children: [
      const Orrery(size: 600, coreFraction: 0.001),
      Transform.scale(scale: 0.78, child: _k(KairoPalette.goldBright)),
    ])), 'icon_foreground.png');
  });

  testWidgets('icon_mono.png（單色）', (tester) async {
    await render(tester, _canvas(background: false, child: Transform.scale(scale: 0.78, child: _k(Colors.white))), 'icon_mono.png');
  });
}
```

- [ ] **Step 2: 生成**

Run: `flutter test --update-goldens tool/render_icon_test.dart`
Expected: 3 PASS，`assets/icon/` 三個 PNG 更新。用 Read 睇 `assets/icon/icon.png` 肉眼確認：深藍底、金色傾斜環、置中金色 K。唔靚就調 `size`／`scale` 再生成。

（`coreFraction: 0.001` 令核心球幾乎唔見，等 K 唔被遮。）

- [ ] **Step 3: launcher icons 底色＋生成**

`pubspec.yaml` `flutter_launcher_icons:` 段：`adaptive_icon_background: "#B23A3A"` → `"#0D1120"`；web `background_color`／`theme_color` → `"#0D1120"`。

Run: `dart run flutter_launcher_icons`（如果報未裝：`flutter pub add --dev flutter_launcher_icons` 再跑）
Expected: Android mipmap、iOS AppIcon、web icons 全部重生成，冇 error。

- [ ] **Step 4: 原生 widget 深色配色**

`android/app/src/main/res/values-night/colors.xml`：背景色值改 `#0D1120`，卡色 `#141A2E`（保留現有 color name，只改值；`cat` 睇清楚邊個 name 係背景）。
`ios/XuanLiWidget/XuanLiWidget.swift`：`grep -n "0x13\|0.07\|131829\|Color(" ios/XuanLiWidget/XuanLiWidget.swift` 搵深色背景，`#131829` 對應值改成 `#0D1120`（RGB 13/17/32）。

Run: `xmllint --noout android/app/src/main/res/values-night/colors.xml && xcrun swiftc -typecheck -target arm64-apple-macos14 ios/XuanLiWidget/XuanLiWidgetLogic.swift`（如果之前 CHANGELOG 嘅 typecheck 指令唔同，用返嗰個）
Expected: 冇 error

- [ ] **Step 5: Commit**

```bash
git add tool/render_icon_test.dart assets/icon pubspec.yaml pubspec.lock android/app/src/main/res ios/Runner/Assets.xcassets ios/XuanLiWidget web/icons web/favicon.png
git commit -m "feat: Kairo orrery app icon and night widget colors"
```

---

### Task 16: 文件更新＋全面驗證

**Files:**
- Modify: `XUANLI_SPEC.md`（標題、§12）、`CLAUDE.md`（標題、必讀文件 2、Progress）、`CHANGELOG.md`（頂部）

- [ ] **Step 1: Spec §12**

`XUANLI_SPEC.md`：第一行標題 `# 玄曆 XuanLi — 實施規格書…` → `# Kairo（吉時，原名玄曆 XuanLi）— 實施規格書…`；§12 code block 改成：

```
Kairo（2026-10-13 改版，視覺語言見 design/kairo-preview.html）
light: paper #f6efe2 / paper2 #efe5d0 / ink #1c2440 / red #b23a3a / gold #c9a24b / jade #3f7d6e
dark（預設）: bg #0d1120 / bg2 #141a2e / card #1c2440 / text #e9dfc9 / gold #c9a24b / goldBright #f0d78c / jade #6fc3ad / 忌 #e57a6f
字體：Noto Serif TC（標題/數字/干支）+ Noto Sans TC（正文）+ Cormorant Garamond SemiBold（Kairo 字）
圓角：卡 16 / 格 9 / widget 28 / 全息卡 24；印章：朱紅底米黃「吉」或直排「吉時」
3D：天體儀、立體籤筒、傾斜全息卡、星空；環境動畫尊重「減少動態效果」
```

- [ ] **Step 2: CLAUDE.md（保持 ≤100 行／6KB）**

- 標題 `# 玄曆 XuanLi — CLAUDE.md` → `# Kairo（原名玄曆 XuanLi）— CLAUDE.md`
- 必讀文件 2 改：`` `design/kairo-preview.html` — 視覺語言權威（配色／品牌／3D／動態）；`design/design-preview.html` — 版面同文案語氣參考（未涵蓋嘅畫面照佢） ``
- 鐵律加第 8 條：`8. **內部識別唔改名**：package／bundle ID／App Group／`xuanli://`／prefs key／備份格式／「玄曆識別碼」保留，見 docs/superpowers/specs/2026-10-13-kairo-rebrand-design.md D1`
- Progress 加：`- [x] Kairo 改名＋3D／動態（2026-10-13，feat/kairo-rebrand）——**真機未驗**：陀螺儀傾斜手感、搖手機抽籤、震動、APK 大小`

Run: `wc -l -c CLAUDE.md`
Expected: ≤ 100 行、≤ 6144 bytes（超咗就將細節搬去 CHANGELOG）

- [ ] **Step 3: CHANGELOG 頂部**

喺 `# CHANGELOG` 標題同說明之後、第一條之前加一條（照實寫完成咗咩、驗證咗咩、未驗證咩、限制），格式跟現有條目：`- 2026-10-13：**Kairo 改名＋3D／動態** — …`

- [ ] **Step 4: 全面驗證（真跑，output 貼入完成報告）**

```bash
dart test test/engine/
flutter analyze
flutter test
flutter build web --release
du -sh assets/fonts/CormorantGaramond-SemiBold.ttf assets/icon
grep -rn "玄曆" lib | grep -v "//" | grep -v "玄曆識別碼"
```
Expected：engine 全綠；analyze `No issues found!`；test 全綠；web build 成功；新增 asset 合計 < 1MB；最後一行 grep 冇輸出。

- [ ] **Step 5: 用家身份 run 一次（web）**

用 `preview_start` 開 `build/web`（要寫 `.claude/launch.json`：`python3 -m http.server 8080 --directory build/web`），然後喺 browser 行一次：封面（天體儀、Kairo、吉時）→ onboarding 填資料 → 今日頁（天體儀中心分數、細環、7 日條、星空）→ 搖籤（翻卡）→ 組合頁（拖動卡傾斜、五行晶球）→ 設定（字串係 Kairo）→ 切淺色模式睇一次。逐頁截圖肉眼查：冇簡體字、冇方格字、冇 overflow 黃黑條。

- [ ] **Step 6: Commit**

```bash
git add XUANLI_SPEC.md CLAUDE.md CHANGELOG.md
git commit -m "docs: record Kairo rebrand in spec, CLAUDE.md and changelog"
```

- [ ] **Step 7: 收尾**

用 superpowers:finishing-a-development-branch 決定 merge／PR。**唔好**自己 `vercel deploy`——web 部署要先問 Stephanie。
