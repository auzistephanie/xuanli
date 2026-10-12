# Kairo 改名 × 3D／動態 — Design

> 2026-10-13・Stephanie 已拍板：方向 C「東方神秘 × 現代 3D」、名 **Kairo**、icon **A（天體儀 K）**。
> 視覺參考：`design/kairo-preview.html`（4 個畫面＋icon＋改／保留清單）。

## 1. 目標

- 用家睇到嘅品牌由「玄曆」改做 **Kairo**（副名／印章「吉時」）。
- 加強 3D 感、圖像感、動態：天體儀、立體籤筒、全息傾斜卡、星空、翻卡、過場。
- **唔郁**：引擎（`lib/engine/`）、分數、宜忌、`combos.json` 文案、籤詩、合盤邏輯。

## 2. 鎖定決定

| # | 決定 |
|---|---|
| D1 | 只改**用家睇到**嘅名。內部識別保留 `xuanli`：Dart package、`XuanLi*` class、bundle ID／applicationId `com.xuanli.xuanli`、App Group、URL scheme `xuanli://`、SharedPreferences key、備份 JSON 格式、Vercel 網址。原因：改咗會令已裝 app／widget／備份斷線。 |
| D2 | 品牌字串集中喺 `lib/theme/brand.dart`（`kBrandName = 'Kairo'`、`kBrandSeal = '吉時'`、`kBrandSealShort = '吉'`）。UI 文案改寫例：「匯出 Kairo 資料」「關於 Kairo」「（Kairo 吉日）」。 |
| D3 | Wordmark 字體：Cormorant Garamond SemiBold（OFL），只 bundle 拉丁字 subset 入 `assets/fonts/`，零網絡。 |
| D4 | 深色主題換成夜空色：bg `#0D1120`、bg2 `#141A2E`、card `#1C2440`、金 `#C9A24B`／亮金 `#F0D78C`、玉 `#6FC3AD`、文字 `#E9DFC9`。淺色主題保留米黃紙，加金色＋天體儀。**新用戶預設深色**；已存設定唔改。 |
| D5 | 3D 一律用 Flutter 自己畫（`CustomPainter`＋`Matrix4` perspective）。唔用 3D 引擎、唔用 WebView、唔加 3D model 檔。主要 bitmap 只得 app icon，由 Flutter 畫出嚟再 export PNG，所以 icon 同 app 內天體儀一致。 |
| D6 | 新依賴只加 `sensors_plus`（陀螺儀傾斜＋搖手機抽籤，本機感應器，冇網絡）。冇感應器（web／桌面）就用手指／滑鼠拖動代替。 |
| D7 | 所有動畫尊重 `MediaQuery.disableAnimations`（減少動態效果）：靜止畫面、撳一下即出結果（沿用現有做法）。 |
| D8 | 星空等裝飾位置用固定公式計（唔用 `Random`），每次 render 一樣，golden／test 穩定。 |
| D9 | 分享卡（PNG）只換品牌（印章＋Kairo＋頁腳），版面唔改；PNG 係靜態，冇傾斜效果。 |
| D10 | 原生 widget（Android／iOS）：改顯示名同深色配色；版面唔改。 |

## 3. 元件

| 元件 | 檔案 | 職責 |
|---|---|---|
| Brand | `lib/theme/brand.dart` | 品牌字串常數 |
| BrandSeal／Wordmark | `lib/widgets/brand.dart` | 朱紅「吉」／「吉時」印章、金色漸變 Kairo 字 |
| Starfield | `lib/widgets/starfield.dart` | 閃爍星點背景（固定公式位置） |
| Orrery | `lib/widgets/orrery.dart` ＋ 純函數 `lib/widgets/orrery_geometry.dart` | 天體儀：3 個傾斜軌道環＋2 粒行星＋中心球（可放分數）；投影數學抽純函數方便測試 |
| TiltCard | `lib/widgets/tilt_card.dart` ＋ `tilt_math.dart` | 傾斜（感應器／拖動）＋全息反光；角度計算抽純函數 |
| WuxingOrbs | `lib/widgets/wuxing_orbs.dart` | 五行晶球列 |
| ShakeDetector | `lib/services/shake_detector.dart` | 純 Dart 搖動偵測 |
| StickCylinder 3D | `lib/widgets/stick_cylinder.dart`（改寫） | 立體籤筒、搖動、一支籤彈出 |
| FlipReveal | `lib/widgets/flip_reveal.dart` | 背面→正面 3D 翻卡 |
| 過場 | `lib/theme/page_transitions.dart` | 淡入＋輕微放大，取代預設 slide |
| Icon 渲染 | `tool/render_icon_test.dart`（手動 `flutter test --update-goldens` 跑） | 用 Orrery 畫 icon A → `assets/icon/*.png` |

## 4. 落點

- **開機**：`_AppBootstrap` loading 由轉圈改為 Orrery＋Kairo 字淡入（唔可以拖慢冷啟動：純畫圖、冇 asset 載入）。
- **封面 WelcomeStep**：Starfield＋Orrery hero＋Kairo／吉時。
- **今日**：header 換 BrandSeal＋Kairo；分數區改為 Orrery，中心球顯示命理分，右下細環顯示狀態契合度（雙分數並列規則不變）；7 日條加輕微立體傾斜，今日格浮起。
- **每日一籤**：3D 籤筒；搖手機或撳掣都得；震動；籤彈出後 FlipReveal 翻出籤卡。
- **組合頁**：組合名卡包 TiltCard；五行改晶球（漸變球體，大細跟比例）。
- **其他畫面**：只換品牌字＋深色配色，版面唔改。

## 5. 驗收

1. `dart test test/engine/` 全綠、`flutter analyze` 0 issue、`flutter test` 全綠。
2. `lib/` UI 字串冇「玄曆」（test 鎖死；code comment 唔計）。
3. 每個新 widget：360×640 唔 overflow；減少動態效果時靜止；有 widget test。
4. `flutter build web --release` 成功；新增 asset 合共 < 1MB。
5. 真字體 render 截圖肉眼查：冇簡體字、冇方格字。
6. **未能喺本機驗證**（冇 Android SDK／Xcode）：APK 大小、真機冷啟動、陀螺儀手感、震動 —— 列入 Phase 4 真機清單。

## 6. 唔做

- 改 bundle ID、URL scheme、Vercel 網址、備份格式。
- 3D model 檔、3D 引擎、WebView。
- 改引擎、分數、文案內容。
- 重畫 onboarding／月曆／我想做嘅版面（只換配色同品牌）。
