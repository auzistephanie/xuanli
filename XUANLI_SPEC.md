# 玄曆 XuanLi — 實施規格書（畀 Claude Code + Superpowers 用）

> **點用呢份文件**：呢份係已經傾掂、鎖定晒決策嘅實施規格，唔使再 brainstorm 產品方向。
> 建議流程：用 superpowers 嘅 planning skill 將本文件拆成 implementation plan（跟第 10 節四個 Phase），
> 然後逐 phase 用 TDD 實作 — 第 11 節有真實通勝數據 fixtures，**先寫 test 後寫 engine**。
> 所有 UI 以 repo 內 `design/design-preview.html` 為準（開瀏覽器睇，係最終視覺 spec）。
> 語言：所有 UI 文案繁體中文（廣東話語感）；code comment 英文。

---

## 1. 產品一句話

中國傳統擇日（通勝黃曆）× 個人八字五行 × 紫微 × MBTI：話畀用戶知「今日／邊一日最適合做某件事」，同一日對唔同人有唔同推薦。國風復古典雅，係「有文化感嘅生活工具」，唔係迷信 app。

## 2. 已鎖定決策（唔好重新討論）

| # | 決策 | 內容 |
|---|------|------|
| 1 | 發佈 | 自用/朋友試玩：Android APK 直裝 + iOS 用 Mac Xcode 免費簽名裝機（唔上 store、唔使 TestFlight） |
| 2 | 技術棧 | Flutter（stable channel）+ `home_widget` |
| 3 | 引擎 | 100% 離線。傳統層用 pub.dev `lunar` package（6tail）；個人化層自寫。零 server、出生資料不離機 |
| 4 | 缺時辰 | 出生時辰可選。唔知 → 三柱降級模式（UI 標「簡易版」+ 檔案完整度 80%），紫微改用日柱輕量文案 |
| 5 | 雙分數 | 「命理分」（純命理）+「狀態契合度」（MBTI×當日）**雙環並列**。小 widget / 7日條 / 月曆顏色一律用命理分 |
| 6 | 通知 | `flutter_local_notifications` 每朝推一句（預設 07:30，可改可關），全本地排定 |
| 7 | 資料 | 免註冊、全本地（`shared_preferences` + JSON）。數據結構用 profiles list，MVP 只用 index 0 |
| 8 | 敏感活動 | 「睇醫生」「求財投資」保留但文案安全線：睇醫生只講「邊日更順」永不輸出「唔好睇醫生」；投資只講宜唔講具體行動。全 app 有「僅供參考・不代替專業意見」聲明（onboarding 尾 + 設定頁） |
| 9 | iOS 交付 | 出一個 `scripts/install_ios.sh`：喺 Mac 上 flutter build + xcodebuild 免費簽名裝落實機 |
| 10 | 日曆 | `device_calendar` package 讀寫部機日曆（自動涵蓋已同步嘅 Google Calendar）。讀：月曆格行程幼條 + 日卡行程列表；寫：Tab B「加入我嘅日曆」。**唔做** Google OAuth（第二版） |
| 11 | 組合頁 | 八字×MBTI 組合詳解頁入 MVP：10 日主 × 16 MBTI = 160 模板，由檔案卡撳入 |

**第二版先做（唔好實作，但唔好寫死唔容許擴展）**：分享卡、稀有度%、紫微深度文案、多人檔案切換 UI、真太陽時、Google OAuth。

## 3. 技術棧同 packages

```yaml
# pubspec.yaml 核心依賴（用最新 stable 版本）
dependencies:
  lunar: ^1.x            # 6tail 農曆/八字/建除/神煞/宜忌
  home_widget: ^0.x      # iOS WidgetKit + Android AppWidget 數據橋
  flutter_local_notifications: ^17.x
  device_calendar: ^4.x  # 讀寫部機日曆
  shared_preferences: ^2.x
  google_fonts: ^6.x     # Noto Serif TC + Noto Sans TC（或直接 bundle 字體檔）
  intl: ^0.x
```

- 字體要 bundle 落 app（assets），唔好 runtime 下載 — app 要完全離線行到。
- 最低支援：iOS 15+、Android 8 (API 26)+。
- Widget 原生部分：iOS SwiftUI (WidgetKit extension)、Android Kotlin (AppWidgetProvider + RemoteViews)。

## 4. Repo 結構

```
xuanli/
├── XUANLI_SPEC.md            # 本文件
├── design/design-preview.html # 視覺 spec（最終權威）
├── lib/
│   ├── engine/               # 純 Dart，零 Flutter 依賴（方便 test）
│   │   ├── bazi.dart         # 八字、五行分佈、喜用神
│   │   ├── almanac.dart      # lunar 包裝：建除/神煞/宜忌/沖煞（繁體化）
│   │   ├── scoring.dart      # 命理分 + 契合度（見第 6 節）
│   │   ├── activity.dart     # 反向擇日（見第 7 節）
│   │   ├── ziwei.dart        # 紫微命宮主星（模板文案版）
│   │   └── copywriter.dart   # 文案模板引擎（見第 8 節）
│   ├── models/               # Profile, DayReading, ActivityRec…
│   ├── data/                 # 模板 JSON：160 組合、MBTI 語氣、活動表
│   ├── screens/              # onboarding/, today/, activity/, calendar/, combo/, settings/
│   ├── widgets/              # 共用 UI 元件（ring, yj_card, seal…）
│   └── services/             # storage, notifications, calendar_sync, widget_bridge
├── ios/XuanLiWidget/         # WidgetKit extension (SwiftUI)
├── android/…/widget/         # AppWidgetProvider (Kotlin)
├── test/engine/              # 引擎 unit tests（第 11 節 fixtures）
└── scripts/install_ios.sh
```

**規則**：`lib/engine/` 唔准 import Flutter — 令佢可以喺純 Dart VM 跑 test。

## 5. 數據模型

```dart
class Profile {
  String id;
  String name;              // 預設「我」
  DateTime birthDate;       // 公曆存底（農曆輸入要即場轉公曆再存）
  int? birthHour;           // 0-23；null = 唔知時辰（降級模式）
  String birthPlace;        // 顯示用，MVP 唔做時區修正
  String mbti;              // "ISFP"
  // 以下由 engine 計出、存 cache：
  List<String> pillars;     // ["己卯","癸酉","乙亥","辛巳"]（缺時辰得 3 個）
  Map<String,int> wuxing;   // {"木":30,"火":14,"土":13,"金":15,"水":28} 百分比
  List<String> favorable;   // 喜用神 ["水","木"]
  List<String> unfavorable; // 忌神 ["金","土"]
  String dayMaster;         // "乙木"
  String ziweiStar;         // "太陰"；降級模式 = 由日支對應嘅簡化星
  String zodiac;            // 生肖 "兔"
}
// 儲存：profiles: [Profile]，MVP 用 profiles[0]。JSON 匯出/匯入即係成個 profiles + settings dump。
```

```dart
class DayReading {           // 每日一個，engine 純函數產出：f(Profile, DateTime) -> DayReading
  DateTime date;
  String ganzhiDay;          // "丙戌"
  String lunarLabel;         // "五月廿七"
  String zhiXing;            // 建除："平"
  String chong;              // "沖龍煞北"
  int fortuneScore;          // 命理分 0-100
  int mbtiScore;             // 契合度 0-100
  String band;               // "吉"|"平"|"忌"（由 fortuneScore 分帶）
  List<YjItem> yi, ji;       // 個人化排序宜忌，YjItem{label, matchesUser:bool}
  String advice;             // 一句貼身建議（copywriter 產出）
  String? clashWarning;      // 沖用戶生肖先有："今日沖你生肖"
  String? avoidHour;         // "申時 15–17"（見 6.4）
}
```

## 6. 演算法規格（engine 核心，全部 deterministic — 唔准用 Random）

### 6.1 八字同五行（bazi.dart）
- 用 `lunar` 攞四柱干支（`getEightChar()`）。**子時界線（重要）**：本 app 採用「晚子時日柱歸翌日」流派 — lunar **預設係流派 2（歸當日），必須顯式 `eightChar.setSect(1)`**。Test：2026-07-11 23:30 → 日柱必須係 丁亥（唔係丙戌）。
- 五行分佈：四柱八字（缺時辰＝六字）每個天干地支計五行，地支用**本氣**（寅→木、子→水…），加權：月支 ×2（月令最重），其餘 ×1。輸出百分比（四捨五入，總和調整至 100）。
- **喜用神（扶抑法，MVP 唯一方法）**：
  - 同黨 = 生日主 + 同日主嘅五行權重和；異黨 = 其餘三行。
  - 同黨 ≥ 45% → 身強：喜 = 剋日主、日主所生（官殺+食傷）兩行；忌 = 生日主、同日主。
  - 同黨 < 45% → 身弱：喜 = 生日主、同日主（印+比劫）；忌 = 剋日主、日主所剋入面權重最高兩行。
  - 輸出固定 2 喜 2 忌（同分時按 木火土金水 序取先）。
- 農曆輸入：UI 收農曆年月日（+閏月 flag），用 `Lunar.fromYmd` 轉公曆存底。

### 6.2 命理分（scoring.dart）
```
base（建除十二神）：建55 除65 滿55 平50 定65 執55 破20 危50 成70 收50 開65 閉35
+ 吉神：每個 +3，上限 +12          （lunar getDayJiShen）
- 凶煞：每個 -4，下限 -16          （lunar getDayXiongSha）
+ 五行：日干五行 ∈ 喜 → +8；∈ 忌 → -8；日支本氣五行同樣 ±8
- 沖生肖：日支沖用戶年支 → -20（另設 clashWarning）
特別規則：通勝「忌：諸事不宜」→ 分數封頂 40；「宜：諸事不宜/餘事勿取」唔加分
clamp 0-100
分帶：≥70 吉 ｜ 40–69 平 ｜ ≤39 忌
```

### 6.3 狀態契合度（MBTI 分，同命理完全獨立）
對每個 MBTI 軸，用當日客觀特徵計 0-25 分，四軸相加：
- **E/I**：日之「動靜」— 建除屬動（建除危成開）對 E 高分、屬靜（平定收閉破執滿）對 I 高分。
- **S/N**：宜忌清單具體度 — 宜項多而具體（≥6 項）利 S；「諸事不宜/餘事勿取」呢類抽象日利 N。
- **T/F**：吉神多（≥3）→ 人和日利 F；凶煞多 → 需冷靜判斷利 T。
- **J/P**：無沖無破（穩定日）利 J；沖/破/危（變動日）利 P。
每軸命中 25 分、半命中 15、不命中 8（具體 mapping 寫成 const table，test 鎖住）。

### 6.4 避開時辰
當日十二時辰入面，搵地支沖用戶日支嘅時辰 → `avoidHour`（例：用戶日支寅，申時沖寅 → 「申時 15–17」）。冇就 null。

### 6.5 宜忌個人化排序
- `lunar` 宜/忌 items（簡體）→ 內建對照表轉繁體 + 口語化（"理发"→"剪髮/理髮"、"馀事勿取"→"餘事勿取"）。
- 每個 item 屬一個活動類別（見第 7 節表），類別五行 ∈ 用戶喜 → `matchesUser=true`，排前面（UI 顯示 ✦ 合你）。
- 宜取頭 3–5、忌取頭 2–4 顯示。

## 7. 反向擇日（activity.dart）

活動表（`data/activities.json`），MVP 14 個 chips：

| 活動 | 通勝關鍵字（命中 +25） | 有利建除 | 五行親和 | 忌關鍵字（命中即淘汰） |
|------|----------------------|---------|---------|---------------------|
| 剪髮 | 理髮 | 除、執 | 木 | 理髮（喺忌列） |
| 搬屋 | 移徙、入宅 | 定、成、開 | 土 | 移徙、入宅 |
| 簽約 | 立券、交易、訂盟 | 定、成 | 金 | 立券、交易 |
| 開業 | 開市、開業 | 開、成 | 火 | 開市 |
| 求財投資 | 納財、開市、交易 | 成、開、收 | 金 | 納財 |
| 表白約會 | 嫁娶、納采、會親友 | 定、成、開 | 火 | 嫁娶 |
| 睇醫生 | 求醫、治病 | 除、破(治病例外吉) | 水 | —（唔設忌，只排序） |
| 出遊 | 出行 | 開、建 | 火 | 出行 |
| 裝修動土 | 修造、動土 | 建、定 | 土 | 動土、修造 |
| 買車 | 納財、交車 | 滿、成 | 金 | 納財 |
| 面試 | 求職、出行、會親友 | 成、開 | 火 | — |
| 考試 | 入學、求學 | 成、開 | 水 | — |
| 擺酒 | 嫁娶、開市、會親友 | 定、成 | 火 | 嫁娶 |
| 拜神 | 祭祀、祈福 | 除、定、開 | 土 | 祭祀、祈福 |

**評分** = 活動分（關鍵字+建除命中）40% + 該日命理分 40% + 活動五行∈用戶喜用神 20%。
範圍（1週/1月/3月）內排序取頭 5，星級 = 分數五等分。每個結果經 copywriter 產生🔮原因。
**安全線**：「睇醫生」永遠出結果（正面排序），唔會話邊日「唔好睇」。

## 8. 文案引擎（copywriter.dart + data/*.json）

全部模板 + 變數插值，**唔用 LLM、唔用網絡**：

1. **今日貼身建議**（Tab A / 大 widget / 通知）拼三段：
   `[命理段：日干支×用戶喜忌關係] + [MBTI 段：16 型各有語氣模板庫，每型 ≥6 句按 date hash 輪換] + [紫微段：14 主星輕量提示，可省略]`
   例：「丙戌平日，宜靜不宜動。你水木旺而火土弱，今日戌土偏燥，正好安定心神——ISFP 嘅你適合執靚一角，大計留返聽日。避開申時（15–17）落重要決定。」
   輪換用 `dayOfYear % templates.length` — 保證 deterministic。
2. **160 組合模板**（`lib/data/combos.json`）：**已寫好、已驗證，直接用，唔准重寫或改內容**。key = `日主天干_MBTI`（如 `乙_ISFP`），欄位：`name`（四字組合名）、`motto`（4字・4字）、`description`（80–130 字）、`strengths[3]`、`watchouts[3]`、`howToWin`（60–110 字，已包含五行日子建議+MBTI 發力方式）。紫微段由 copywriter 另外拼接（唔喺 combo 模板入面，因為紫微主星係 per-user）。工程上只需寫 loader + model class + 一個 test 驗證 160 keys 齊全。
3. **MBTI 語氣規則**：I 型建議獨處類行動、E 型社交類；F 型講感受、T 型講策略；廣東話自然語感，避免「您」，用「你」。

## 9. 各功能規格（UI 全跟 design-preview.html）

### 9.1 Onboarding（3 步）
① 出生資料：新曆/農曆 segmented switch、日期/時間 picker（時辰顯示中文時辰名）、「我唔清楚出生時間」toggle、地點（純文字，預設香港）→ ② MBTI：「我知我嘅類型」16 宮格 或 8 題快測（每軸 2 題，A/B 選項，即場計型）→ ③ 命理檔案卡（藏藍卡：頭像縮寫、MBTI 金 chip、五行橫條、喜用/忌神/紫微、流年+沖太歲提示、完整度%）→「開始睇今日」。尾部「僅供參考」聲明。

### 9.2 Tab A 今日宜忌
日期 header（公曆+農曆+干支+沖煞）、雙環卡（命理分金環 + 契合度玉綠環）、宜/忌兩欄（✦合你 標記）、🔮貼身建議卡、未來 7 日條（撳跳去該日）。

### 9.3 Tab B 我想做…
Chips（可橫向 scroll）→ 範圍 segmented（1週/1月/3月）→ 結果卡（日期+星級+農曆行+🔮原因+「＋加入我嘅日曆」+「當日已有 N 個行程」）。底部細字顯示「已為你避開 XX」增加信任感。

### 9.4 Tab C 月曆
月 grid（吉玉綠/忌朱紅/平淡墨圓點；有行程 = 藏藍幼條；今日金框）、swipe/箭咀轉月、撳日展開日卡（同 Tab A 格式 + 📅 當日行程列表）。範圍支援 1900–2100（lunar 上限）。

### 9.5 組合詳解頁
由檔案卡撳入。組合名大字 + motto + description + 優勢/留意位兩欄 + 點樣發力 + 稀有度佔位（顯示「即將推出」）。

### 9.6 Widget（小/中，MVP 唔做大）
- 數據流：app 每次打開 + 每朝通知觸發時，用 `home_widget` 寫入未來 7 日 `DayReading` JSON → 原生 widget 讀 JSON render。iOS 用 timeline entries（每日 00:00 + 07:00 兩個 entry）；Android 用 `AlarmManager` 每朝 07:00 + 子夜 update。
- 小：命理分環 + 一個字（吉/平/忌）。中：日期農曆 + 環 + 宜3忌2 + 避時提示。
- 深色模式：跟系統，配色見 design html。撳 widget → deep link `xuanli://day/2026-07-11`。
- **App 7 日冇開嘅 fallback**：widget 顯示最後一日數據 + 「開 app 更新」細字。

### 9.7 通知
每朝（預設 07:30）：「今日丙戌日・命理分 42・宜祈福靜修，忌簽約。避開申時落大決定。」內容 = copywriter 短版。用 `zonedSchedule` 預排未來 7 日，app 每次打開 refresh。

### 9.8 設定頁
通知時間/開關、深色模式（跟系統/常開/常關）、JSON 匯出（share sheet）/匯入、重新做 onboarding、免責聲明全文、關於。

### 9.9 日曆整合（services/calendar_sync.dart）
- 首次入 Tab C 先問權限；拒絕 → 月曆照用，行程功能靜默隱藏（唔好嘈）。
- 讀：當月 events → 格仔幼條 + 日卡列表（時間+標題，最多 5 項）。
- 寫：Tab B 加入日曆 → 建全日 event，標題「✂ 剪髮（玄曆吉日）」，description 放🔮原因。

## 10. 實施 Phases（每個 phase 完成要 demo 到 + tests 全綠先落下一個）

### Phase 1 — 引擎（純 Dart，TDD）
- [ ] almanac.dart 包裝 lunar + 繁體化表
- [ ] bazi.dart：四柱/五行/喜用神（含缺時辰降級、農曆輸入、子時界線）
- [ ] scoring.dart：命理分 + 契合度 + 避時
- [ ] activity.dart + copywriter.dart + combos.json loader（JSON 已提供，唔使寫內容）
- [ ] **驗收**：第 11 節 fixtures 全過；`dart test` 全綠；寫個 CLI demo（`dart run tool/demo.dart 1995-03-21 ISFP`）print 到今日 DayReading

### Phase 2 — App UI
- [ ] Onboarding 三步 + 檔案卡 + 組合頁
- [ ] Tab A/B/C 全功能（含日曆讀寫）
- [ ] 設定頁 + JSON 匯出入 + 深色模式
- [ ] **驗收**：對照 design/design-preview.html 逐屏 screenshot 比對；冷啟動 <2s；離線（飛行模式）全功能正常

### Phase 3 — Widget + 通知
- [ ] home_widget 橋 + iOS WidgetKit（小/中）+ Android AppWidget（小/中）
- [ ] 每朝通知 + 7 日預排
- [ ] **驗收**：改機時測試子夜轉日；深色切換；撳 widget deep link 落正確日

### Phase 4 — 交付
- [ ] `flutter build apk --release`（output 要 <40MB）
- [ ] scripts/install_ios.sh（檢查 Xcode → flutter build ios → 免費簽名裝實機，附 README 一步步）
- [ ] **驗收**：APK 真機裝到行到；iOS script 喺乾淨 Mac 環境行到

## 11. 引擎測試 Fixtures（真實通勝數據，2026 年 7 月，經 lunar-javascript 驗證）

以下係 golden data，engine 輸出必須完全一致（`test/engine/almanac_test.dart`）：

| 公曆 | 農曆 | 日干支 | 建除 | 沖煞 | 宜（節錄） | 忌（節錄） |
|------|------|--------|------|------|-----------|-----------|
| 2026-07-11 | 五月廿七 | 丙戌 | 平 | 沖龍煞北 | 祭祀、解除、餘事勿取 | 諸事不宜 |
| 2026-07-12 | 五月廿八 | 丁亥 | 定 | 沖蛇煞西 | 祭祀、祈福、求嗣、開光、入宅 | 嫁娶、栽種、理髮、作灶 |
| 2026-07-13 | 五月廿九 | 戊子 | 執 | 沖馬煞南 | 解除、祭祀、理髮、安葬 | 嫁娶、開市、作灶 |
| 2026-07-14 | 六月初一 | 己丑 | 破 | 沖羊煞東 | 破屋、壞垣、餘事勿取 | 諸事不宜 |
| 2026-07-15 | 六月初二 | 庚寅 | 危 | 沖猴煞北 | 開市、交易、立券、納財、動土 | 入宅、移徙、作灶、祭祀 |
| 2026-07-16 | 六月初三 | 辛卯 | 成 | 沖雞煞西 | 嫁娶、納采、訂盟、祭祀、祈福 | 掘井、伐木、納畜 |
| 2026-07-17 | 六月初四 | 壬辰 | 收 | 沖狗煞南 | 祭祀、冠笄、作灶、交易、納財 | 開渠、造船、安床、安葬 |

另須 test：
- 2026 年係丙午年、7 月中係乙未月；2026-07-14 係六月初一（月界）。
- 子時界線：2026-07-11 23:30 出生 → 日柱丁亥（sect 1；用 lunar 預設會錯出丙戌）。
- 示範用戶「阿玄」（**1999-09-20 09:30 香港**，ISFP）：四柱 己卯 癸酉 乙亥 辛巳；日主乙木、肖兔；按 6.1 權重（月支×2）：木2 火1 土1 金3 水2 → 同黨（木+水）44% < 45% → 身弱 → 喜水木、忌金土。呢個係 6.1 演算法嘅 end-to-end golden test。
- Scoring smoke tests：2026-07-14（破日+諸事不宜）分數必須 ≤40 帶「忌」；2026-07-16 對喜木用戶必須 ≥70 帶「吉」；同 input 行 100 次結果 identical（deterministic）。
- 沖生肖：肖龍用戶喺 2026-07-11（沖龍）要有 clashWarning 且 -20。

## 12. 設計 tokens（詳見 design html）

```
paper #f6efe2 / paper2 #efe5d0 / ink #1c2440 / red #b23a3a / gold #c9a24b / jade #3f7d6e
dark: bg #131829 / card #1c2440 / paper-text #e9dfc9
字體：Noto Serif TC（標題/數字/干支）+ Noto Sans TC（正文）
圓角：卡 16 / 格 9 / widget 28；印章 logo：朱紅底米黃「玄曆」直排
```

## 13. 紅線（唔准做）

- 唔准將出生資料、任何用戶數據send上網（whole app 零網絡請求，字體都要 bundle）
- 唔准輸出「唔好睇醫生/延遲就醫」類文案；投資唔准出具體買賣建議
- 唔准用 Random / DateTime.now() 影響分數計算（時間只可以做「今日係邊日」嘅 input）
- 唔准簡體字出現喺 UI（lunar 回傳係簡體，必須經繁體化表）
- 唔准 hardcode 單一 profile（要行 profiles[0] 架構）
