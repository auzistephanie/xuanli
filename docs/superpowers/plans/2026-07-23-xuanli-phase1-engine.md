# 玄曆 XuanLi — Phase 1 引擎 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 建好 `lib/engine/` 純 Dart 引擎（八字/五行/喜用神、通勝繁體化、命理分、契合度、反向擇日、文案模板），全部由 `test/engine/` 嘅 golden fixtures（XUANLI_SPEC.md §11）驅動、TDD 寫，`dart test test/engine/` 全綠 + `tool/demo.dart` 可行。

**Architecture:** `lib/engine/` 全部純函數、零 Flutter import、零 Random/DateTime.now()。傳統層靠 pub.dev `lunar`（6tail）包裝出繁體化嘅 `AlmanacDay`；個人化層（八字/五行/喜用神）自寫喺 `bazi.dart`；`scoring.dart` 消費呢兩層產出命理分＋契合度；`activity.dart`／`copywriter.dart` 喺呢啲之上做反向擇日同文案。`models/` 淨係數據類，`data/*.json` 淨係內容。

**Tech Stack:** Flutter 3.44（stable，已用 `brew install --cask flutter` 裝好，`dart` 3.12.2 / `flutter` 都喺 PATH）；`lunar` ^1.x（6tail，離線農曆/八字/建除/神煞/宜忌引擎）。

**已鎖定嘅範圍決定（呢份 plan 執行前已同 Stephanie 傾掂）：**
- ziwei.dart 全模式（有時辰）同降級模式（冇時辰）**用同一個簡化對照表**（keyed by 日支），唔做真正紫微斗數排盤（五虎遁月／定命宮／安十四主星訣全部**唔做**，留返 v2 深度文案，見 spec §2 決定 11）。
- MBTI 語氣庫（spec §8.3 要求 16 型 × ≥6 句）**內容本身唔喺呢份 engineering plan 範圍內**——spec 冇提供任何一句實際文案，淨係規則（I 講獨處、E 講社交、F 講感受、T 講策略）。Task 16 會起好 loader + rotation 邏輯 + 2 個型嘅真實例句（用嚟過 determinism test），其餘 14 型嘅內容係文案工作，執行到 Task 16 見到再問 Stephanie 想自己填定叫另一個 session 用 humanizer-zh 幫手起稿。

---

## Task 0: Flutter 專案骨架

**Files:**
- Create（`flutter create` 產生）: `pubspec.yaml`, `lib/main.dart`, `test/widget_test.dart`, `analysis_options.yaml`, `android/`, `ios/`, `.gitignore`
- Modify: `pubspec.yaml`（加依賴）

- [ ] **Step 1: 用 flutter create 喺現有 repo 度起 app**

呢個目錄已經有 `CLAUDE.md`、`XUANLI_SPEC.md`、`design/`、`lib/data/combos.json`、`scripts/`、`.env`、`CHANGELOG.md`——`flutter create` 對現有目錄安全（唔會覆蓋呢啲檔案，只加返 Flutter 標準骨架）。

Run:
```bash
cd "/Users/stephanieau/Desktop/Stephanie-Google Drive/dev/xuanli"
flutter create --org com.xuanli --project-name xuanli --platforms=ios,android .
```
Expected: 產生 `pubspec.yaml`、`lib/main.dart`（default counter demo）、`android/`、`ios/`、`test/widget_test.dart`。`lib/data/combos.json` 同其他既有檔案原封不動。

- [ ] **Step 2: 刪除 default counter demo test（Phase 2 先起真正 UI）**

```bash
rm -f "/Users/stephanieau/Desktop/Stephanie-Google Drive/dev/xuanli/test/widget_test.dart"
```

- [ ] **Step 3: 加依賴落 pubspec.yaml**

Modify `pubspec.yaml`，喺 `dependencies:` 底下（保留 flutter create 產生嘅 `flutter: sdk: flutter` 行）加：

```yaml
dependencies:
  flutter:
    sdk: flutter
  lunar: ^1.7.0
  home_widget: ^0.7.0
  flutter_local_notifications: ^17.2.0
  device_calendar: ^4.3.0
  shared_preferences: ^2.3.0
  google_fonts: ^6.2.0
  intl: ^0.19.0
  cupertino_icons: ^1.0.8
```

- [ ] **Step 4: 裝依賴**

```bash
cd "/Users/stephanieau/Desktop/Stephanie-Google Drive/dev/xuanli" && flutter pub get
```
Expected: `Got dependencies!`，`pubspec.lock` 產生。如果某個版本 resolve 唔到，用 `flutter pub get` 報嘅建議版本號調整（唔准降級用 `Random`／過時 API 嘅版本）。

- [ ] **Step 5: 建 engine/models/data/test 資料夾骨架**

```bash
cd "/Users/stephanieau/Desktop/Stephanie-Google Drive/dev/xuanli"
mkdir -p lib/engine lib/models lib/services lib/screens lib/widgets test/engine tool
```

- [ ] **Step 6: 驗證骨架可以行 test（空 test 都得）**

```bash
cd "/Users/stephanieau/Desktop/Stephanie-Google Drive/dev/xuanli" && dart test test/engine/ 2>&1 || echo "no tests yet - expected"
```
Expected: "No tests were found" 或類似（`test/engine/` 仲係空）——呢步淨係確認 `dart test` 指令喺呢個 repo 行得通。

- [ ] **Step 7: Commit**

```bash
cd "/Users/stephanieau/Desktop/Stephanie-Google Drive/dev/xuanli"
git add pubspec.yaml pubspec.lock lib/main.dart android ios .gitignore analysis_options.yaml
git commit -m "chore: scaffold flutter project, add engine dependencies"
```

---

## Task 1: 共用五行/干支對照表（`wuxing_tables.dart`）

**Files:**
- Create: `lib/engine/wuxing_tables.dart`
- Test: `test/engine/wuxing_tables_test.dart`

呢個 task 冧起成個引擎用嘅底層常數表：天干/地支五行、地支六沖、簡繁對照。**全部靠 spec §6.1/§11 fixtures 反推驗證過**，唔係亂估。

- [ ] **Step 1: 寫 failing test**

`test/engine/wuxing_tables_test.dart`:
```dart
import 'package:test/test.dart';
import 'package:xuanli/engine/wuxing_tables.dart';

void main() {
  group('WuxingTables', () {
    test('天干五行', () {
      expect(ganWuxing['甲'], '木');
      expect(ganWuxing['乙'], '木');
      expect(ganWuxing['丙'], '火');
      expect(ganWuxing['丁'], '火');
      expect(ganWuxing['戊'], '土');
      expect(ganWuxing['己'], '土');
      expect(ganWuxing['庚'], '金');
      expect(ganWuxing['辛'], '金');
      expect(ganWuxing['壬'], '水');
      expect(ganWuxing['癸'], '水');
    });

    test('地支本氣五行', () {
      expect(zhiWuxing['子'], '水');
      expect(zhiWuxing['丑'], '土');
      expect(zhiWuxing['寅'], '木');
      expect(zhiWuxing['卯'], '木');
      expect(zhiWuxing['辰'], '土');
      expect(zhiWuxing['巳'], '火');
      expect(zhiWuxing['午'], '火');
      expect(zhiWuxing['未'], '土');
      expect(zhiWuxing['申'], '金');
      expect(zhiWuxing['酉'], '金');
      expect(zhiWuxing['戌'], '土');
      expect(zhiWuxing['亥'], '水');
    });

    test('地支六沖', () {
      expect(zhiClash['子'], '午');
      expect(zhiClash['午'], '子');
      expect(zhiClash['丑'], '未');
      expect(zhiClash['未'], '丑');
      expect(zhiClash['寅'], '申');
      expect(zhiClash['申'], '寅');
      expect(zhiClash['卯'], '酉');
      expect(zhiClash['酉'], '卯');
      expect(zhiClash['辰'], '戌');
      expect(zhiClash['戌'], '辰');
      expect(zhiClash['巳'], '亥');
      expect(zhiClash['亥'], '巳');
    });

    test('相生：邊行生日主', () {
      expect(elementThatGenerates('木'), '水'); // 水生木
      expect(elementThatGenerates('火'), '木'); // 木生火
      expect(elementThatGenerates('土'), '火'); // 火生土
      expect(elementThatGenerates('金'), '土'); // 土生金
      expect(elementThatGenerates('水'), '金'); // 金生水
    });

    test('相剋：邊行剋日主', () {
      expect(elementThatControls('木'), '金'); // 金剋木
      expect(elementThatControls('火'), '水'); // 水剋火
      expect(elementThatControls('土'), '木'); // 木剋土
      expect(elementThatControls('金'), '火'); // 火剋金
      expect(elementThatControls('水'), '土'); // 土剋水
    });

    test('日主生邊行（食傷）', () {
      expect(elementGeneratedBy('木'), '火'); // 木生火
      expect(elementGeneratedBy('水'), '木'); // 水生木
    });

    test('日主剋邊行（財）', () {
      expect(elementControlledBy('木'), '土'); // 木剋土
      expect(elementControlledBy('水'), '火'); // 水剋火
    });

    test('簡繁對照表覆蓋 spec §7/§11 出現嘅字', () {
      expect(traditionalize('理发'), '理髮');
      expect(traditionalize('马'), '馬');
      expect(traditionalize('龙'), '龍');
      expect(traditionalize('开'), '開');
      expect(traditionalize('闭'), '閉');
      expect(traditionalize('满'), '滿');
      expect(traditionalize('执'), '執');
      expect(traditionalize('馀事勿取'), '餘事勿取');
      expect(traditionalize('诸事不宜'), '諸事不宜');
      expect(traditionalize('纳财'), '納財');
      expect(traditionalize('动土'), '動土');
      expect(traditionalize('纳采'), '納采');
      expect(traditionalize('订盟'), '訂盟');
      expect(traditionalize('开市'), '開市');
      expect(traditionalize('开渠'), '開渠');
      expect(traditionalize('坏垣'), '壞垣');
      expect(traditionalize('纳畜'), '納畜');
      expect(traditionalize('求医', ), '求醫');
      expect(traditionalize('栽种'), '栽種');
      // 已經係繁體嘅字要原樣返回（唔喺對照表出現）
      expect(traditionalize('祭祀'), '祭祀');
    });
  });
}
```

- [ ] **Step 2: Run test 確認 fail**

```bash
cd "/Users/stephanieau/Desktop/Stephanie-Google Drive/dev/xuanli" && dart test test/engine/wuxing_tables_test.dart
```
Expected: FAIL（`package:xuanli/engine/wuxing_tables.dart` 唔存在）。

- [ ] **Step 3: 寫實作**

`lib/engine/wuxing_tables.dart`:
```dart
/// 天干 → 五行
const Map<String, String> ganWuxing = {
  '甲': '木', '乙': '木',
  '丙': '火', '丁': '火',
  '戊': '土', '己': '土',
  '庚': '金', '辛': '金',
  '壬': '水', '癸': '水',
};

/// 地支 → 本氣五行
const Map<String, String> zhiWuxing = {
  '子': '水', '丑': '土', '寅': '木', '卯': '木',
  '辰': '土', '巳': '火', '午': '火', '未': '土',
  '申': '金', '酉': '金', '戌': '土', '亥': '水',
};

/// 地支六沖（子午/丑未/寅申/卯酉/辰戌/巳亥）
const Map<String, String> zhiClash = {
  '子': '午', '午': '子',
  '丑': '未', '未': '丑',
  '寅': '申', '申': '寅',
  '卯': '酉', '酉': '卯',
  '辰': '戌', '戌': '辰',
  '巳': '亥', '亥': '巳',
};

const List<String> _wuxingOrder = ['木', '火', '土', '金', '水'];

const Map<String, String> _generates = {
  '木': '火', '火': '土', '土': '金', '金': '水', '水': '木',
};
const Map<String, String> _controls = {
  '木': '土', '土': '水', '水': '火', '火': '金', '金': '木',
};

/// 邊行生咗 [element]（印星）
String elementThatGenerates(String element) {
  return _generates.entries.firstWhere((e) => e.value == element).key;
}

/// 邊行剋咗 [element]（官殺）
String elementThatControls(String element) {
  return _controls.entries.firstWhere((e) => e.value == element).key;
}

/// [element] 生邊行（食傷）
String elementGeneratedBy(String element) => _generates[element]!;

/// [element] 剋邊行（財）
String elementControlledBy(String element) => _controls[element]!;

/// 簡體 → 繁體對照表（`lunar` package 回傳簡體，UI 一律要繁體）。
/// **規則**：淨係列出「簡體同繁體字形唔同」嘅字／詞；已經同繁體一樣嘅字唔使入表，
/// [traditionalize] 對表入面搵唔到嘅原樣返回。跟住 Phase 2 對住 design-preview.html
/// 肉眼查 UI 若發現漏字，喺呢個表加多條 entry 就得。
const Map<String, String> _simplifiedToTraditional = {
  '理发': '理髮', '发': '髮',
  '马': '馬', '龙': '龍', '风': '風',
  '开': '開', '闭': '閉', '满': '滿', '执': '執',
  '马会': '馬會',
  '馀事勿取': '餘事勿取', '余事勿取': '餘事勿取',
  '诸事不宜': '諸事不宜',
  '纳财': '納財', '纳采': '納采', '纳畜': '納畜',
  '动土': '動土', '订盟': '訂盟',
  '开市': '開市', '开渠': '開渠', '开光': '開光',
  '坏垣': '壞垣', '栽种': '栽種',
  '求医': '求醫', '造船': '造船',
  '会亲友': '會親友', '嫁娶': '嫁娶',
};

/// 將 [lunar] package 回傳嘅簡體詞轉繁體。搵唔到就原樣返回
/// （表示個詞本身簡繁同形，例如「祭祀」「祈福」）。
String traditionalize(String simplified) {
  if (_simplifiedToTraditional.containsKey(simplified)) {
    return _simplifiedToTraditional[simplified]!;
  }
  // 逐字替換（處理啲有簡體單字夾喺繁體詞入面嘅情況，例如「理发」入面嘅「发」）
  final buffer = StringBuffer();
  for (final ch in simplified.split('')) {
    buffer.write(_simplifiedToTraditional[ch] ?? ch);
  }
  return buffer.toString();
}
```

- [ ] **Step 4: Run test 確認 pass**

```bash
cd "/Users/stephanieau/Desktop/Stephanie-Google Drive/dev/xuanli" && dart test test/engine/wuxing_tables_test.dart
```
Expected: 全部 PASS。

- [ ] **Step 5: Commit**

```bash
cd "/Users/stephanieau/Desktop/Stephanie-Google Drive/dev/xuanli"
git add lib/engine/wuxing_tables.dart test/engine/wuxing_tables_test.dart
git commit -m "feat(engine): add wuxing/ganzhi lookup tables"
```

---

## Task 2: `almanac.dart` — 通勝日期基本欄位（zhi_xing/沖煞/農曆label）

**Files:**
- Create: `lib/engine/almanac.dart`
- Test: `test/engine/almanac_test.dart`

**依賴**：`lunar` package 嘅 `Solar`／`Lunar` class。呢個 task 用 spec §11 嘅 7 個 golden fixture（2026-07-11 至 2026-07-17）鎖住輸出。

- [ ] **Step 1: 寫 failing test（golden fixtures）**

`test/engine/almanac_test.dart`:
```dart
import 'package:test/test.dart';
import 'package:xuanli/engine/almanac.dart';

void main() {
  group('AlmanacDay golden fixtures (2026-07)', () {
    final fixtures = [
      _Fixture(2026, 7, 11, lunarLabel: '五月廿七', ganzhiDay: '丙戌', zhiXing: '平', chong: '沖龍煞北'),
      _Fixture(2026, 7, 12, lunarLabel: '五月廿八', ganzhiDay: '丁亥', zhiXing: '定', chong: '沖蛇煞西'),
      _Fixture(2026, 7, 13, lunarLabel: '五月廿九', ganzhiDay: '戊子', zhiXing: '執', chong: '沖馬煞南'),
      _Fixture(2026, 7, 14, lunarLabel: '六月初一', ganzhiDay: '己丑', zhiXing: '破', chong: '沖羊煞東'),
      _Fixture(2026, 7, 15, lunarLabel: '六月初二', ganzhiDay: '庚寅', zhiXing: '危', chong: '沖猴煞北'),
      _Fixture(2026, 7, 16, lunarLabel: '六月初三', ganzhiDay: '辛卯', zhiXing: '成', chong: '沖雞煞西'),
      _Fixture(2026, 7, 17, lunarLabel: '六月初四', ganzhiDay: '壬辰', zhiXing: '收', chong: '沖狗煞南'),
    ];

    for (final f in fixtures) {
      test('${f.year}-${f.month}-${f.day}', () {
        final day = AlmanacDay.forDate(DateTime(f.year, f.month, f.day));
        expect(day.lunarLabel, f.lunarLabel, reason: 'lunarLabel');
        expect(day.ganzhiDay, f.ganzhiDay, reason: 'ganzhiDay');
        expect(day.zhiXing, f.zhiXing, reason: 'zhiXing');
        expect(day.chong, f.chong, reason: 'chong');
      });
    }

    test('月界：2026-07-14 係六月初一', () {
      final day = AlmanacDay.forDate(DateTime(2026, 7, 14));
      expect(day.lunarLabel, '六月初一');
    });
  });

  group('宜/忌繁體化', () {
    test('2026-07-11 宜含「祭祀」「餘事勿取」，忌「諸事不宜」', () {
      final day = AlmanacDay.forDate(DateTime(2026, 7, 11));
      expect(day.yi, contains('祭祀'));
      expect(day.yi, contains('餘事勿取'));
      expect(day.ji, contains('諸事不宜'));
      // 冇簡體字漏網
      for (final item in [...day.yi, ...day.ji]) {
        expect(item.contains('诸'), isFalse, reason: '$item 唔應該有簡體字');
        expect(item.contains('余'), isFalse, reason: '$item 唔應該有簡體字');
      }
    });

    test('2026-07-12 宜含「入宅」，忌含「理髮」（唔係簡體「理发」）', () {
      final day = AlmanacDay.forDate(DateTime(2026, 7, 12));
      expect(day.yi, contains('入宅'));
      expect(day.ji, contains('理髮'));
    });
  });

  group('isJiSevere / isYiVague', () {
    test('2026-07-11（忌：諸事不宜）isJiSevere = true', () {
      final day = AlmanacDay.forDate(DateTime(2026, 7, 11));
      expect(day.isJiSevere, isTrue);
    });
    test('2026-07-12（忌唔係諸事不宜）isJiSevere = false', () {
      final day = AlmanacDay.forDate(DateTime(2026, 7, 12));
      expect(day.isJiSevere, isFalse);
    });
    test('2026-07-14（宜：餘事勿取）isYiVague = true', () {
      final day = AlmanacDay.forDate(DateTime(2026, 7, 14));
      expect(day.isYiVague, isTrue);
    });
    test('2026-07-12（宜有具體項目）isYiVague = false', () {
      final day = AlmanacDay.forDate(DateTime(2026, 7, 12));
      expect(day.isYiVague, isFalse);
    });
  });
}

class _Fixture {
  final int year, month, day;
  final String lunarLabel, ganzhiDay, zhiXing, chong;
  _Fixture(this.year, this.month, this.day,
      {required this.lunarLabel, required this.ganzhiDay, required this.zhiXing, required this.chong});
}
```

- [ ] **Step 2: Run test 確認 fail**

```bash
cd "/Users/stephanieau/Desktop/Stephanie-Google Drive/dev/xuanli" && dart test test/engine/almanac_test.dart
```
Expected: FAIL（`almanac.dart` 唔存在）。

- [ ] **Step 3: 寫實作**

`lib/engine/almanac.dart`:
```dart
import 'package:lunar/lunar.dart';
import 'wuxing_tables.dart';

/// 一日嘅通勝資料，全部已經繁體化、deterministic（純 [date] 做 input）。
class AlmanacDay {
  final DateTime date;
  final String lunarLabel; // "五月廿七"
  final String ganzhiDay; // "丙戌"
  final String zhiXing; // 建除："平"
  final String chong; // "沖龍煞北"
  final List<String> yi;
  final List<String> ji;
  final int jiShenCount;
  final int xiongShaCount;
  final bool isJiSevere; // 忌：諸事不宜
  final bool isYiVague; // 宜：諸事不宜／餘事勿取（冇具體項目）

  AlmanacDay._({
    required this.date,
    required this.lunarLabel,
    required this.ganzhiDay,
    required this.zhiXing,
    required this.chong,
    required this.yi,
    required this.ji,
    required this.jiShenCount,
    required this.xiongShaCount,
    required this.isJiSevere,
    required this.isYiVague,
  });

  factory AlmanacDay.forDate(DateTime date) {
    final lunar = Solar.fromYmd(date.year, date.month, date.day).getLunar();

    final lunarLabel = '${lunar.getMonthInChinese()}月${lunar.getDayInChinese()}';
    final ganzhiDay = lunar.getDayInGanZhi();
    final zhiXing = traditionalize(lunar.getZhiXing());
    final chongAnimal = traditionalize(lunar.getDayChongShengXiao());
    final sha = lunar.getDaySha();
    final chong = '沖$chongAnimal煞$sha';

    final yi = lunar.getDayYi().map(traditionalize).toList();
    final ji = lunar.getDayJi().map(traditionalize).toList();

    final isJiSevere = ji.length == 1 && ji.first == '諸事不宜';
    final isYiVague = yi.isEmpty ||
        (yi.length == 1 && (yi.first == '諸事不宜' || yi.first == '餘事勿取'));

    return AlmanacDay._(
      date: date,
      lunarLabel: lunarLabel,
      ganzhiDay: ganzhiDay,
      zhiXing: zhiXing,
      chong: chong,
      yi: yi,
      ji: ji,
      jiShenCount: lunar.getDayJiShen().length,
      xiongShaCount: lunar.getDayXiongSha().length,
      isJiSevere: isJiSevere,
      isYiVague: isYiVague,
    );
  }

  /// 日支（`ganzhiDay` 第二個字）
  String get dayZhi => ganzhiDay.substring(1);

  /// 日干（`ganzhiDay` 第一個字）
  String get dayGan => ganzhiDay.substring(0, 1);
}
```

- [ ] **Step 4: Run test，逐個 fixture 對**

```bash
cd "/Users/stephanieau/Desktop/Stephanie-Google Drive/dev/xuanli" && dart test test/engine/almanac_test.dart -r expanded
```
Expected: 全部 PASS。**如果 `lunarLabel` 格式錯**（例如變成「五月月廿七」或者淨係得「廿七」），最大機會係 `getMonthInChinese()` 已經包埋「月」字或者根本冇——出現呢個情況就跟住個 fail message 改 `almanac.dart` 嗰行 string interpolation（例如去掉多餘嘅「月」或者改用 `lunar.toString()` 拆解），唔使改 test（fixture 係權威）。**如果 `traditionalize` 漏字**（例如某個宜/忌詞冇轉繁體），跟住 fail 訊息去 `wuxing_tables.dart` 嘅 `_simplifiedToTraditional` 加返個 entry。

- [ ] **Step 5: Commit**

```bash
cd "/Users/stephanieau/Desktop/Stephanie-Google Drive/dev/xuanli"
git add lib/engine/almanac.dart test/engine/almanac_test.dart
git commit -m "feat(engine): add almanac.dart with golden fixture coverage"
```

---

## Task 3: `bazi.dart` — 八字四柱 + 子時界線

**Files:**
- Create: `lib/engine/bazi.dart`
- Test: `test/engine/bazi_test.dart`

- [ ] **Step 1: 寫 failing test（子時界線 + 阿玄四柱）**

`test/engine/bazi_test.dart`:
```dart
import 'package:test/test.dart';
import 'package:xuanli/engine/bazi.dart';

void main() {
  group('子時界線（晚子時歸翌日，sect 1）', () {
    test('2026-07-11 23:30 出生 → 日柱丁亥（唔係丙戌）', () {
      final result = computeBazi(
        birthDate: DateTime(2026, 7, 11),
        birthHour: 23,
        birthMinute: 30,
      );
      expect(result.pillars[2], '丁亥', reason: '晚子時（23:00-23:59）日柱歸翌日');
    });
  });

  group('阿玄 golden fixture（1999-09-20 09:30 香港, ISFP）', () {
    late BaziResult result;
    setUp(() {
      result = computeBazi(
        birthDate: DateTime(1999, 9, 20),
        birthHour: 9,
        birthMinute: 30,
      );
    });

    test('四柱 = 己卯 癸酉 乙亥 辛巳', () {
      expect(result.pillars, ['己卯', '癸酉', '乙亥', '辛巳']);
    });

    test('日主 = 乙木', () {
      expect(result.dayMaster, '乙木');
    });

    test('五行分佈 木2 火1 土1 金3 水2（權重制，未歸一）', () {
      expect(result.wuxingWeighted, {'木': 2, '火': 1, '土': 1, '金': 3, '水': 2});
    });

    test('五行百分比總和 = 100', () {
      final sum = result.wuxing.values.fold<int>(0, (a, b) => a + b);
      expect(sum, 100);
    });

    test('同黨 44% < 45% → 身弱', () {
      expect(result.isBodyStrong, isFalse);
    });

    test('身弱 → 喜水木、忌金土', () {
      expect(result.favorable.toSet(), {'水', '木'});
      expect(result.unfavorable.toSet(), {'金', '土'});
    });
  });
}
```

- [ ] **Step 2: Run test 確認 fail**

```bash
cd "/Users/stephanieau/Desktop/Stephanie-Google Drive/dev/xuanli" && dart test test/engine/bazi_test.dart
```
Expected: FAIL（`bazi.dart` 唔存在）。

- [ ] **Step 3: 寫實作（四柱 + setSect(1)）**

`lib/engine/bazi.dart`:
```dart
import 'package:lunar/lunar.dart';
import 'wuxing_tables.dart';

class BaziResult {
  final List<String> pillars; // 4 個（缺時辰得 3 個），["己卯","癸酉","乙亥","辛巳"]
  final Map<String, int> wuxingWeighted; // 未歸一嘅權重
  final Map<String, int> wuxing; // 歸一做百分比，總和 100
  final String dayMaster; // "乙木"
  final bool isBodyStrong; // 同黨 >= 45%
  final List<String> favorable; // 固定 2 個
  final List<String> unfavorable; // 固定 2 個

  BaziResult({
    required this.pillars,
    required this.wuxingWeighted,
    required this.wuxing,
    required this.dayMaster,
    required this.isBodyStrong,
    required this.favorable,
    required this.unfavorable,
  });
}

const List<String> _wuxingOrder = ['木', '火', '土', '金', '水'];

BaziResult computeBazi({
  required DateTime birthDate,
  int? birthHour, // null = 唔知時辰（三柱降級模式）
  int birthMinute = 0,
}) {
  // 冇時辰時用中午 12:00 做安全預設（遠離子時邊界），只攞年月日三柱。
  final hour = birthHour ?? 12;
  final solar = Solar.fromYmdHms(
      birthDate.year, birthDate.month, birthDate.day, hour, birthMinute, 0);
  final lunar = solar.getLunar();
  final eightChar = lunar.getEightChar();
  eightChar.setSect(1); // 晚子時日柱歸翌日流派，lunar 預設係流派 2，必須顯式設

  final fourPillars = [
    eightChar.getYear(),
    eightChar.getMonth(),
    eightChar.getDay(),
    eightChar.getTime(),
  ];
  final pillars = birthHour == null ? fourPillars.sublist(0, 3) : fourPillars;

  final dayGan = pillars[2].substring(0, 1);
  final dayMasterElement = ganWuxing[dayGan]!;
  final dayMaster = '$dayGan$dayMasterElement';

  final wuxingWeighted = _weightedWuxing(pillars);
  final wuxing = _normalizeToPercent(wuxingWeighted);

  final sameParty = _sameSideElements(dayMasterElement);
  final sameWeight =
      sameParty.fold<int>(0, (sum, el) => sum + (wuxingWeighted[el] ?? 0));
  final totalWeight =
      wuxingWeighted.values.fold<int>(0, (a, b) => a + b);
  final samePartyPercent = totalWeight == 0 ? 0 : sameWeight * 100 / totalWeight;
  final isBodyStrong = samePartyPercent >= 45;

  final List<String> favorable;
  final List<String> unfavorable;
  if (isBodyStrong) {
    // 身強：喜 = 剋日主(官殺) + 日主所生(食傷)；忌 = 生日主(印) + 同日主(比劫)
    favorable = [
      elementThatControls(dayMasterElement),
      elementGeneratedBy(dayMasterElement),
    ];
    unfavorable = [
      elementThatGenerates(dayMasterElement),
      dayMasterElement,
    ];
  } else {
    // 身弱：喜 = 生日主(印) + 同日主(比劫)；忌 = 剋日主(官殺) + 日主所剋(財)
    favorable = [
      elementThatGenerates(dayMasterElement),
      dayMasterElement,
    ];
    unfavorable = [
      elementThatControls(dayMasterElement),
      elementControlledBy(dayMasterElement),
    ];
  }

  return BaziResult(
    pillars: pillars,
    wuxingWeighted: wuxingWeighted,
    wuxing: wuxing,
    dayMaster: dayMaster,
    isBodyStrong: isBodyStrong,
    favorable: favorable,
    unfavorable: unfavorable,
  );
}

/// 同黨 = 生日主(印) + 同日主(比劫) 嘅五行
List<String> _sameSideElements(String dayMasterElement) {
  return [elementThatGenerates(dayMasterElement), dayMasterElement];
}

/// 逐柱計權重：天干 ×1、地支本氣 ×1，月支（pillars[1] 嘅地支）×2。
Map<String, int> _weightedWuxing(List<String> pillars) {
  final weighted = <String, int>{for (final e in _wuxingOrder) e: 0};
  for (var i = 0; i < pillars.length; i++) {
    final gan = pillars[i].substring(0, 1);
    final zhi = pillars[i].substring(1, 2);
    final isMonthPillar = i == 1;

    final ganElement = ganWuxing[gan]!;
    weighted[ganElement] = weighted[ganElement]! + 1;

    final zhiElement = zhiWuxing[zhi]!;
    weighted[zhiElement] = weighted[zhiElement]! + (isMonthPillar ? 2 : 1);
  }
  return weighted;
}

/// 四捨五入做百分比，殘差加喺權重最大嗰行（同分按 木火土金水 序）。
Map<String, int> _normalizeToPercent(Map<String, int> weighted) {
  final total = weighted.values.fold<int>(0, (a, b) => a + b);
  if (total == 0) return {for (final e in _wuxingOrder) e: 0};

  final rounded = <String, int>{};
  for (final e in _wuxingOrder) {
    rounded[e] = ((weighted[e]! * 100) / total).round();
  }
  final sum = rounded.values.fold<int>(0, (a, b) => a + b);
  final residual = 100 - sum;
  if (residual != 0) {
    final target = _wuxingOrder
        .reduce((a, b) => weighted[a]! >= weighted[b]! ? a : b);
    rounded[target] = rounded[target]! + residual;
  }
  return rounded;
}
```

- [ ] **Step 4: Run test 確認 pass**

```bash
cd "/Users/stephanieau/Desktop/Stephanie-Google Drive/dev/xuanli" && dart test test/engine/bazi_test.dart -r expanded
```
Expected: 全部 PASS。呢個係 spec §6.1 嘅 end-to-end golden test，如果 fail 喺 `wuxingWeighted` 唔啱，先查 `_weightedWuxing` 嘅月支×2 邏輯（唔係月干×2——呢個位好易錯，spec 原文淨係話「月支 ×2」）。

- [ ] **Step 5: Commit**

```bash
cd "/Users/stephanieau/Desktop/Stephanie-Google Drive/dev/xuanli"
git add lib/engine/bazi.dart test/engine/bazi_test.dart
git commit -m "feat(engine): add bazi four-pillar, wuxing, and favorable-element calc"
```

---

## Task 4: `bazi.dart` — 缺時辰降級模式 + 農曆輸入

**Files:**
- Modify: `lib/engine/bazi.dart`
- Test: `test/engine/bazi_test.dart`（加 group）

- [ ] **Step 1: 加 failing test**

喺 `test/engine/bazi_test.dart` 加：
```dart
  group('缺時辰降級模式（三柱）', () {
    test('冇 birthHour → pillars 得 3 個（冇時柱）', () {
      final result = computeBazi(birthDate: DateTime(1999, 9, 20), birthHour: null);
      expect(result.pillars.length, 3);
      expect(result.pillars, ['己卯', '癸酉', '乙亥']);
    });

    test('三柱模式五行分佈都計到（分母跟 6 字調整）', () {
      final result = computeBazi(birthDate: DateTime(1999, 9, 20), birthHour: null);
      final sum = result.wuxing.values.fold<int>(0, (a, b) => a + b);
      expect(sum, 100);
      expect(result.dayMaster, '乙木');
    });
  });

  group('農曆輸入', () {
    test('農曆轉公曆：1999 年農曆八月十一 → 公曆 1999-09-20', () {
      final solarDate = lunarToSolarDate(year: 1999, month: 8, day: 11, isLeapMonth: false);
      expect(solarDate, DateTime(1999, 9, 20));
    });
  });
```

- [ ] **Step 2: Run test 確認 fail**

```bash
cd "/Users/stephanieau/Desktop/Stephanie-Google Drive/dev/xuanli" && dart test test/engine/bazi_test.dart
```
Expected: 缺時辰 group 應該已經 PASS（Task 3 個實作已經處理咗 `birthHour == null` 嘅分支）；`lunarToSolarDate` fail（未定義）。

- [ ] **Step 3: 加 `lunarToSolarDate`**

喺 `lib/engine/bazi.dart` 加（喺 import 之後、`BaziResult` class 之前）：
```dart
/// 農曆年月日（+閏月 flag）轉公曆 DateTime，畀 onboarding 農曆輸入用。
DateTime lunarToSolarDate({
  required int year,
  required int month,
  required int day,
  required bool isLeapMonth,
}) {
  final lunar = Lunar.fromYmd(year, isLeapMonth ? -month : month, day);
  final solar = lunar.getSolar();
  return DateTime(solar.getYear(), solar.getMonth(), solar.getDay());
}
```

- [ ] **Step 4: Run test 確認 pass**

```bash
cd "/Users/stephanieau/Desktop/Stephanie-Google Drive/dev/xuanli" && dart test test/engine/bazi_test.dart -r expanded
```
Expected: 全部 PASS。**如果 `lunarToSolarDate` fail**：`lunar` package 用負數月份表示閏月係 6tail 系列（Java/JS/Go 版）一致嘅慣例，但 Dart 版未實測過——如果 `Lunar.fromYmd(-6, ...)` 拋錯或者結果錯晒，改用 `Lunar.fromYmd` 前先查 `flutter pub deps` 裝落嚟嗰個版本嘅 `lunar` 源碼（`~/.pub-cache/hosted/pub.dev/lunar-*/lib/`）搵 `fromYmd` 定義，確認閏月點表示。

- [ ] **Step 5: Commit**

```bash
cd "/Users/stephanieau/Desktop/Stephanie-Google Drive/dev/xuanli"
git add lib/engine/bazi.dart test/engine/bazi_test.dart
git commit -m "feat(engine): add lunar-to-solar conversion for onboarding input"
```

---

## Task 5: `models/profile.dart` + `models/day_reading.dart`

**Files:**
- Create: `lib/models/profile.dart`
- Create: `lib/models/day_reading.dart`
- Test: `test/engine/models_test.dart`

呢兩個係純數據類（spec §5），冇邏輯，用 JSON serialization 做 test（因為 Task storage 服務要用）。

- [ ] **Step 1: 寫 failing test**

`test/engine/models_test.dart`:
```dart
import 'package:test/test.dart';
import 'package:xuanli/models/profile.dart';
import 'package:xuanli/models/day_reading.dart';

void main() {
  test('Profile toJson/fromJson round-trip', () {
    final profile = Profile(
      id: 'p1',
      name: '阿玄',
      birthDate: DateTime(1999, 9, 20),
      birthHour: 9,
      birthPlace: '香港',
      mbti: 'ISFP',
      pillars: ['己卯', '癸酉', '乙亥', '辛巳'],
      wuxing: {'木': 22, '火': 11, '土': 11, '金': 33, '水': 23},
      favorable: ['水', '木'],
      unfavorable: ['金', '土'],
      dayMaster: '乙木',
      ziweiStar: '太陰',
      zodiac: '兔',
    );
    final json = profile.toJson();
    final restored = Profile.fromJson(json);
    expect(restored.name, '阿玄');
    expect(restored.pillars, profile.pillars);
    expect(restored.birthDate, profile.birthDate);
    expect(restored.birthHour, 9);
  });

  test('Profile birthHour null（缺時辰）round-trip', () {
    final profile = Profile(
      id: 'p1', name: '我', birthDate: DateTime(1999, 9, 20), birthHour: null,
      birthPlace: '香港', mbti: 'ISFP', pillars: ['己卯', '癸酉', '乙亥'],
      wuxing: {'木': 20, '火': 20, '土': 20, '金': 20, '水': 20},
      favorable: ['水', '木'], unfavorable: ['金', '土'], dayMaster: '乙木',
      ziweiStar: '太陰', zodiac: '兔',
    );
    expect(Profile.fromJson(profile.toJson()).birthHour, isNull);
  });

  test('YjItem 有 label 同 matchesUser', () {
    const item = YjItem(label: '祭祀', matchesUser: true);
    expect(item.label, '祭祀');
    expect(item.matchesUser, isTrue);
  });

  test('DayReading 建構', () {
    final reading = DayReading(
      date: DateTime(2026, 7, 11),
      ganzhiDay: '丙戌',
      lunarLabel: '五月廿七',
      zhiXing: '平',
      chong: '沖龍煞北',
      fortuneScore: 42,
      mbtiScore: 60,
      band: '平',
      yi: const [YjItem(label: '祭祀', matchesUser: false)],
      ji: const [YjItem(label: '諸事不宜', matchesUser: false)],
      advice: '今日宜靜不宜動。',
      clashWarning: null,
      avoidHour: null,
    );
    expect(reading.band, '平');
    expect(reading.yi.first.label, '祭祀');
  });
}
```

- [ ] **Step 2: Run test 確認 fail**

```bash
cd "/Users/stephanieau/Desktop/Stephanie-Google Drive/dev/xuanli" && dart test test/engine/models_test.dart
```
Expected: FAIL（models 未定義）。

- [ ] **Step 3: 寫實作**

`lib/models/profile.dart`:
```dart
class Profile {
  final String id;
  final String name;
  final DateTime birthDate;
  final int? birthHour; // null = 唔知時辰
  final String birthPlace;
  final String mbti;
  final List<String> pillars;
  final Map<String, int> wuxing;
  final List<String> favorable;
  final List<String> unfavorable;
  final String dayMaster;
  final String ziweiStar;
  final String zodiac;

  Profile({
    required this.id,
    required this.name,
    required this.birthDate,
    required this.birthHour,
    required this.birthPlace,
    required this.mbti,
    required this.pillars,
    required this.wuxing,
    required this.favorable,
    required this.unfavorable,
    required this.dayMaster,
    required this.ziweiStar,
    required this.zodiac,
  });

  /// 檔案完整度：有時辰 = 100%，冇時辰（三柱降級模式）= 80%。
  int get completeness => birthHour == null ? 80 : 100;

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'birthDate': birthDate.toIso8601String(),
        'birthHour': birthHour,
        'birthPlace': birthPlace,
        'mbti': mbti,
        'pillars': pillars,
        'wuxing': wuxing,
        'favorable': favorable,
        'unfavorable': unfavorable,
        'dayMaster': dayMaster,
        'ziweiStar': ziweiStar,
        'zodiac': zodiac,
      };

  factory Profile.fromJson(Map<String, dynamic> json) => Profile(
        id: json['id'] as String,
        name: json['name'] as String,
        birthDate: DateTime.parse(json['birthDate'] as String),
        birthHour: json['birthHour'] as int?,
        birthPlace: json['birthPlace'] as String,
        mbti: json['mbti'] as String,
        pillars: List<String>.from(json['pillars'] as List),
        wuxing: Map<String, int>.from(json['wuxing'] as Map),
        favorable: List<String>.from(json['favorable'] as List),
        unfavorable: List<String>.from(json['unfavorable'] as List),
        dayMaster: json['dayMaster'] as String,
        ziweiStar: json['ziweiStar'] as String,
        zodiac: json['zodiac'] as String,
      );
}
```

`lib/models/day_reading.dart`:
```dart
class YjItem {
  final String label;
  final bool matchesUser;
  const YjItem({required this.label, required this.matchesUser});
}

class DayReading {
  final DateTime date;
  final String ganzhiDay;
  final String lunarLabel;
  final String zhiXing;
  final String chong;
  final int fortuneScore;
  final int mbtiScore;
  final String band; // "吉"|"平"|"忌"
  final List<YjItem> yi;
  final List<YjItem> ji;
  final String advice;
  final String? clashWarning;
  final String? avoidHour;

  DayReading({
    required this.date,
    required this.ganzhiDay,
    required this.lunarLabel,
    required this.zhiXing,
    required this.chong,
    required this.fortuneScore,
    required this.mbtiScore,
    required this.band,
    required this.yi,
    required this.ji,
    required this.advice,
    required this.clashWarning,
    required this.avoidHour,
  });
}
```

- [ ] **Step 4: Run test 確認 pass**

```bash
cd "/Users/stephanieau/Desktop/Stephanie-Google Drive/dev/xuanli" && dart test test/engine/models_test.dart -r expanded
```
Expected: 全部 PASS。

- [ ] **Step 5: Commit**

```bash
cd "/Users/stephanieau/Desktop/Stephanie-Google Drive/dev/xuanli"
git add lib/models/profile.dart lib/models/day_reading.dart test/engine/models_test.dart
git commit -m "feat(models): add Profile and DayReading data classes"
```

---

## Task 6: `scoring.dart` — 命理分（fortuneScore）

**Files:**
- Create: `lib/engine/scoring.dart`
- Test: `test/engine/scoring_test.dart`

- [ ] **Step 1: 寫 failing test（spec §11 smoke tests）**

`test/engine/scoring_test.dart`:
```dart
import 'package:test/test.dart';
import 'package:xuanli/engine/almanac.dart';
import 'package:xuanli/engine/scoring.dart';

void main() {
  // 阿玄：喜水木、忌金土
  const favorable = ['水', '木'];
  const unfavorable = ['金', '土'];

  group('fortuneScore smoke tests', () {
    test('2026-07-14（破日 + 諸事不宜）分數 <=40 帶「忌」', () {
      final day = AlmanacDay.forDate(DateTime(2026, 7, 14));
      final result = computeFortuneScore(
        day: day, favorable: favorable, unfavorable: unfavorable, userYearZhi: '寅');
      expect(result.score, lessThanOrEqualTo(40));
      expect(result.band, '忌');
    });

    test('2026-07-16 對喜木用戶 >=70 帶「吉」', () {
      final day = AlmanacDay.forDate(DateTime(2026, 7, 16));
      // 2026-07-16 = 辛卯（日干辛=金，日支卯=木）。用呢個用戶淨係試「喜木」對日支嘅加分路徑。
      final result = computeFortuneScore(
        day: day, favorable: const ['木'], unfavorable: const ['土'], userYearZhi: '寅');
      expect(result.score, greaterThanOrEqualTo(70));
      expect(result.band, '吉');
    });

    test('同 input 行 100 次結果 identical（deterministic）', () {
      final day = AlmanacDay.forDate(DateTime(2026, 7, 15));
      final scores = List.generate(
        100,
        (_) => computeFortuneScore(
            day: day, favorable: favorable, unfavorable: unfavorable, userYearZhi: '子').score,
      );
      expect(scores.toSet().length, 1);
    });
  });

  group('沖生肖', () {
    test('肖龍用戶喺 2026-07-11（沖龍）clashWarning 非空且 -20 已計入', () {
      final day = AlmanacDay.forDate(DateTime(2026, 7, 11));
      // 用戶生肖龍 → 年支辰
      final withClash = computeFortuneScore(
          day: day, favorable: favorable, unfavorable: unfavorable, userYearZhi: '辰');
      final withoutClash = computeFortuneScore(
          day: day, favorable: favorable, unfavorable: unfavorable, userYearZhi: '子');
      expect(withClash.clashWarning, isNotNull);
      expect(withClash.clashWarning, contains('龍'));
      expect(withoutClash.clashWarning, isNull);
      expect(withClash.score, lessThanOrEqualTo(withoutClash.score - 20));
    });
  });

  group('band 分帶', () {
    test('>=70 吉，40-69 平，<=39 忌', () {
      expect(bandFor(70), '吉');
      expect(bandFor(100), '吉');
      expect(bandFor(69), '平');
      expect(bandFor(40), '平');
      expect(bandFor(39), '忌');
      expect(bandFor(0), '忌');
    });
  });
}
```

- [ ] **Step 2: Run test 確認 fail**

```bash
cd "/Users/stephanieau/Desktop/Stephanie-Google Drive/dev/xuanli" && dart test test/engine/scoring_test.dart
```
Expected: FAIL（`scoring.dart` 未定義）。

- [ ] **Step 3: 寫實作**

`lib/engine/scoring.dart`:
```dart
import 'almanac.dart';
import 'wuxing_tables.dart';

class FortuneScoreResult {
  final int score;
  final String band;
  final String? clashWarning;
  FortuneScoreResult({required this.score, required this.band, required this.clashWarning});
}

const Map<String, int> _zhiXingBase = {
  '建': 55, '除': 65, '滿': 55, '平': 50, '定': 65, '執': 55,
  '破': 20, '危': 50, '成': 70, '收': 50, '開': 65, '閉': 35,
};

String bandFor(int score) {
  if (score >= 70) return '吉';
  if (score >= 40) return '平';
  return '忌';
}

FortuneScoreResult computeFortuneScore({
  required AlmanacDay day,
  required List<String> favorable,
  required List<String> unfavorable,
  required String userYearZhi,
}) {
  var score = _zhiXingBase[day.zhiXing] ?? 50;

  score += (day.jiShenCount * 3).clamp(0, 12);
  score -= (day.xiongShaCount * 4).clamp(0, 16);

  final dayGanElement = ganWuxing[day.dayGan]!;
  if (favorable.contains(dayGanElement)) score += 8;
  if (unfavorable.contains(dayGanElement)) score -= 8;

  final dayZhiElement = zhiWuxing[day.dayZhi]!;
  if (favorable.contains(dayZhiElement)) score += 8;
  if (unfavorable.contains(dayZhiElement)) score -= 8;

  String? clashWarning;
  if (zhiClash[day.dayZhi] == userYearZhi) {
    score -= 20;
    clashWarning = '今日沖你生肖（${_zhiToZodiac[userYearZhi]}）';
  }

  if (day.isJiSevere) {
    score = score > 40 ? 40 : score;
  }

  score = score.clamp(0, 100);

  return FortuneScoreResult(score: score, band: bandFor(score), clashWarning: clashWarning);
}

const Map<String, String> _zhiToZodiac = {
  '子': '鼠', '丑': '牛', '寅': '虎', '卯': '兔', '辰': '龍', '巳': '蛇',
  '午': '馬', '未': '羊', '申': '猴', '酉': '雞', '戌': '狗', '亥': '豬',
};
```

- [ ] **Step 4: Run test 確認 pass**

```bash
cd "/Users/stephanieau/Desktop/Stephanie-Google Drive/dev/xuanli" && dart test test/engine/scoring_test.dart -r expanded
```
Expected: 全部 PASS。如果 2026-07-16 個 test fail 喺分數唔夠 70，檢查番 `_zhiXingBase['成']=70` 加埋 `+8`（日支卯屬木，favorable=['木']）已經 >=70，冇 jishen/xiongsha 都夠——如果仲係唔夠，print 中間值查邊步扣咗分。

- [ ] **Step 5: Commit**

```bash
cd "/Users/stephanieau/Desktop/Stephanie-Google Drive/dev/xuanli"
git add lib/engine/scoring.dart test/engine/scoring_test.dart
git commit -m "feat(engine): add fortune score calculation with golden fixtures"
```

---

## Task 7: `scoring.dart` — 避開時辰（avoidHour）

**Files:**
- Modify: `lib/engine/scoring.dart`
- Test: `test/engine/scoring_test.dart`（加 group）

十二時辰地支同鐘點對照：子23-1／丑1-3／寅3-5／卯5-7／辰7-9／巳9-11／午11-13／未13-15／申15-17／酉17-19／戌19-21／亥21-23。

- [ ] **Step 1: 加 failing test**

喺 `test/engine/scoring_test.dart` 加：
```dart
  group('避開時辰', () {
    test('用戶日支寅，申時（15-17）沖寅 → avoidHour = "申時 15–17"', () {
      expect(computeAvoidHour('寅'), '申時 15–17');
    });
    test('用戶日支申，寅時（3-5）沖申', () {
      expect(computeAvoidHour('申'), '寅時 3–5');
    });
    test('每個地支都有對應沖時辰（冇 null case）', () {
      for (final zhi in ['子', '丑', '卯', '辰', '巳', '午', '未', '酉', '戌', '亥']) {
        expect(computeAvoidHour(zhi), isNotNull);
      }
    });
  });
```

- [ ] **Step 2: Run test 確認 fail**

```bash
cd "/Users/stephanieau/Desktop/Stephanie-Google Drive/dev/xuanli" && dart test test/engine/scoring_test.dart
```
Expected: FAIL（`computeAvoidHour` 未定義）。

- [ ] **Step 3: 加實作**

喺 `lib/engine/scoring.dart` 加：
```dart
const Map<String, String> _zhiHourRange = {
  '子': '23–1', '丑': '1–3', '寅': '3–5', '卯': '5–7',
  '辰': '7–9', '巳': '9–11', '午': '11–13', '未': '13–15',
  '申': '15–17', '酉': '17–19', '戌': '19–21', '亥': '21–23',
};

/// 用戶日支 [userDayZhi] → 沖佢嘅時辰標籤（例如「申時 15–17」）。
/// 十二地支必定有對沖時辰，唔會有 null case。
String computeAvoidHour(String userDayZhi) {
  final clashingZhi = zhiClash[userDayZhi]!;
  return '$clashingZhi時 ${_zhiHourRange[clashingZhi]}';
}
```

- [ ] **Step 4: Run test 確認 pass**

```bash
cd "/Users/stephanieau/Desktop/Stephanie-Google Drive/dev/xuanli" && dart test test/engine/scoring_test.dart -r expanded
```
Expected: 全部 PASS。

- [ ] **Step 5: Commit**

```bash
cd "/Users/stephanieau/Desktop/Stephanie-Google Drive/dev/xuanli"
git add lib/engine/scoring.dart test/engine/scoring_test.dart
git commit -m "feat(engine): add avoid-hour calculation"
```

---

## Task 8: `scoring.dart` — 狀態契合度（mbtiScore，§6.3）

**Files:**
- Modify: `lib/engine/scoring.dart`
- Test: `test/engine/scoring_test.dart`（加 group）

四軸獨立計，每軸 25（命中）／15（唔明確）／8（唔命中）。**E/I 軸冇「唔明確」狀態**（12 個建除值已經窮盡分咗兩組，冇灰色地帶），淨係 25 或 8。

- [ ] **Step 1: 加 failing test**

```dart
  group('契合度四軸（獨立於命理分）', () {
    test('E/I：建除屬動（建除危成開）對 E 高分', () {
      // 2026-07-15 zhiXing='危'（屬動）
      final day = AlmanacDay.forDate(DateTime(2026, 7, 15));
      expect(axisScoreEI(day, 'E'), 25);
      expect(axisScoreEI(day, 'I'), 8);
    });
    test('E/I：建除屬靜（平定收閉破執滿）對 I 高分', () {
      // 2026-07-11 zhiXing='平'（屬靜）
      final day = AlmanacDay.forDate(DateTime(2026, 7, 11));
      expect(axisScoreEI(day, 'I'), 25);
      expect(axisScoreEI(day, 'E'), 8);
    });

    test('S/N：宜項 >=6 具體 → 利 S', () {
      // 2026-07-12 宜：祭祀、祈福、求嗣、開光、入宅（起碼 5 項，用 fixture 節錄）
      final day = AlmanacDay.forDate(DateTime(2026, 7, 12));
      expect(day.isYiVague, isFalse);
      final sScore = axisScoreSN(day, 'S');
      final nScore = axisScoreSN(day, 'N');
      expect(sScore, greaterThanOrEqualTo(nScore));
    });
    test('S/N：宜：餘事勿取（isYiVague）→ 利 N', () {
      final day = AlmanacDay.forDate(DateTime(2026, 7, 14));
      expect(axisScoreSN(day, 'N'), 25);
      expect(axisScoreSN(day, 'S'), 8);
    });

    test('T/F：吉神 >=3 → 利 F', () {
      final day = AlmanacDay.forDate(DateTime(2026, 7, 12));
      if (day.jiShenCount >= 3) {
        expect(axisScoreTF(day, 'F'), 25);
        expect(axisScoreTF(day, 'T'), 8);
      }
    });

    test('J/P：無沖無破（穩定）→ 利 J；沖/破/危 → 利 P', () {
      final stableDay = AlmanacDay.forDate(DateTime(2026, 7, 12)); // zhiXing='定'
      expect(axisScoreJP(stableDay, hasClash: false, userLetter: 'J'), 25);
      final volatileDay = AlmanacDay.forDate(DateTime(2026, 7, 14)); // zhiXing='破'
      expect(axisScoreJP(volatileDay, hasClash: false, userLetter: 'P'), 25);
      expect(axisScoreJP(volatileDay, hasClash: true, userLetter: 'P'), 25);
    });

    test('computeMbtiScore 加返四軸並 clamp 0-100', () {
      final day = AlmanacDay.forDate(DateTime(2026, 7, 11));
      final score = computeMbtiScore(day: day, mbti: 'ISFP', hasClash: false);
      expect(score, inInclusiveRange(0, 100));
    });

    test('命理分同契合度完全獨立（唔會互相引用對方個 favorable/unfavorable）', () {
      final day = AlmanacDay.forDate(DateTime(2026, 7, 11));
      final mbtiScore1 = computeMbtiScore(day: day, mbti: 'ISFP', hasClash: false);
      final mbtiScore2 = computeMbtiScore(day: day, mbti: 'ISFP', hasClash: false);
      expect(mbtiScore1, mbtiScore2); // deterministic，冇食任何命理輸入
    });
  });
```

- [ ] **Step 2: Run test 確認 fail**

```bash
cd "/Users/stephanieau/Desktop/Stephanie-Google Drive/dev/xuanli" && dart test test/engine/scoring_test.dart
```
Expected: FAIL（四個 axisScore* function 未定義）。

- [ ] **Step 3: 加實作**

喺 `lib/engine/scoring.dart` 加：
```dart
const _dongZhiXing = {'建', '除', '危', '成', '開'};
const _jingZhiXing = {'平', '定', '收', '閉', '破', '執', '滿'};

/// E/I 軸：建除屬動 → E 高分；屬靜 → I 高分。冇灰色地帶（12 建除值已窮盡分兩組）。
int axisScoreEI(AlmanacDay day, String userLetter) {
  final dayLeansE = _dongZhiXing.contains(day.zhiXing);
  final matches = (dayLeansE && userLetter == 'E') || (!dayLeansE && userLetter == 'I');
  return matches ? 25 : 8;
}

/// S/N 軸：宜項 >=6 具體 → 利 S；isYiVague（諸事不宜/餘事勿取）→ 利 N；中間 → 15（唔明確）。
int axisScoreSN(AlmanacDay day, String userLetter) {
  if (day.isYiVague) {
    return userLetter == 'N' ? 25 : 8;
  }
  if (day.yi.length >= 6) {
    return userLetter == 'S' ? 25 : 8;
  }
  return 15;
}

/// T/F 軸：吉神 >=3 → 利 F；凶煞 > 吉神（明顯偏凶）→ 利 T；中間 → 15。
int axisScoreTF(AlmanacDay day, String userLetter) {
  if (day.jiShenCount >= 3) {
    return userLetter == 'F' ? 25 : 8;
  }
  if (day.xiongShaCount > day.jiShenCount) {
    return userLetter == 'T' ? 25 : 8;
  }
  return 15;
}

/// J/P 軸：無沖（[hasClash]=false）且建除穩定（唔係破/危）→ 利 J；
/// 有沖或建除屬破/危（變動）→ 利 P；中間 → 15。
int axisScoreJP(AlmanacDay day, {required bool hasClash, required String userLetter}) {
  final isVolatile = hasClash || day.zhiXing == '破' || day.zhiXing == '危';
  if (isVolatile) {
    return userLetter == 'P' ? 25 : 8;
  }
  final isStable = !hasClash && (day.zhiXing == '定' || day.zhiXing == '成' || day.zhiXing == '收');
  if (isStable) {
    return userLetter == 'J' ? 25 : 8;
  }
  return 15;
}

/// 狀態契合度：四軸加埋，同命理分（favorable/unfavorable）完全獨立，
/// 淨係食 [day] 嘅客觀特徵 + 用戶 [mbti] 四個字母。
int computeMbtiScore({required AlmanacDay day, required String mbti, required bool hasClash}) {
  final letters = mbti.split('');
  final score = axisScoreEI(day, letters[0]) +
      axisScoreSN(day, letters[1]) +
      axisScoreTF(day, letters[2]) +
      axisScoreJP(day, hasClash: hasClash, userLetter: letters[3]);
  return score.clamp(0, 100);
}
```

- [ ] **Step 4: Run test 確認 pass**

```bash
cd "/Users/stephanieau/Desktop/Stephanie-Google Drive/dev/xuanli" && dart test test/engine/scoring_test.dart -r expanded
```
Expected: 全部 PASS。

- [ ] **Step 5: Commit**

```bash
cd "/Users/stephanieau/Desktop/Stephanie-Google Drive/dev/xuanli"
git add lib/engine/scoring.dart test/engine/scoring_test.dart
git commit -m "feat(engine): add MBTI compatibility scoring (independent of fortune score)"
```

---

## Task 9: `almanac.dart` — 宜忌個人化排序（§6.5）

**Files:**
- Create: `lib/data/activity_categories.json`
- Modify: `lib/engine/almanac.dart`
- Test: `test/engine/almanac_test.dart`（加 group）

每個宜/忌項目屬一個活動類別（同 Task 10 個 activities 表共用類別 → 五行 對照），類別五行 ∈ 用戶喜 → `matchesUser=true`，排前面。

- [ ] **Step 1: 寫活動類別 → 五行對照表**

`lib/data/activity_categories.json`（key = 通勝關鍵字，value = 五行親和；內容直接取自 spec §7 表格「五行親和」一欄，逐個關鍵字展開）：
```json
{
  "理髮": "木",
  "移徙": "土", "入宅": "土",
  "立券": "金", "交易": "金", "訂盟": "金",
  "開市": "火", "開業": "火",
  "納財": "金",
  "嫁娶": "火", "納采": "火", "會親友": "火",
  "求醫": "水", "治病": "水",
  "出行": "火",
  "修造": "土", "動土": "土",
  "交車": "金",
  "求職": "火",
  "入學": "水", "求學": "水",
  "祭祀": "土", "祈福": "土"
}
```

- [ ] **Step 2: 寫 failing test**

喺 `test/engine/almanac_test.dart` 加：
```dart
  group('宜忌個人化排序', () {
    test('personalizedYi 將 matchesUser 嘅項目排前面，並標記 matchesUser', () {
      final day = AlmanacDay.forDate(DateTime(2026, 7, 12));
      // 2026-07-12 宜含「入宅」（五行=土）；用戶喜土
      final items = day.personalizedYi(favorable: const ['土']);
      final matched = items.where((i) => i.matchesUser).toList();
      expect(matched, isNotEmpty);
      expect(items.indexOf(matched.first), lessThan(items.length - matched.length + 1));
    });

    test('personalizedJi 同樣邏輯', () {
      final day = AlmanacDay.forDate(DateTime(2026, 7, 12));
      // 忌含「理髮」（五行=木）
      final items = day.personalizedJi(favorable: const ['木']);
      expect(items.any((i) => i.label == '理髮' && i.matchesUser), isTrue);
    });

    test('宜取頭 3-5、忌取頭 2-4', () {
      final day = AlmanacDay.forDate(DateTime(2026, 7, 12));
      final yi = day.personalizedYi(favorable: const []);
      final ji = day.personalizedJi(favorable: const []);
      expect(yi.length, inInclusiveRange(1, 5));
      expect(ji.length, inInclusiveRange(1, 4));
    });
  });
```

- [ ] **Step 3: Run test 確認 fail**

```bash
cd "/Users/stephanieau/Desktop/Stephanie-Google Drive/dev/xuanli" && dart test test/engine/almanac_test.dart
```
Expected: FAIL（`personalizedYi`/`personalizedJi` 未定義）。

- [ ] **Step 4: 加實作**

`lib/engine/almanac.dart` 頂部加 import：
```dart
import 'dart:convert';
import 'dart:io';
import '../models/day_reading.dart';
```

喺 `AlmanacDay` class 入面加方法：
```dart
  List<YjItem> personalizedYi({required List<String> favorable}) {
    return _personalize(yi, favorable: favorable, maxCount: 5);
  }

  List<YjItem> personalizedJi({required List<String> favorable}) {
    return _personalize(ji, favorable: favorable, maxCount: 4);
  }

  List<YjItem> _personalize(List<String> items, {required List<String> favorable, required int maxCount}) {
    final scored = items.map((label) {
      final element = activityCategoryWuxing[label];
      final matches = element != null && favorable.contains(element);
      return YjItem(label: label, matchesUser: matches);
    }).toList();
    scored.sort((a, b) {
      if (a.matchesUser == b.matchesUser) return 0;
      return a.matchesUser ? -1 : 1;
    });
    final take = maxCount > scored.length ? scored.length : maxCount;
    return scored.sublist(0, take == 0 ? (scored.isEmpty ? 0 : 1) : take);
  }
```

喺檔案底部（class 後面）加 loader：
```dart
/// 通勝關鍵字 → 五行親和，源自 lib/data/activity_categories.json（spec §7）。
final Map<String, String> activityCategoryWuxing = _loadActivityCategories();

Map<String, String> _loadActivityCategories() {
  final file = File('lib/data/activity_categories.json');
  final jsonMap = json.decode(file.readAsStringSync()) as Map<String, dynamic>;
  return jsonMap.map((k, v) => MapEntry(k, v as String));
}
```

- [ ] **Step 5: Run test 確認 pass**

```bash
cd "/Users/stephanieau/Desktop/Stephanie-Google Drive/dev/xuanli" && dart test test/engine/almanac_test.dart -r expanded
```
Expected: 全部 PASS。**注意**：`File('lib/data/...')` 用相對路徑，`dart test` 一定要喺 repo 根目錄行先讀到（同 CLAUDE.md 常用指令一致）。Phase 2 執到 Flutter app（`flutter run`）嗰陣，`File()` 讀 assets 會唔得，到時要改用 `rootBundle.loadString('lib/data/activity_categories.json')`（連埋要喺 `pubspec.yaml` 嘅 `flutter: assets:` 登記）——依家 Phase 1 純 dart test 環境唔使理，但呢個係已知嘅 Phase 2 TODO，寫低喺呢個 task 底部提個未來 self 一聲。

- [ ] **Step 6: Commit**

```bash
cd "/Users/stephanieau/Desktop/Stephanie-Google Drive/dev/xuanli"
git add lib/data/activity_categories.json lib/engine/almanac.dart test/engine/almanac_test.dart
git commit -m "feat(engine): add personalized yi/ji sorting by user's favorable elements"
```

---

## Task 10: `activity.dart` — 反向擇日

**Files:**
- Create: `lib/data/activities.json`
- Create: `lib/engine/activity.dart`
- Test: `test/engine/activity_test.dart`

`lib/data/activities.json` 內容直接由 spec §7 表格逐行轉 JSON（14 個活動，已經係鎖定內容，唔使自己作）：

- [ ] **Step 1: 寫 activities.json**

`lib/data/activities.json`:
```json
[
  {"name": "剪髮", "hitKeywords": ["理髮"], "goodZhiXing": ["除", "執"], "element": "木", "avoidKeywords": ["理髮"]},
  {"name": "搬屋", "hitKeywords": ["移徙", "入宅"], "goodZhiXing": ["定", "成", "開"], "element": "土", "avoidKeywords": ["移徙", "入宅"]},
  {"name": "簽約", "hitKeywords": ["立券", "交易", "訂盟"], "goodZhiXing": ["定", "成"], "element": "金", "avoidKeywords": ["立券", "交易"]},
  {"name": "開業", "hitKeywords": ["開市", "開業"], "goodZhiXing": ["開", "成"], "element": "火", "avoidKeywords": ["開市"]},
  {"name": "求財投資", "hitKeywords": ["納財", "開市", "交易"], "goodZhiXing": ["成", "開", "收"], "element": "金", "avoidKeywords": ["納財"]},
  {"name": "表白約會", "hitKeywords": ["嫁娶", "納采", "會親友"], "goodZhiXing": ["定", "成", "開"], "element": "火", "avoidKeywords": ["嫁娶"]},
  {"name": "睇醫生", "hitKeywords": ["求醫", "治病"], "goodZhiXing": ["除", "破"], "element": "水", "avoidKeywords": []},
  {"name": "出遊", "hitKeywords": ["出行"], "goodZhiXing": ["開", "建"], "element": "火", "avoidKeywords": ["出行"]},
  {"name": "裝修動土", "hitKeywords": ["修造", "動土"], "goodZhiXing": ["建", "定"], "element": "土", "avoidKeywords": ["動土", "修造"]},
  {"name": "買車", "hitKeywords": ["納財", "交車"], "goodZhiXing": ["滿", "成"], "element": "金", "avoidKeywords": ["納財"]},
  {"name": "面試", "hitKeywords": ["求職", "出行", "會親友"], "goodZhiXing": ["成", "開"], "element": "火", "avoidKeywords": []},
  {"name": "考試", "hitKeywords": ["入學", "求學"], "goodZhiXing": ["成", "開"], "element": "水", "avoidKeywords": []},
  {"name": "擺酒", "hitKeywords": ["嫁娶", "開市", "會親友"], "goodZhiXing": ["定", "成"], "element": "火", "avoidKeywords": ["嫁娶"]},
  {"name": "拜神", "hitKeywords": ["祭祀", "祈福"], "goodZhiXing": ["除", "定", "開"], "element": "土", "avoidKeywords": ["祭祀", "祈福"]}
]
```

- [ ] **Step 2: 寫 failing test**

`test/engine/activity_test.dart`:
```dart
import 'package:test/test.dart';
import 'package:xuanli/engine/activity.dart';
import 'package:xuanli/engine/almanac.dart';
import 'package:xuanli/engine/scoring.dart';

void main() {
  group('反向擇日', () {
    test('14 個活動全部載入到', () {
      expect(loadActivities().length, 14);
      expect(loadActivities().map((a) => a.name), contains('睇醫生'));
    });

    test('活動出現喺忌關鍵字 → 淘汰', () {
      // 2026-07-12 忌含「理髮」，「剪髮」活動應該喺呢日俾淘汰
      final day = AlmanacDay.forDate(DateTime(2026, 7, 12));
      final activity = loadActivities().firstWhere((a) => a.name == '剪髮');
      final score = scoreActivityForDay(activity: activity, day: day, favorable: const [], fortuneScore: 50);
      expect(score, isNull, reason: '忌關鍵字命中即淘汰');
    });

    test('安全線：睇醫生永遠有結果，唔會俾淘汰', () {
      for (var d = 11; d <= 17; d++) {
        final day = AlmanacDay.forDate(DateTime(2026, 7, d));
        final activity = loadActivities().firstWhere((a) => a.name == '睇醫生');
        final score = scoreActivityForDay(activity: activity, day: day, favorable: const [], fortuneScore: 50);
        expect(score, isNotNull, reason: '2026-07-$d 睇醫生唔可以俾淘汰');
      }
    });

    test('rankActivities 喺範圍內排序取頭 5，星級 1-5', () {
      final dates = List.generate(7, (i) => DateTime(2026, 7, 11 + i));
      final results = rankActivities(
        activityName: '搬屋',
        dates: dates,
        favorable: const ['土'],
        fortuneScoreOf: (d) => AlmanacDay.forDate(d).zhiXing == '定' ? 80 : 50,
      );
      expect(results.length, lessThanOrEqualTo(5));
      for (final r in results) {
        expect(r.stars, inInclusiveRange(1, 5));
      }
      // 排序由高分到低分
      for (var i = 1; i < results.length; i++) {
        expect(results[i - 1].score, greaterThanOrEqualTo(results[i].score));
      }
    });
  });
}
```

- [ ] **Step 3: Run test 確認 fail**

```bash
cd "/Users/stephanieau/Desktop/Stephanie-Google Drive/dev/xuanli" && dart test test/engine/activity_test.dart
```
Expected: FAIL（`activity.dart` 未定義）。

- [ ] **Step 4: 寫實作**

`lib/engine/activity.dart`:
```dart
import 'dart:convert';
import 'dart:io';
import 'almanac.dart';

class Activity {
  final String name;
  final List<String> hitKeywords;
  final List<String> goodZhiXing;
  final String element;
  final List<String> avoidKeywords;

  Activity({
    required this.name,
    required this.hitKeywords,
    required this.goodZhiXing,
    required this.element,
    required this.avoidKeywords,
  });

  factory Activity.fromJson(Map<String, dynamic> json) => Activity(
        name: json['name'] as String,
        hitKeywords: List<String>.from(json['hitKeywords'] as List),
        goodZhiXing: List<String>.from(json['goodZhiXing'] as List),
        element: json['element'] as String,
        avoidKeywords: List<String>.from(json['avoidKeywords'] as List),
      );
}

class ActivityDayResult {
  final DateTime date;
  final int score;
  final int stars; // 1-5
  ActivityDayResult({required this.date, required this.score, required this.stars});
}

List<Activity> loadActivities() {
  final file = File('lib/data/activities.json');
  final list = json.decode(file.readAsStringSync()) as List;
  return list.map((e) => Activity.fromJson(e as Map<String, dynamic>)).toList();
}

/// 評分 = 活動分（關鍵字+建除命中）40% + 命理分 40% + 五行親和 20%。
/// [activity] 嘅 avoidKeywords 命中 [day] 嘅忌 → null（淘汰），**除非 avoidKeywords 為空**
/// （例如「睇醫生」設計上冇忌關鍵字，永遠唔會俾呢條規則淘汰——安全線見 spec §7）。
int? scoreActivityForDay({
  required Activity activity,
  required AlmanacDay day,
  required List<String> favorable,
  required int fortuneScore,
}) {
  if (activity.avoidKeywords.isNotEmpty &&
      activity.avoidKeywords.any((k) => day.ji.contains(k))) {
    return null;
  }

  final keywordHit = activity.hitKeywords.any((k) => day.yi.contains(k));
  final zhiXingHit = activity.goodZhiXing.contains(day.zhiXing);
  var activityScore = 0;
  if (keywordHit) activityScore += 60;
  if (zhiXingHit) activityScore += 40;
  activityScore = activityScore.clamp(0, 100);

  final elementBonus = favorable.contains(activity.element) ? 100 : 0;

  final total =
      (activityScore * 0.4 + fortuneScore * 0.4 + elementBonus * 0.2).round();
  return total.clamp(0, 100);
}

/// 喺 [dates] 範圍內幫 [activityName] 呢個活動排序，取分數最高頭 5 日。
/// [fortuneScoreOf] 由 caller 傳入（scoring.dart 嘅 computeFortuneScore 已經要 favorable/userYearZhi，
/// 呢度用 callback 避免 activity.dart 同 scoring.dart 互相 import 出現循環依賴）。
List<ActivityDayResult> rankActivities({
  required String activityName,
  required List<DateTime> dates,
  required List<String> favorable,
  required int Function(DateTime date) fortuneScoreOf,
}) {
  final activity = loadActivities().firstWhere((a) => a.name == activityName);
  final results = <ActivityDayResult>[];
  for (final date in dates) {
    final day = AlmanacDay.forDate(date);
    final fortuneScore = fortuneScoreOf(date);
    final score = scoreActivityForDay(
        activity: activity, day: day, favorable: favorable, fortuneScore: fortuneScore);
    if (score != null) {
      results.add(ActivityDayResult(date: date, score: score, stars: _starsFor(score)));
    }
  }
  results.sort((a, b) => b.score.compareTo(a.score));
  return results.take(5).toList();
}

int _starsFor(int score) {
  // 分數五等分：0-20→1, 21-40→2, 41-60→3, 61-80→4, 81-100→5
  final stars = (score / 20).ceil();
  return stars.clamp(1, 5);
}
```

- [ ] **Step 5: Run test 確認 pass**

```bash
cd "/Users/stephanieau/Desktop/Stephanie-Google Drive/dev/xuanli" && dart test test/engine/activity_test.dart -r expanded
```
Expected: 全部 PASS。

- [ ] **Step 6: Commit**

```bash
cd "/Users/stephanieau/Desktop/Stephanie-Google Drive/dev/xuanli"
git add lib/data/activities.json lib/engine/activity.dart test/engine/activity_test.dart
git commit -m "feat(engine): add reverse date-picking (activity ranking) with doctor-visit safety line"
```

---

## Task 11: `combos.json` loader（160 組合）

**Files:**
- Create: `lib/models/combo.dart`
- Test: `test/engine/combo_test.dart`

**唔准改 `lib/data/combos.json` 內容**（已寫好、已驗證）——呢個 task 淨係寫 loader + model class + 驗證 160 keys 齊全。

- [ ] **Step 1: 寫 failing test**

`test/engine/combo_test.dart`:
```dart
import 'package:test/test.dart';
import 'package:xuanli/models/combo.dart';

void main() {
  group('160 組合 loader', () {
    test('全部 160 個 key 齊全（10 日主 × 16 MBTI）', () {
      final combos = loadCombos();
      expect(combos.length, 160);

      const dayMasters = ['甲', '乙', '丙', '丁', '戊', '己', '庚', '辛', '壬', '癸'];
      const mbtiTypes = [
        'INTJ', 'INTP', 'ENTJ', 'ENTP', 'INFJ', 'INFP', 'ENFJ', 'ENFP',
        'ISTJ', 'ISFJ', 'ESTJ', 'ESFJ', 'ISTP', 'ISFP', 'ESTP', 'ESFP',
      ];
      for (final dm in dayMasters) {
        for (final mbti in mbtiTypes) {
          expect(combos.containsKey('${dm}_$mbti'), isTrue, reason: '缺 ${dm}_$mbti');
        }
      }
    });

    test('每個 combo 有齊 name/motto/description/strengths[3]/watchouts[3]/howToWin', () {
      final combos = loadCombos();
      final sample = combos['甲_INTJ']!;
      expect(sample.name, isNotEmpty);
      expect(sample.motto, isNotEmpty);
      expect(sample.description.length, inInclusiveRange(80, 130));
      expect(sample.strengths.length, 3);
      expect(sample.watchouts.length, 3);
      expect(sample.howToWin, isNotEmpty);
    });

    test('getCombo(dayMaster, mbti) 方便查詢', () {
      final combo = getCombo(dayGan: '甲', mbti: 'INTJ');
      expect(combo.name, '雪嶺孤松');
    });
  });
}
```

- [ ] **Step 2: Run test 確認 fail**

```bash
cd "/Users/stephanieau/Desktop/Stephanie-Google Drive/dev/xuanli" && dart test test/engine/combo_test.dart
```
Expected: FAIL（`combo.dart` 未定義）。

- [ ] **Step 3: 寫實作**

`lib/models/combo.dart`:
```dart
import 'dart:convert';
import 'dart:io';

class Combo {
  final String name;
  final String motto;
  final String description;
  final List<String> strengths;
  final List<String> watchouts;
  final String howToWin;

  Combo({
    required this.name,
    required this.motto,
    required this.description,
    required this.strengths,
    required this.watchouts,
    required this.howToWin,
  });

  factory Combo.fromJson(Map<String, dynamic> json) => Combo(
        name: json['name'] as String,
        motto: json['motto'] as String,
        description: json['description'] as String,
        strengths: List<String>.from(json['strengths'] as List),
        watchouts: List<String>.from(json['watchouts'] as List),
        howToWin: json['howToWin'] as String,
      );
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

Combo getCombo({required String dayGan, required String mbti}) {
  return loadCombos()['${dayGan}_$mbti']!;
}
```

- [ ] **Step 4: Run test 確認 pass**

```bash
cd "/Users/stephanieau/Desktop/Stephanie-Google Drive/dev/xuanli" && dart test test/engine/combo_test.dart -r expanded
```
Expected: 全部 PASS（如果 fail 喺缺 key，係 `lib/data/combos.json` 本身有缺漏——唔好自己補內容，記低邊個 key 缺咗，話返俾 Stephanie，因為呢個檔案「已驗證」係假設）。

- [ ] **Step 5: Commit**

```bash
cd "/Users/stephanieau/Desktop/Stephanie-Google Drive/dev/xuanli"
git add lib/models/combo.dart test/engine/combo_test.dart
git commit -m "feat(models): add combos.json loader with 160-key coverage test"
```

---

## Task 12: `ziwei.dart` — 簡化紫微主星對照（全模式＋降級模式共用）

**Files:**
- Create: `lib/engine/ziwei.dart`
- Test: `test/engine/ziwei_test.dart`

**已同 Stephanie 確認嘅範圍**：唔做真正紫微斗數排盤，全模式同降級模式**共用同一個「日支 → 簡化主星」對照表**。

- [ ] **Step 1: 寫 failing test**

`test/engine/ziwei_test.dart`:
```dart
import 'package:test/test.dart';
import 'package:xuanli/engine/ziwei.dart';

void main() {
  group('簡化紫微主星（日支對照，全模式同降級模式共用）', () {
    test('阿玄（日支亥）→ 太陰', () {
      expect(ziweiStarForDayZhi('亥'), '太陰');
    });
    test('十二地支都有對應主星（冇 null case）', () {
      const allZhi = ['子', '丑', '寅', '卯', '辰', '巳', '午', '未', '申', '酉', '戌', '亥'];
      for (final zhi in allZhi) {
        expect(ziweiStarForDayZhi(zhi), isNotNull);
        expect(ziweiStarForDayZhi(zhi), isNotEmpty);
      }
    });
    test('deterministic：同一個地支永遠攞返同一個主星', () {
      expect(ziweiStarForDayZhi('子'), ziweiStarForDayZhi('子'));
    });
  });
}
```

- [ ] **Step 2: Run test 確認 fail**

```bash
cd "/Users/stephanieau/Desktop/Stephanie-Google Drive/dev/xuanli" && dart test test/engine/ziwei_test.dart
```
Expected: FAIL（`ziwei.dart` 未定義）。

- [ ] **Step 3: 寫實作**

`lib/engine/ziwei.dart`:
```dart
/// **MVP 簡化版**：唔係正統紫微斗數排盤（冇做五虎遁月／定命宮／安十四主星訣）。
/// 全模式（有時辰）同降級模式（冇時辰）共用呢個「日支 → 簡化主星」對照表——
/// 呢個係同 Stephanie 傾過嘅範圍決定（見 docs/superpowers/plans/2026-07-23-xuanli-phase1-engine.md）。
/// 真正紫微命宮計算留返 spec §2 決定 11 講嘅「紫微深度文案」v2 先做。
const Map<String, String> _dayZhiToZiweiStar = {
  '子': '貪狼', '丑': '天府', '寅': '紫微', '卯': '天機',
  '辰': '天相', '巳': '天梁', '午': '太陽', '未': '巨門',
  '申': '七殺', '酉': '天同', '戌': '廉貞', '亥': '太陰',
};

/// [dayZhi] = 日柱地支（例如「亥」）。十二地支窮盡覆蓋，唔會有 null case。
String ziweiStarForDayZhi(String dayZhi) => _dayZhiToZiweiStar[dayZhi]!;
```

- [ ] **Step 4: Run test 確認 pass**

```bash
cd "/Users/stephanieau/Desktop/Stephanie-Google Drive/dev/xuanli" && dart test test/engine/ziwei_test.dart -r expanded
```
Expected: 全部 PASS。

- [ ] **Step 5: Commit**

```bash
cd "/Users/stephanieau/Desktop/Stephanie-Google Drive/dev/xuanli"
git add lib/engine/ziwei.dart test/engine/ziwei_test.dart
git commit -m "feat(engine): add simplified ziwei star lookup (MVP scope per Stephanie decision)"
```

---

## Task 13: `copywriter.dart` — 今日貼身建議（模板引擎）

**Files:**
- Create: `lib/data/mbti_tones.json`
- Create: `lib/engine/copywriter.dart`
- Test: `test/engine/copywriter_test.dart`

**內容範圍注意**：`mbti_tones.json` 要 16 型 × ≥6 句先算完成（spec §8.3），但 spec 本身冇提供任何一句實際文案——淨係風格規則（I 講獨處、E 講社交、F 講感受、T 講策略、廣東話自然語感、用「你」唔用「您」）。呢個 task 淨係起好 loader + 輪換邏輯 + **2 個型嘅真實例句**（夠 test 用）；其餘 14 型嘅內容係文案工作，唔喺呢份 engineering plan 範圍——執行到呢步見到，話返俾 Stephanie 想自己填、定係另開一個用 `humanizer-zh` skill 嘅 session 幫手起稿。

- [ ] **Step 1: 寫 mbti_tones.json（2 型示範內容，其餘留返文案工作）**

`lib/data/mbti_tones.json`:
```json
{
  "ISFP": [
    "你今日適合執靚一角，慢慢嚟，大計留返聽日。",
    "獨處嘅時間會俾你叉返電，唔使勉強自己社交。",
    "跟住個人感覺走就啱，唔使諗太多道理。",
    "手作或者微細嘅美感練習，今日特別啱你。",
    "有情緒就俾自己感受吓，唔使即刻處理晒。",
    "今日唔使急住表態，靜靜感受個節奏先。"
  ],
  "ISFJ": [
    "今日適合照顧身邊人，佢哋會記得你嘅心思。",
    "按部就班做熟悉嘅事，會令你安心好多。",
    "留啲時間畀返自己，唔使乜嘢都以人為先。",
    "細心留意小節，今日呢種特質特別派用場。",
    "有人需要幫手就伸手，但唔使勉強承擔晒。",
    "今日適合鞏固關係，一個電話或者一聲問候都夠。"
  ]
}
```

（其餘 14 型 = INTJ/INTP/ENTJ/ENTP/INFJ/INFP/ENFJ/ENFP/ISTJ/ESTJ/ESFJ/ISTP/ESTP/ESFP：**Phase 1 唔封鎖**，容許 JSON 得返呢 2 個 key 通過測試；Phase 2 UI 接埋所有型之前要補齊。）

- [ ] **Step 2: 寫 failing test**

`test/engine/copywriter_test.dart`:
```dart
import 'package:test/test.dart';
import 'package:xuanli/engine/almanac.dart';
import 'package:xuanli/engine/copywriter.dart';

void main() {
  group('今日貼身建議模板引擎', () {
    test('拼接命理段 + MBTI 段（有紫微段可省略）', () {
      final day = AlmanacDay.forDate(DateTime(2026, 7, 11));
      final advice = buildAdvice(
        day: day,
        favorable: const ['水', '木'],
        unfavorable: const ['金', '土'],
        mbti: 'ISFP',
        ziweiStar: null,
        avoidHour: '申時 15–17',
      );
      expect(advice, isNotEmpty);
      expect(advice, contains('避開申時')); // avoidHour 一定要出現
    });

    test('template 輪換用 dayOfYear % length，deterministic', () {
      final day = AlmanacDay.forDate(DateTime(2026, 7, 11));
      final advice1 = buildAdvice(
        day: day, favorable: const ['水'], unfavorable: const ['金'],
        mbti: 'ISFP', ziweiStar: null, avoidHour: null,
      );
      final advice2 = buildAdvice(
        day: day, favorable: const ['水'], unfavorable: const ['金'],
        mbti: 'ISFP', ziweiStar: null, avoidHour: null,
      );
      expect(advice1, advice2);
    });

    test('唔同 dayOfYear 揀唔同 MBTI 語氣句（起碼喺 2 型入面有變化）', () {
      final day1 = AlmanacDay.forDate(DateTime(2026, 1, 1));
      final day2 = AlmanacDay.forDate(DateTime(2026, 1, 2));
      final advice1 = buildAdvice(
        day: day1, favorable: const [], unfavorable: const [],
        mbti: 'ISFP', ziweiStar: null, avoidHour: null,
      );
      final advice2 = buildAdvice(
        day: day2, favorable: const [], unfavorable: const [],
        mbti: 'ISFP', ziweiStar: null, avoidHour: null,
      );
      // 唔要求一定唔同（6 句可能撞號），但起碼函數要行得通冇 crash
      expect(advice1, isNotEmpty);
      expect(advice2, isNotEmpty);
    });

    test('冇 avoidHour 就唔會出現「避開」字眼', () {
      final day = AlmanacDay.forDate(DateTime(2026, 7, 12));
      final advice = buildAdvice(
        day: day, favorable: const [], unfavorable: const [],
        mbti: 'ISFJ', ziweiStar: '天機', avoidHour: null,
      );
      expect(advice.contains('避開'), isFalse);
    });
  });
}
```

- [ ] **Step 3: Run test 確認 fail**

```bash
cd "/Users/stephanieau/Desktop/Stephanie-Google Drive/dev/xuanli" && dart test test/engine/copywriter_test.dart
```
Expected: FAIL（`copywriter.dart` 未定義）。

- [ ] **Step 4: 寫實作**

`lib/engine/copywriter.dart`:
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

/// 命理段：日干支 × 用戶喜忌關係。
String _fortuneSegment(AlmanacDay day, List<String> favorable, List<String> unfavorable) {
  final leaning = favorable.isNotEmpty ? '你${favorable.join('')}旺而${unfavorable.join('')}弱' : '';
  return '${day.ganzhiDay}${day.zhiXing}日，$leaning。'.replaceAll('，。', '。');
}

/// MBTI 段：由 mbti_tones.json 攞句，用 dayOfYear % length 輪換（deterministic）。
/// 如果 [mbti] 喺 mbti_tones.json 未有內容（Phase 1 淨係填咗 ISFP/ISFJ 兩型示範），
/// 就返回一句 fallback，唔會 crash——其餘 14 型內容係另外嘅文案工作。
String _mbtiSegment(AlmanacDay day, String mbti) {
  final tones = _loadMbtiTones();
  final lines = tones[mbti];
  if (lines == null || lines.isEmpty) {
    return '$mbti 嘅你，跟住今日嘅節奏行就得。';
  }
  final dayOfYear = int.parse(_dayOfYear(day.date).toString());
  final index = dayOfYear % lines.length;
  return lines[index];
}

int _dayOfYear(DateTime date) {
  return date.difference(DateTime(date.year, 1, 1)).inDays + 1;
}

/// 紫微段：14 主星輕量提示，[ziweiStar] 為 null 就省略呢一段。
String _ziweiSegment(String? ziweiStar) {
  if (ziweiStar == null) return '';
  return '$ziweiStar 坐命嘅你，今日順住個星氣行就啱。';
}

/// 建構今日貼身建議：命理段 + MBTI 段 + 紫微段（可省略）+ 避時提示（可省略）。
/// 全部 deterministic（用 [day.date] 做 dayOfYear seed，唔用 Random/DateTime.now()）。
String buildAdvice({
  required AlmanacDay day,
  required List<String> favorable,
  required List<String> unfavorable,
  required String mbti,
  required String? ziweiStar,
  required String? avoidHour,
}) {
  final segments = <String>[
    _fortuneSegment(day, favorable, unfavorable),
    _mbtiSegment(day, mbti),
  ];
  final ziwei = _ziweiSegment(ziweiStar);
  if (ziwei.isNotEmpty) segments.add(ziwei);
  if (avoidHour != null) segments.add('避開$avoidHour落重要決定。');
  return segments.where((s) => s.isNotEmpty).join('');
}
```

- [ ] **Step 5: Run test 確認 pass**

```bash
cd "/Users/stephanieau/Desktop/Stephanie-Google Drive/dev/xuanli" && dart test test/engine/copywriter_test.dart -r expanded
```
Expected: 全部 PASS。

- [ ] **Step 6: Commit**

```bash
cd "/Users/stephanieau/Desktop/Stephanie-Google Drive/dev/xuanli"
git add lib/data/mbti_tones.json lib/engine/copywriter.dart test/engine/copywriter_test.dart
git commit -m "feat(engine): add copywriter template engine with deterministic rotation"
```

---

## Task 14: 引擎總入口 `f(Profile, DateTime) -> DayReading` + CLI demo

**Files:**
- Create: `lib/engine/day_reading_engine.dart`
- Create: `tool/demo.dart`
- Test: `test/engine/day_reading_engine_test.dart`

呢個 task 將之前所有 engine 拼埋一齊，做返 spec §5 講嘅純函數 `f(Profile, DateTime) -> DayReading`，同 spec §10 Phase 1 驗收要求嘅 CLI demo。

- [ ] **Step 1: 寫 failing test**

`test/engine/day_reading_engine_test.dart`:
```dart
import 'package:test/test.dart';
import 'package:xuanli/engine/bazi.dart';
import 'package:xuanli/engine/day_reading_engine.dart';
import 'package:xuanli/models/profile.dart';

void main() {
  test('buildDayReading(阿玄, 2026-07-11) 產出完整 DayReading', () {
    final bazi = computeBazi(birthDate: DateTime(1999, 9, 20), birthHour: 9, birthMinute: 30);
    final profile = Profile(
      id: 'p1', name: '阿玄', birthDate: DateTime(1999, 9, 20), birthHour: 9,
      birthPlace: '香港', mbti: 'ISFP',
      pillars: bazi.pillars, wuxing: bazi.wuxing,
      favorable: bazi.favorable, unfavorable: bazi.unfavorable,
      dayMaster: bazi.dayMaster, ziweiStar: '太陰', zodiac: '兔',
    );

    final reading = buildDayReading(profile: profile, date: DateTime(2026, 7, 11));

    expect(reading.ganzhiDay, '丙戌');
    expect(reading.lunarLabel, '五月廿七');
    expect(reading.zhiXing, '平');
    expect(reading.fortuneScore, inInclusiveRange(0, 100));
    expect(reading.mbtiScore, inInclusiveRange(0, 100));
    expect(['吉', '平', '忌'], contains(reading.band));
    expect(reading.advice, isNotEmpty);
    expect(reading.yi, isNotEmpty);
  });

  test('deterministic：同 input 行兩次result一樣', () {
    final bazi = computeBazi(birthDate: DateTime(1999, 9, 20), birthHour: 9, birthMinute: 30);
    final profile = Profile(
      id: 'p1', name: '阿玄', birthDate: DateTime(1999, 9, 20), birthHour: 9,
      birthPlace: '香港', mbti: 'ISFP',
      pillars: bazi.pillars, wuxing: bazi.wuxing,
      favorable: bazi.favorable, unfavorable: bazi.unfavorable,
      dayMaster: bazi.dayMaster, ziweiStar: '太陰', zodiac: '兔',
    );
    final r1 = buildDayReading(profile: profile, date: DateTime(2026, 7, 11));
    final r2 = buildDayReading(profile: profile, date: DateTime(2026, 7, 11));
    expect(r1.fortuneScore, r2.fortuneScore);
    expect(r1.advice, r2.advice);
  });
}
```

- [ ] **Step 2: Run test 確認 fail**

```bash
cd "/Users/stephanieau/Desktop/Stephanie-Google Drive/dev/xuanli" && dart test test/engine/day_reading_engine_test.dart
```
Expected: FAIL（`day_reading_engine.dart` 未定義）。

- [ ] **Step 3: 寫實作**

`lib/engine/day_reading_engine.dart`:
```dart
import 'almanac.dart';
import 'copywriter.dart';
import 'scoring.dart';
import '../models/day_reading.dart';
import '../models/profile.dart';

/// 純函數：f(Profile, DateTime) -> DayReading。呢個係 spec §5 講嘅引擎總入口，
/// 淨係拼接返之前嘅 almanac/scoring/copywriter，唔加新邏輯。
DayReading buildDayReading({required Profile profile, required DateTime date}) {
  final day = AlmanacDay.forDate(date);
  final userYearZhi = profile.pillars[0].substring(1);

  final fortune = computeFortuneScore(
    day: day,
    favorable: profile.favorable,
    unfavorable: profile.unfavorable,
    userYearZhi: userYearZhi,
  );

  final mbtiScore = computeMbtiScore(
    day: day,
    mbti: profile.mbti,
    hasClash: fortune.clashWarning != null,
  );

  final userDayZhi = profile.pillars[2].substring(1);
  final avoidHour = computeAvoidHour(userDayZhi);

  final advice = buildAdvice(
    day: day,
    favorable: profile.favorable,
    unfavorable: profile.unfavorable,
    mbti: profile.mbti,
    ziweiStar: profile.ziweiStar,
    avoidHour: avoidHour,
  );

  return DayReading(
    date: date,
    ganzhiDay: day.ganzhiDay,
    lunarLabel: day.lunarLabel,
    zhiXing: day.zhiXing,
    chong: day.chong,
    fortuneScore: fortune.score,
    mbtiScore: mbtiScore,
    band: fortune.band,
    yi: day.personalizedYi(favorable: profile.favorable),
    ji: day.personalizedJi(favorable: profile.favorable),
    advice: advice,
    clashWarning: fortune.clashWarning,
    avoidHour: avoidHour,
  );
}
```

- [ ] **Step 4: Run test 確認 pass**

```bash
cd "/Users/stephanieau/Desktop/Stephanie-Google Drive/dev/xuanli" && dart test test/engine/day_reading_engine_test.dart -r expanded
```
Expected: 全部 PASS。

- [ ] **Step 5: 寫 CLI demo**

`tool/demo.dart`:
```dart
import 'package:xuanli/engine/bazi.dart';
import 'package:xuanli/engine/day_reading_engine.dart';
import 'package:xuanli/engine/ziwei.dart';
import 'package:xuanli/models/profile.dart';

const _zhiToZodiac = {
  '子': '鼠', '丑': '牛', '寅': '虎', '卯': '兔', '辰': '龍', '巳': '蛇',
  '午': '馬', '未': '羊', '申': '猴', '酉': '雞', '戌': '狗', '亥': '豬',
};

/// Usage: dart run tool/demo.dart <YYYY-MM-DD> [HH:MM] <MBTI>
/// 例如：dart run tool/demo.dart 1999-09-20 09:30 ISFP
void main(List<String> args) {
  if (args.length < 2) {
    print('Usage: dart run tool/demo.dart <YYYY-MM-DD> [HH:MM] <MBTI>');
    return;
  }

  final dateParts = args[0].split('-').map(int.parse).toList();
  final birthDate = DateTime(dateParts[0], dateParts[1], dateParts[2]);

  int? birthHour;
  int birthMinute = 0;
  String mbti;
  if (args.length == 3) {
    final timeParts = args[1].split(':').map(int.parse).toList();
    birthHour = timeParts[0];
    birthMinute = timeParts[1];
    mbti = args[2];
  } else {
    mbti = args[1];
  }

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

  final today = DateTime.now();
  final reading = buildDayReading(profile: profile, date: DateTime(today.year, today.month, today.day));

  print('=== 玄曆 Demo ===');
  print('四柱：${bazi.pillars.join(' ')}');
  print('日主：${bazi.dayMaster}　肖：${profile.zodiac}　完整度：${profile.completeness}%');
  print('喜：${bazi.favorable.join('')}　忌：${bazi.unfavorable.join('')}');
  print('---');
  print('${reading.lunarLabel}　${reading.ganzhiDay}　${reading.zhiXing}日　${reading.chong}');
  print('命理分：${reading.fortuneScore}（${reading.band}）　契合度：${reading.mbtiScore}');
  print('宜：${reading.yi.map((e) => e.label).join('、')}');
  print('忌：${reading.ji.map((e) => e.label).join('、')}');
  if (reading.clashWarning != null) print('⚠️ ${reading.clashWarning}');
  print('🔮 ${reading.advice}');
}
```

- [ ] **Step 6: 行 demo 確認可以真係 print 出今日 DayReading**

```bash
cd "/Users/stephanieau/Desktop/Stephanie-Google Drive/dev/xuanli" && dart run tool/demo.dart 1999-09-20 09:30 ISFP
```
Expected: 冇 crash，print 出完整嘅四柱/命理分/宜忌/🔮建議（spec §10 Phase 1 驗收條件之一）。

- [ ] **Step 7: Commit**

```bash
cd "/Users/stephanieau/Desktop/Stephanie-Google Drive/dev/xuanli"
git add lib/engine/day_reading_engine.dart tool/demo.dart test/engine/day_reading_engine_test.dart
git commit -m "feat(engine): wire engine into f(Profile, DateTime) -> DayReading + CLI demo"
```

---

## Task 15: Phase 1 收尾驗收

**Files:**
- Modify: `CLAUDE.md`（Progress 一節）
- Modify: `CHANGELOG.md`（頂部加新條目）

- [ ] **Step 1: 全套 test 行一次，確認全綠**

```bash
cd "/Users/stephanieau/Desktop/Stephanie-Google Drive/dev/xuanli" && dart test test/engine/ -r expanded
```
Expected: 全部 PASS，冇 skip。貼真實 output（唔准用「應該過」呢類斷言）。

- [ ] **Step 2: flutter analyze 檢查冇 lint 錯**

```bash
cd "/Users/stephanieau/Desktop/Stephanie-Google Drive/dev/xuanli" && flutter analyze lib/engine lib/models lib/data 2>&1
```
Expected: `No issues found!` 或者列出嘅 issue 已經逐個處理（唔准帶住 error 級別 issue 收工）。

- [ ] **Step 3: demo CLI 再行一次做手動驗收**

```bash
cd "/Users/stephanieau/Desktop/Stephanie-Google Drive/dev/xuanli" && dart run tool/demo.dart 1999-09-20 09:30 ISFP
```

- [ ] **Step 4: 更新 CLAUDE.md Progress 一節**

喺 `CLAUDE.md` 嘅 `## Progress` 底下，將:
```markdown
- [ ] Phase 1 引擎（TDD，fixtures spec §11）
```
改做:
```markdown
- [x] Phase 1 引擎（TDD，fixtures spec §11；`dart test test/engine/` 全綠，`dart run tool/demo.dart` 可行）
```

- [ ] **Step 5: CHANGELOG.md 頂部加條目**

喺 `CHANGELOG.md` 第 4 行（`---` 分隔線之後）插入新條目（規則：新條目一律插頂，唔准 append 落 CLAUDE.md）：
```markdown
## 2026-07-23 Phase 1 引擎完成（TDD，全綠）

- 裝好 Flutter SDK（`brew install --cask flutter`，之前部 Mac 冇裝過）。
- `lib/engine/` 九個純 Dart 模組全部起好：wuxing_tables／almanac／bazi／scoring／activity／ziwei／copywriter／day_reading_engine，`test/engine/` 全綠，`dart run tool/demo.dart` 可行。
- 範圍決定（已同 Stephanie 確認）：ziwei.dart 全模式同降級模式共用簡化日支對照表，唔做真紫微排盤（v2 先做深度文案）。
- 未完成：`lib/data/mbti_tones.json` 淨係 ISFP/ISFJ 兩型有真實內容，其餘 14 型文案要喺 Phase 2 UI 接之前補齊。
```

- [ ] **Step 6: Commit（呢個 repo 用真 git CLI，唔係 github_push.py——見 CLAUDE.md 例外表）**

```bash
cd "/Users/stephanieau/Desktop/Stephanie-Google Drive/dev/xuanli"
git add CLAUDE.md CHANGELOG.md
git commit -m "docs: mark Phase 1 engine complete, update changelog"
```

- [ ] **Step 7: 提醒 Stephanie 嘅收尾事項（唔使自動做，執行完呢個 plan 之後用文字話低）**

1. `lib/data/mbti_tones.json` 得 2 型有內容，其餘 14 型（INTJ/INTP/ENTJ/ENTP/INFJ/INFP/ENFJ/ENFP/ISTJ/ESTJ/ESFJ/ISTP/ESTP/ESFP）文案未寫，Phase 2 UI 接之前要補（可以自己填，或者叫另一個 session 用 `humanizer-zh` skill 幫手）。
2. Task 9（`personalizedYi`）用 `File()` 相對路徑讀 JSON，Phase 2 起真 Flutter app 之後要改用 `rootBundle.loadString` + `pubspec.yaml` assets 登記，唔係 Phase 1 阻塞。
3. `lunar` package 嘅閏月表示法（`Lunar.fromYmd` 負數月）淨係喺 Task 4 個 test 度驗證過一次，如果掂到閏月邊緣情況要留意。
4. 未 push 上 GitHub（呢個 repo 用真 git CLI + feature branch，Push kit 首次真 push 留咗做「Phase 1 有 code 先驗」，依家啱啱好可以驗）。

---

## Self-Review（已做，摘要）

**Spec coverage**：§6.1（bazi）→ Task 3/4；§6.2（fortuneScore）→ Task 6；§6.3（mbtiScore）→ Task 8；§6.4（avoidHour）→ Task 7；§6.5（宜忌排序）→ Task 9；§7（activity）→ Task 10；§8.1（copywriter 建議）→ Task 13；§8.2（160 combos）→ Task 11；§8.3（MBTI 語氣規則）→ Task 13（loader/邏輯完整，內容缺 14 型，已喺 Task 15 步驟 7 記低）；§11 全部 golden fixtures → Task 2/3/6 逐條覆蓋；§13 紅線（零網絡/唔用Random/唔簡體/唔hardcode單profile）→ 全程冇一個 task 用到 `Random`/`DateTime.now()` 做分數輸入、冇網絡請求、`Profile` 用 list 唔係 hardcode 單例。

**已知缺口（唔係呢份 plan 嘅 bug，係範圍決定）**：ziweiStar 全模式簡化（Task 12，已經同 Stephanie 傾過）；mbti_tones.json 得 2/16 型內容（Task 13，文案工作非工程工作）。
