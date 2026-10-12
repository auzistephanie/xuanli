# Kairo（原名玄曆 XuanLi）— CLAUDE.md

Flutter app：中國傳統擇日 × 八字五行 × 紫微 × MBTI 個人化宜忌。國風復古典雅，全繁體中文（廣東話語感）UI。

## ⚙️ Standards（MANDATORY — 正本：`stephanie-personal/docs/ai-governance/STANDARDS.md`，改規則只改正本）

Push（`github_push.py`，永不 git CLI・HTTPS・一 run 一 commit・**開工前 `--check`**・**收工即推**・三道閘 刪檔／SHA／交叉 review，撞閘唔好即刻 `--force`）・寫入分流（改動記錄 → `CHANGELOG.md` **頂部**；本檔上限 100 行/6KB）・清理 mv `_to_delete/`・方向性決定先 preview（02 §R3）・改完以用家身份 run 一次先報完成・governance 00–06（派工 01 §1＋03 模板；完成前過 02 §R2；冇 mount stephanie-personal 就叫 Stephanie 連埋）。**Codex 讀同層 `AGENTS.md`**。詳文＋例外表 → 正本。
⚠️ 本 repo 係 standards **例外**（真 git CLI＋feature branch＋英文 commit）— 見正本例外表＋下面 Git section。

## 必讀文件（順序）

1. `XUANLI_SPEC.md` — 完整實施規格。**所有產品決策已鎖定（spec 第 2 節），唔好重新討論或自行更改**；發現 spec 有矛盾就停低問 Stephanie，唔好自己拍板。
2. `design/kairo-preview.html` — 視覺語言權威（配色／品牌／3D／動態）；`design/design-preview.html` — 版面同文案語氣參考（未涵蓋嘅畫面照佢）
3. `lib/data/combos.json` — 160 個組合文案（已寫好、已驗證，唔好改內容；只准 bug fix 例如 JSON 讀取問題）

## 工作流程

- 跟 spec 第 10 節四個 Phase 順序做；每個 phase 驗收標準全過先開下一個
- **TDD**：spec 第 11 節有 2026 年 7 月真實通勝 golden fixtures — 先寫 test 後寫 engine
- 用 superpowers planning/TDD skills 拆解每個 phase；大改動前先出 plan 畀 Stephanie 確認
- 完成每個 phase：更新本文件嘅 Progress 一節 + commit

## 常用指令

```bash
dart test test/engine/          # 引擎測試（Phase 1 起必須全綠）
dart run tool/demo.dart 1999-09-20 09:30 ISFP   # 引擎 CLI demo
flutter analyze && flutter test # 全項目檢查
flutter build apk --release     # Android 交付（<40MB）
./scripts/install_ios.sh        # Mac 上 build + 免費簽名裝 iPhone
```

## 鐵律（違反 = 即刻停手修正）

1. **零網絡**：成個 app 唔准有任何網絡請求（連字體都 bundle）。用戶出生資料絕不離機
2. **`lib/engine/` 唔准 import Flutter** — 保持純 Dart 可測試
3. **Deterministic**：分數計算唔准用 `Random` / `DateTime.now()`（日期只可以係 input 參數）
4. **UI 唔准出現簡體字**：`lunar` 回傳簡體，必須經 `almanac.dart` 繁體化表；新增 UI string 要人手檢查
5. **八字子時**：必須 `eightChar.setSect(1)`（晚子時日柱歸翌日）— lunar 預設係錯嘅流派
6. **醫療/投資文案安全線**：睇醫生只講「邊日更順」，永不輸出勸阻就醫；投資唔出具體買賣建議
7. UI 文案語氣跟 design html：親切、典雅、帶少少玄學神秘感，用「你」唔用「您」
8. **內部識別唔改名**：package／bundle ID／App Group／`xuanli://`／prefs key／備份格式／「玄曆識別碼」保留，見 docs/superpowers/specs/2026-10-13-kairo-rebrand-design.md D1

## 架構速記

- 傳統層：`lunar` package（干支/建除/神煞/宜忌/沖煞）→ `almanac.dart` 包裝+繁體化
- 個人化層：`bazi.dart`（四柱/五行/喜用神，演算法 spec §6.1）→ `scoring.dart`（命理分 §6.2 + MBTI 契合度 §6.3，**兩分數互相獨立**）
- 文案：`copywriter.dart` 模板插值（模板輪換用 `dayOfYear % n`，唔用 random）
- 儲存：`shared_preferences`，profiles list 結構（MVP 只用 index 0，唔准 hardcode 單 profile）
- Widget 數據流：app 開啟時預生成未來 7 日 DayReading JSON → `home_widget` → 原生讀

## ✅ 完成前檢查（本 repo 專屬 DoD；通用四格 → 02-JUDGMENT §R2）

1. `dart test test/engine/` 全綠（Phase 1 起必跑）＋`flutter analyze && flutter test` 過，真跑貼 output
2. UI 有改 → 肉眼查冇簡體字＋文案語氣對照 `design/design-preview.html`
3. 每 phase 對照 spec §10 驗收標準全過先開下一個；完成 phase → 更新 Progress＋commit

## Progress

- [x] 規格 + 設計稿 + combos.json（Cowork）
- [x] Phase 1 引擎（TDD，fixtures spec §11；`dart test test/engine/` 全綠，`dart run tool/demo.dart` 可行）
- [ ] Phase 2 App UI（功能齊，見 CHANGELOG＋spec §2 決定 12–15；PR #1 2026-10-12 merge）。**真機驗收未做**（冷啟動 <2s、離線、權限 dialog、分享、震動），docs/pr-1-review-checklist.md §A 係清單
- [x] interim web 部署 → https://xuanli-opal.vercel.app（**唔算** Phase 3/4；`vercel.json` 已停 git 自動部署，更新要 `flutter build web` 後喺 `build/web` 行 `vercel deploy --prod`）
- [ ] Phase 3 Widget＋通知：數據橋、通知、冷啟動 deep link 已做；Android／iOS 小+中 widget 原生碼已寫（Kotlin 編譯＋邏輯測試、Swift typecheck 過），**未經 Gradle／Xcode／真機**；iOS 要喺有 Xcode 嘅機行 `ruby scripts/add_ios_widget_target.rb`（未套用）；已開 app 時撳 widget 唔跳（router 只處理冷啟動）
- [x] Kairo 改名＋3D／動態（2026-10-13，feat/kairo-rebrand）——**真機未驗**：陀螺儀傾斜手感、搖手機抽籤、震動、APK 大小
- [ ] Phase 4 交付（APK + install_ios.sh）——開發機冇 Android SDK／Xcode，未開始

## Git

- 分支：`main` 保持可 build；每個 phase 一個 feature branch
- Commit message 用英文、細粒度；phase 完成先 merge
- 唔好 commit：`build/`、`.dart_tool/`、`.env`、`.gh-token`、任何含出生資料嘅測試 dump

### Push kit（2026-07-18 已裝）

`scripts/github_push.py`＋`.env` token＋registry 行三樣齊（正本 `stephanie-personal/docs/PUSH-SETUP.md`）。首次真 push 留 Phase 1 有 code 先跑（`python3 scripts/github_push.py "<msg>"` 見 ✅ 先算通）。
