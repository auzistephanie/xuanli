# CHANGELOG — xuanli（玄曆）

> 改動記錄出口：新條目一律插喺呢個檔案頂部。CLAUDE.md 只放路由同現行規則。

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
