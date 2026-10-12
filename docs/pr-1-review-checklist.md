# PR #1 Review 清單

`feat/phase2-backup-and-launch-prep` → `main`｜12 個 commit｜143 檔｜+7258／−440

> **建議逐個 commit 睇**（`git log --reverse main..HEAD`），唔好一次睇晒個 diff。
> 自動化檢查（本機）：`flutter analyze` 0 issue；`flutter test` 311／311；`dart test test/engine/` 全過。
> 冇 CI。**真機驗收未做**——呢個 PR 唔應該 merge，直至 §A 全部剔晒。

---

## A. Merge 前一定要做（真機／真 build）

呢部開發機冇 Xcode、Android SDK，以下全部**未驗證**：

- [ ] `flutter build apk --release` 成功，APK < 40MB（spec Phase 4）
- [ ] iOS 用 Xcode build 成功；冷啟動 < 2 秒；飛行模式全功能正常（spec Phase 2 驗收）
- [ ] **Widget（Android）**：Gradle 真 build 過；加小／中 widget；撳 widget 跳去當日；改機時過子夜自動轉日；深色切換
- [ ] **Widget（iOS）**：喺有 Xcode 嘅機行 `ruby scripts/add_ios_widget_target.rb`，揀 Signing Team，build 成功；免費 Apple ID 係咪用得 App Group 未知
- [ ] 通知：Android 通知小圖示（`ic_stat_xuanli`）正常顯示，唔係白方塊；通知真係喺設定時間響
- [ ] 分享：組合卡／合盤卡／籤卡嘅系統 share sheet 正常（iPad 要有 popover 位置）
- [ ] 日曆權限 dialog、加入日曆、JSON 匯出入嘅原生 share／file picker
- [ ] 搖籤／揭曉動畫嘅震動手感，低階機有冇掉幀
- [ ] 已知限制：app 已開緊嗰陣撳 widget，deep link 唔會跳（`DeepLinkRouter` 只處理冷啟動）

---

## B. 逐個 commit

### 1. `1246387` 備份、日曆權限、農曆輸入修正（33 檔）
- [ ] 農曆輸入先轉公曆再建 profile（`BirthDataState.toSolarDate`）；閏月、不存在日期（例如二月三十）有擋
- [ ] JSON 備份：版本化、嚴格驗證、覆蓋前確認；任何失敗保留舊資料（`storage_service.replaceWithBackup` 有 rollback）
- [ ] iOS `NSCalendars*UsageDescription`、Android `READ/WRITE_CALENDAR` 已宣告
- [ ] 加入日曆用穩定識別碼防重複；進行中鎖住按鈕
- [ ] 順手夾咗治理檔案（`AGENTS.md`、`CLAUDE.md`、`scripts/github_push.py`、`.gitignore`）——**同功能無關，可考慮拆出去**

### 2. `5af3571` Icon、名稱、字體、Vercel（64 檔，大部分係生成圖）
- [ ] 圖示：紅印章；iOS／Android adaptive／monochrome／web 都有
- [ ] App 名「玄曆」（Android label、iOS display name）
- [ ] **字體 subset 28.8MB → 8.3MB**：只保留 Big5 常用字＋repo 內出現過嘅字；罕見字會 fallback 去系統字體——確認 UI 冇明顯缺字
- [ ] `vercel.json` 停咗 git 自動部署（原因：repo 根目錄冇 `index.html`，每次 push 都會令 production 變 404）
- [ ] `analysis_options.yaml` 排除 `_to_delete/`、`build/`
- [ ] `flutter_launcher_icons` 係新 dev dependency；注意佢曾經將 `ios/Runner.xcodeproj` 嘅 `ASSETCATALOG_COMPILER_GENERATE_SWIFT_ASSET_SYMBOL_EXTENSIONS` 錯寫成 `AppIcon`，**已還原，唔喺 commit 入面**

### 3. `225169a` 分享卡
- [ ] 卡上**冇姓名、出生資料**（有 test）
- [ ] 本機 `RepaintBoundary` 截 1080×1920 PNG，唔經網絡

### 4. `64d8689` 稀有度
- [ ] 算法：日主各 1/10 × MBTI 人口比例（Myers-Briggs 基金會**美國樣本**，歸一化）——**確認文案一律寫「估算」、冇寫「全港」**
- [ ] 數據來源（`rarity.dart` 入面 16 個數字）有冇問題

### 5. `b5ba7db` 組合頁符號改畫形狀
- [ ] `◈ ☾ ⇪` 唔係 bundled 字體嘅 glyph，改用畫嘅 `DiamondMark`／`MoonMark` 同 Material icon

### 6. `4fdf3b1` 揭曉動畫
- [ ] 3.4 秒 timeline；撳畫面跳到尾；減少動態效果直接顯示最後畫面；動畫未完掣唔撳得
- [ ] 揭曉用嘅 profile（id `reveal`）只喺記憶體

### 7. `f82c655` 分享卡 QR
- [ ] QR 內容只係網址 `https://xuanli-opal.vercel.app`；已用 OpenCV 掃過 PNG 驗證
- [ ] 新 dependency：`qr_flutter`
- [ ] 將來換網域要改 `xuanliWebUrl`（`share_parts.dart`）

### 8. `34ade1c` 封面
- [ ] **文案要睇**：「160 個組合，邊個係你？」同三個賣點、「免註冊・全離線・出生資料唔離你部機」
- [ ] 流程步序：封面 0 → 出生 1 → MBTI 2 → 揭曉 3 → 檔案卡 4

### 9. `9e2c38f` 不存資料嘅試玩
- [ ] **私隱承諾**：揭曉前後 `SharedPreferences` 冇任何 key（有 flow test）
- [ ] 「儲存並睇我嘅命理檔案」先係真正儲存；「幫朋友再試一個」清走記憶體 state

### 10. `5d4b1a5` 兩人合盤（16 檔，+1781）
- [ ] **決定 14（spec）**：多人檔案切換 UI 仍屬第二版；朋友資料**用完即棄、唔儲存**
- [ ] 分數只由八字計（日主五行、日支六合／六沖、喜用神互補）；MBTI 只影響文案——同 spec §6.3 一致
- [ ] 分數 61–99；**文案安全線**：test 掃描冇「唔夾／唔配／分手／孽緣」等字眼
- [ ] 關係名只由日主五行決定（15 個），同五行組合會見到同一個名——接唔接受
- [ ] 文案係模板拼接；MBTI 配對冇科學驗證，只作趣味
- [ ] 重構：`BirthDataStep`／`MbtiStep` 加 title／subtitle／showProgress／allowQuiz；分享卡共用件抽去 `share_parts.dart`；`SharePreviewScreen` 通用化

### 11. `327c2e4` 每日一籤（12 檔，+1084）
- [ ] **決定 15（spec）**：新增功能，原本唔喺 spec
- [ ] 籤級跟命理分（≥85／70／55／40）；冇「凶」「下下籤」，最低「守靜籤」
- [ ] 同人同日永遠同一支（FNV-1a hash，無 `Random`／`DateTime.now`）
- [ ] **20 首原創七言籤詩**：逐首睇文字有冇問題（test 有掃負面／醫療／投資字眼，但文學質素要人睇）
- [ ] 只存「今日已抽」日期（`xuanli_stick_drawn`），唔入備份
- [ ] 解曰跳過「餘事勿取」同喪葬類項目

### 12. `6e82bee` 桌面 Widget（23 檔）
- [ ] Dart 橋：App Group `group.com.xuanli.xuanli`、iOS kind `XuanLiWidget`、Android `XuanLiWidgetProvider`／`XuanLiWidgetMediumProvider`——**三個名要同原生側一致**
- [ ] Android 新增 3 個 receiver（manifest）；`RECEIVE_BOOT_COMPLETED` 本來已有
- [ ] iOS 只加咗 Swift／plist／entitlements 檔案，**冇改 `project.pbxproj`**（腳本等有 Xcode 先行）
- [ ] `ios/Runner/Runner.entitlements` 係新檔，但 Runner target 未引用佢（要等腳本）
- [ ] 已驗證：Kotlin 對 Android 舊 stub 編譯 0 error＋27 項邏輯測試；Swift typecheck＋23 項邏輯測試；Dart 真 JSON → Swift decode

---

## C. 跨 commit 要留意

- [ ] **新增 dependency**：`file_picker`、`share_plus`、`qr_flutter`（運行時）、`flutter_launcher_icons`（dev）。**零網絡鐵律**：呢幾個 package 本身都唔發網絡請求；`qr_flutter` 純本機畫
- [ ] **Spec 已改**（`XUANLI_SPEC.md`）：決定 12 分享卡、13 稀有度、14 兩人合盤、15 每日一籤全部由「第二版」提前入 MVP——**呢啲係 Stephanie 親自拍板，請確認**
- [ ] **UI 簡體字**：新文案已人手檢查；`lunar` 回傳簡體仍經 `almanac.dart` 繁體化
- [ ] **按鈕字體 bug**：`FilledButton.styleFrom(textStyle: TextStyle(...))` 一覆寫就丟失字體 family（變方格）。呢個 PR 入面已逐個加 `fontFamily`；之後新增按鈕要留意
- [ ] 醫療／投資文案安全線：籤詩、合盤、解曰都冇出現勸阻就醫或具體買賣建議
- [ ] 全 app 仍然零網絡請求

## D. 線上網站（已部署，非 PR 內容）

`https://xuanli-opal.vercel.app` 已部署呢個 branch 較早嘅版本（含分享卡、稀有度、封面、揭曉、不存資料試玩、合盤、每日一籤；**未含 Widget**）。Vercel SSO protection 已關，任何人拎到連結都開到。
