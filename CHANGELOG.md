# CHANGELOG — xuanli（玄曆）

> 改動記錄出口：新條目一律插喺呢個檔案頂部。CLAUDE.md 只放路由同現行規則。

- 2026-08-01（承 07-31 制度複檢）：**`scripts/github_push.py` 修靜默故障** — 舊版 `_PUSH_STATE_DIR` 用 `os.path.dirname(REPO)` 當 stephanie-personal 係隔籬 folder；04-MAINTENANCE §6 將 5 個 repo 搬出 Drive Mirror 後假設崩咗，`makedirs` 靜靜咁喺 `~/Desktop/dev`、`~/dev`、`daily-novel/` 開咗 3 個假 stephanie-personal，concurrent-push 偵測對 6 個 repo 死咗都冇人知（真 state 檔停留喺 7/26–7/30）。改為 `STEPHANIE_PERSONAL_DIR` 環境變數 → Drive 正本絕對路徑 → legacy sibling 三段 resolve，搵唔到就**唔寫兼出聲**（S5「死咗邊個會知」）。12 份 script 一齊改，py_compile 全過，sales-trainer 實跑驗證真 state 有更新。假 folder 已收入 `_to_delete/`。

- 2026-07-31：`.gitignore` 加 `*.bak-*` 第二道防線 — 配合 06-STANDARDS §S3「備份一律開喺 `_to_delete/`」，就算漏咗 mv 都唔會畀 `github_push.py` 誤推上 GitHub（2026-07-25 事故嘅根治）。本 repo 冇 governance `backups/`，所以唔需要 negation 例外。

## 2026-07-29 Phase 3c Deep Link Routing 完成（冷啟動 `xuanli://day/...` 接返 Calendar tab）

- **新增 `DeepLinkRouter`**（`lib/services/deep_link_router.dart`）：包裝新加嘅 `app_links` package，解析 `xuanli://day/YYYY-MM-DD` 嘅冷啟動 launch URI（spec §9.6）。已接入 `TabShell`／`CalendarScreen`（新加 `deepLinkDate`／`initialSelectedDate` 兩個參數——同本身已有嘅 `today` 參數分開，`today` 淨係控制月格仔嘅 `isToday` highlight，唔受影響）同 `main.dart` 嘅 bootstrap（呢個係**要 await** 嘅，唔似 widget／notification 嗰兩個 fire-and-forget refresh，因為要喺 `TabShell` build 之前就知道應該開邊個 tab／揀邊一日）。
- **新加 dependency：`app_links`**（證實有需要——冇現存 package 識解析 incoming launch URI）。佢個 `AppLinksPlatform.instance` 係一個 settable static field，俾到一個比 Phase 2h／3a／3b 嗰種 `MethodChannel` mock 更乾淨嘅 direct-fake-injection test seam。
- **新增 native URI scheme registration**：`AndroidManifest.xml` 喺 `MainActivity` 加咗 `<intent-filter>` 撳 `xuanli://day/...`；`Info.plist` 加咗 `CFBundleURLTypes`。兩個都 XML／plist 驗證過，但同 Phase 2h 之後每一次 native config 改動一樣，冇真機／simulator 驗證唔到 end-to-end。
- **範圍邊界講明**：呢個 plan 淨係做冷啟動——app 已經開緊嗰陣先收到嘅 deep link（`AppLinks().uriLinkStream`）未做，呢個係一個要諗 navigation-stack 嘅獨立設計問題，留返做獨立 follow-up。而且而家都仲未有真正會送 link 嘅 native widget（Phase 3a 個 data bridge 寫嘅 JSON 而家冇嘢讀），所以呢個缺口而家冇實際影響。
- **Review 過程執到三個真問題，值得記低**：(1) `DeepLinkRouter` 個 native platform call 一開始冇 guard——喺呢部冇 simulator／裝置嘅 dev 環境會擲 `MissingPluginException`，Task 2 接落去嗰刻會累到 4 個本身已經過嘅 bootstrap test 一齊爆——跟返 sibling service 個 pattern 加咗 try/catch 修好；(2) 發現 `DateTime.parse` 會靜靜將 out-of-range 日期 roll over（例如 `"2026-13-45"` 變咗 `2027-02-14`）而唔係拒絕佢——用 strict-format + round-trip 重組 check 修好；(3) 將個 router 接入 bootstrap 嗰陣，發現同一個 task 加嘅 OS-wide `xuanli://` scheme registration，令一個 out-of-range 年份（例如 `9999-01-01`）可以 seed `CalendarScreen` 個初始月份去到超出自己 navigation 邊界，令個日曆 tab 永久卡死、app 入面完全冇得救返——加上而家個 scheme 唔淨係 XuanLi 自己（未來嘅）widget 先叫得，係部機任何 app 都 reachable，所以呢個係修咗而唔係延後：`DeepLinkRouter` 拒絕 `[1900, 2100]` 以外嘅年份。

## 2026-07-29 Phase 3b 通知排程完成（淨係 Dart 端排程，未起 native widget）

- **新增 `NotificationScheduler`**（`lib/services/notification_scheduler.dart`）：包裝本身已經喺 `pubspec.yaml` 但一直未用過嘅 `flutter_local_notifications`，用 `zonedSchedule` 排未來 7 日嘅每朝通知——內容用 `buildNotificationText()`（Phase 3a 加嘅短版文案），時間/開關用 `AppSettings.notificationHour`/`notificationMinute`/`notificationsEnabled`（Phase 2g）。已接入 `main.dart` 嘅 app 開啟 bootstrap，同 `WidgetDataBridge`（Phase 3a）並排、一樣用 `unawaited()` 完全 fire-and-forget。
- **今次加咗兩個新 package**：`flutter_timezone`（偵測裝置真實 IANA timezone，係準確通知響鐘時間嘅真實功能需求——唔似 Phase 2h 個日曆全日事件寫入嗰次，證實用 plain UTC 已經啱）；同 `timezone`（由本身已經係 transitive dependency〔經 `device_calendar` 帶入嚟〕升做直接 dependency，版本冇變，零 churn）。
- **改正咗 Phase 3a 個 plan 自己講錯咗嘅一個假設**：Phase 3a 嗰陣刻意延後通知排程，理由係以為 `flutter_local_notifications` 需要一套同 `device_calendar`/`home_widget` 「完全唔同嘅測試架構」。呢個假設係錯嘅——執到 installed package 嘅源碼先發現，佢實際嘅 platform 實作用嘅都係普通、可以 mock 嘅 `MethodChannel`，同另外兩個 package 一模一樣。記低喺度，等之後嘅人唔使再撞多次同一個過度審慎嘅延後決定。
- **Review 過程執到兩個真問題，已修**：(1) timezone 偵測失敗降級做 UTC 嗰段 doc comment，原本寫到好似話「總之好過唔排」——修正做兩面睇嘅講法：響錯 timezone 嘅鐘客觀嚟講可能比完全冇響更差，維持 UTC 純粹係因為有更高優先嘅「platform-channel 失敗絕對唔可以累到成個 background refresh 爆晒」原則要守，唔係話呢個妥協本身係好嘢；(2) `AndroidInitializationSettings('@mipmap/ic_launcher')` 呢個 placeholder 通知圖示，review 確認咗係**真實嘅上真機前必修 blocker**，唔係得個諗頭——Android 個 status bar 通知小圖示淨係睇 alpha channel，而呢個 app 實際嘅 launcher icon（睇過真 PNG 資產確認）係全彩、冇透明度嘅，好大機會顯示做一嚿破晒嘅白色方塊。Code 入面已經加咗 `TODO(phase3b, 上真機前一定要換)` 註解標住；**呢度特登都寫低一次**，等之後唔會漏——上真機測試通知之前，一定要整一個正經嘅單色剪影 notification icon 資產先。
- **範圍邊界**：呢個 plan 淨係跟 spec §9.7 字面（「app 每次打開 refresh」）接咗去 app-launch bootstrap，冇接落 `SettingsScreen` 個通知開關/時間揀選器（唔會做「改完 settings 即刻 reschedule」嗰種 live 效果——下次開 app 個 refresh 自然會攞到新 settings，spec 亦冇要求即時生效）。真實裝置上嘅通知送達/準確響鐘時間都仲未驗證過——呢部 Mac 冇 simulator/裝置，同 Phase 2g 之後每個裝置相關功能一樣嘅老問題。
- **⚠️ 全 branch review 執到一個結構性缺口，已修（commit `371bbe4`）：唔修嘅話喺 Android 上通知一個都唔會響。** 前面 4 個 task 全部 review 都冚唔到，因為佢哋一律 mock 緊 Dart 側嘅 `MethodChannel`，從來冇真正行過 `AlarmManager`/native permission dialog 嗰條 path。兩個真缺口：(1) `android/app/src/main/AndroidManifest.xml` 本身完全冇註冊 `flutter_local_notifications` 話明要有嘅 `<receiver>`（`ScheduledNotificationReceiver`／`ScheduledNotificationBootReceiver`）同 `RECEIVE_BOOT_COMPLETED` 權限——`zonedSchedule()` call 本身唔會爆，但去到真正響鬧嗰刻，因為冇 receiver 接住個 `AlarmManager` broadcast，通知永遠唔會顯示出嚟；(2) `initialize()` 本身唔會自動問 Android 13+ 嘅 `POST_NOTIFICATIONS` runtime 權限，要額外 call `requestNotificationsPermission()`（依返 `CalendarSyncService.requestPermission()` 嗰套 pattern）先會出到用戶許可對話框。兩樣都已經修好：manifest 加咗兩個 receiver + 權限，`NotificationScheduler._ensureInitialized()` 加咗 permission request call。冇 Android SDK/Gradle 呢部 Mac 做唔到真 build，`xmllint` 驗證過 manifest well-formed，Dart 側 210/210 test 全過，但真機上嘅 receiver dispatch/reboot 存活/permission dialog 行為都仲係得靠之後有真機先可以驗證。

## 2026-07-29 Phase 3a Widget 資料橋接完成（淨係 Dart 端寫入，未起 native widget）

- **`buildNotificationText()` 加咗落 `lib/engine/copywriter.dart`**：短版文案（spec §9.7），例如「今日丙戌日・命理分42・宜祈福、靜修，忌簽約。避開申時落大決定。」——除咗畀之後嘅通知功能用，而家即刻俾 widget「中」size 攞嚟顯示。
- **新增 `WidgetDataBridge`**（`lib/services/widget_data_bridge.dart`）：包裝本身已經喺 `pubspec.yaml` 但一直未用過嘅 `home_widget` package（冇加新 package），負責計未來 7 日嘅 `DayReading` 再序列化做 JSON、寫入 native widget 讀嗰個 storage（spec §9.6 嘅資料流要求）。已接入 `main.dart` 嘅 app 開啟 bootstrap，用 `unawaited()` 完全 fire-and-forget，唔會拖慢冷啟動。
- **範圍邊界（講清楚）**：呢個 phase 淨係做完 spec §9.6 嘅 Dart 端寫入呢一半。**未起 iOS WidgetKit extension 或者 Android AppWidgetProvider**——卡喺呢部 Mac 冇裝 Xcode／Android Studio（`flutter doctor` 確認：淨係 Xcode Command Line Tools、冇 CocoaPods、冇 Android SDK）。Stephanie 會另外裝返呢批 tooling，native widget UI 呢部分要等裝好先繼續。**呢個 plan 亦刻意冇做通知排程**（spec §9.7 嘅送達機制，`flutter_local_notifications`／`zonedSchedule`）——原因係嗰個 package 用緊完全唔同嘅測試架構（Pigeon 生成嘅 platform interface，唔似 `device_calendar`／`home_widget` 咁樣簡單可以 mock 個 `MethodChannel`），而且要準確嘅通知發送時間仲要新加一個 `flutter_timezone` dependency 做真實裝置時區判斷（唔似 Phase 2h 日曆寫入嗰次，證實用 plain UTC 就啱）——兩樣都值得起獨立 follow-up plan 先做，唔喺呢個 plan 度趕。
- **Review 過程執到一個真係設計修正**（記低畀之後嘅人唔使再撞一次）：`WidgetDataBridge.refreshNext7Days` 個 try/catch 一開始係包住成個 method body（計算+platform 寫入一齊包），咁會連計算部分真係有 bug 都靜靜吞埋——同「native widget 未註冊」呢種預期之內嘅失敗混埋一齊睇唔出分別。已經改窄做淨係包住 platform 寫入嗰步，payload 計算而家冇被包住，真係有 bug 會照樣爆出嚟。不過因為成個 app 完全冇 crash-reporting／zone-error-handling 嘅底層設施（冇 `runZonedGuarded`、冇覆寫 `FlutterError.onError`——grep 過確認），呢個「爆出嚟」而家淨係 dev/QA 見到，去到 release build 唔會有人睇到——呢個係已知、有記錄嘅缺口（唔係呢個 plan 嘅工作範圍，要整個 app 層面嘅 crash-reporting 底層設施先修得到），寫低喺度免得之後唔記得。

## 2026-07-28 Phase 2h 日曆整合完成 — Tab B/C 接返真 device_calendar，Phase 2 App UI 收尾

- **新增 `CalendarSyncService`**（`lib/services/calendar_sync.dart`）：包裝 `device_calendar` 嘅權限/讀/寫（`hasPermission`/`requestPermission`/`addAllDayEvent`/`eventsInRange`/`eventsOnDay`），冇 throw、一律靜靜返 `false`/`[]`。`device_calendar: ^4.3.0` 本身已經喺 `pubspec.yaml`（之前裝咗冇用過），今次冇加新 package。
- **Tab C（`CalendarScreen`）**：月格仔嘅行程幼條、日卡「📅 你嘅行程」section，由之前永遠 `false` 嘅 `hasEvents` stub，接返真實讀取（首次入 Tab 問一次權限，拒絕就成個行程 section 靜默隱藏）。
- **Tab B（`ActivityScreen`）**：「＋ 加入我嘅日曆」（建全日 event）、「當日行程 ›」（讀當日 events，AlertDialog 顯示）由之前嘅 stub SnackBar，接返真實寫入/讀取。
- ⚠️ **未驗證項**：呢個 phase 淨係用 mocked platform channel（`flutter test` 全部 mock，冇真機/simulator）驗證過所有可達 code path；真實裝置上嘅權限對話框行為、寫入實際日曆 app 後嘅顯示效果，都未喺呢部 Mac 上測試過，上線前要搵真機/simulator 補測。
- **Review 過程執到兩個假線索**（記低畀之後嘅人唔使再行多次）：
  1. 一開始以為 `addAllDayEvent` 嘅全日事件有 timezone bug，加咗個 `_hostFixedOffsetLocation()` 想修——後來證實唔使：`TZDateTime.from` 係 instant-preserving，`device_calendar` 自己嗰套「用 host local time 重新歸位」邏輯喺真機上（app 同日曆共用同一個系統 timezone）本身已經自洽，呢個「修法」刪返走。
  2. `CalendarScreen` 讀月/日 events 屬於 async，需要防止「慢嗰個 response 遲到、蓋走快嗰個嘅新結果」（request-ordering）——第一版用一個共用嘅 generation counter，review 發現呢個共用版會俾一個唔相關嘅撳日動作，靜靜蓋走緊 in-flight 嘅月讀取結果，於是拆做兩個獨立 counter（`_monthLoadGeneration`／`_dayLoadGeneration`）。
- **已知、刻意延後嘅跟進項**（Task 3 review 提出，唔急）：Tab B「＋ 加入我嘅日曆」冇防重複撳保護——如果權限已批（冇彈系統對話框卡住），連撳兩下會建到兩個重複 event，因為 `addAllDayEvent` 一律建新、唔會更新舊嘅。「當日行程 ›」（`onViewSchedule`）都係同一形狀嘅缺口，只係後果輕微好多（最多疊多個 dialog，冇資料重複）。兩個都係 plan 本身冇考慮到嘅缺口，已經照 spec 原樣做齊，值得起個小 follow-up（撳落之後 disable 個掣，等自己嗰次寫完先放返）但唔急。

## 2026-07-25 `.active-session.lock*` 冇入 .gitignore → session 鎖檔一直推上 GitHub

- **問題**：`session-lock.sh` 喺每個 repo 根寫 `.active-session.lock`；release 嗰陣 Drive mount `rm` 唔到（device bridge 冇 rm 權限），會 fallback 改名做 `.active-session.lock.DELETE-ME-<epoch>`。兩種檔全部 repo 都**冇入 `.gitignore`**，所以 `github_push.py` 照推——最舊一個殘留檔 timestamp 係 **2026-07-14**，即係呢個洩漏行咗成十日。
- **修**：12 個 repo（含 `novel-web`）`.gitignore` 全部加 `.active-session.lock*`（一條 pattern 蓋埋活鎖同 `.DELETE-ME-*`）；現存 16 個殘留檔 mv 入各自 `_to_delete/`。
- **同類第三宗**：同日先修咗 ①`_to_delete/` 冇入 ignore、②`.bak-*` 冇入回收筒，今次係 ③鎖檔。三宗共通根因＝**新產生嘅暫存檔冇人幫佢配 ignore rule**。
- ⚠️ **未做（要 Stephanie 拍板）**：真正治本係改 `session-lock.sh`，唔好將鎖寫入 repo 樹，改寫去 `stephanie-personal/scripts/.session-locks/<repo>.lock` 集中管——咁就冇檔會落 repo，亦唔使靠 12 份 `.gitignore` 各自記得。

## 2026-07-25 Phase 1 引擎完成（TDD，全綠）

- 裝好 Flutter SDK（`brew install --cask flutter`，之前部 Mac 冇裝過）。
- `lib/engine/` 九個純 Dart 模組全部起好：wuxing_tables／almanac／bazi／scoring／activity／ziwei／copywriter／day_reading_engine，`test/engine/` 全綠，`dart run tool/demo.dart` 可行。
- 範圍決定（已同 Stephanie 確認）：ziwei.dart 全模式同降級模式共用簡化日支對照表，唔做真紫微排盤（v2 先做深度文案）。
- 未完成：`lib/data/mbti_tones.json` 淨係 ISFP/ISFJ 兩型有真實內容，其餘 14 型文案要喺 Phase 2 UI 接之前補齊。

## 2026-07-25 `_to_delete/` 冇入 .gitignore → 回收筒檔案推咗上 GitHub（修）

- **問題**：全局規則係「清理檔案一律 mv 去 `_to_delete/`」，但本 repo `.gitignore` 冇 `_to_delete/` 一行。`github_push.py` 嘅 `working_files()` 用 `git ls-files -c -o --exclude-standard`，`--exclude-standard` 只擋 .gitignore 有列嘅嘢——冇列就當普通未追蹤檔照上傳。GitHub Git Trees API 核實 remote `main`：**實際有 1 個（`_to_delete/CLAUDE.md.bak-20260718`）**。
- **修**：`.gitignore` 加 `_to_delete/`。下次 push，`working_files()` 唔再列佢 → `deletions = [p for p in remote if p not in local_set]` 會用 `sha: None` 自動由 remote 樹刪走，唔使（亦唔准）動用 git CLI `rm --cached`。
- **範圍**：同一 session 掃晒 11 個 repo，6 個中招（AI for elderly／stephanie-portfolio／xuanli／catnu-app／MakeMyHome／fable-prompt），一次過全部補。原本已有嘅 5 個：Travel App／daily-novel／sales-trainer／stephanie-personal／venturenix-lab-seminar。
- ⚠️ **只由 HEAD 移除，舊 commit 歷史仍然有**。已 grep 過全部內容，冇 token／secret **值**（只有變數名如 `GITHUB_TOKEN` 出現喺說明文字），本 repo 為 **public**，判斷唔需要 rewrite history。

## 2026-07-18 CLAUDE.md 加 repo 專屬 DoD＋Push kit 裝好（開檔呢份 CHANGELOG）

- CLAUDE.md 加「✅ 完成前檢查」section：dart test／flutter analyze＋test／簡體字肉眼檢查／每 phase 對照 spec §10 驗收（全 repo CLAUDE.md 升級 session，承接同日 Standards 收斂）。改前版本 → `CLAUDE.md.bak-20260718`。
- **Push kit 裝好**：`scripts/github_push.py` copy 自 stephanie-personal 正本；`.env` GITHUB_TOKEN 同 autopush-registry 行原已存在（即「三缺一」只差 script，今日補齊）。首次真 push 留 Phase 1 有 code 先驗。
- 本 repo 之前冇 CHANGELOG.md，今日起計。
