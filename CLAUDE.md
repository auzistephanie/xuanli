# 玄曆 XuanLi — CLAUDE.md

Flutter app：中國傳統擇日 × 八字五行 × 紫微 × MBTI 個人化宜忌。國風復古典雅，全繁體中文（廣東話語感）UI。

## 必讀文件（順序）

1. `XUANLI_SPEC.md` — 完整實施規格。**所有產品決策已鎖定（spec 第 2 節），唔好重新討論或自行更改**；發現 spec 有矛盾就停低問 Stephanie，唔好自己拍板。
2. `design/design-preview.html` — 視覺最終權威（配色/排版/文案語氣全部以佢為準）
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

## 架構速記

- 傳統層：`lunar` package（干支/建除/神煞/宜忌/沖煞）→ `almanac.dart` 包裝+繁體化
- 個人化層：`bazi.dart`（四柱/五行/喜用神，演算法 spec §6.1）→ `scoring.dart`（命理分 §6.2 + MBTI 契合度 §6.3，**兩分數互相獨立**）
- 文案：`copywriter.dart` 模板插值（模板輪換用 `dayOfYear % n`，唔用 random）
- 儲存：`shared_preferences`，profiles list 結構（MVP 只用 index 0，唔准 hardcode 單 profile）
- Widget 數據流：app 開啟時預生成未來 7 日 DayReading JSON → `home_widget` → 原生讀

## Progress

- [x] 規格 + 設計稿 + combos.json（Cowork session 完成）
- [ ] Phase 1 引擎（TDD，fixtures spec §11）
- [ ] Phase 2 App UI（onboarding + 組合頁 + 3 tabs + 日曆整合）
- [ ] Phase 3 Widget（iOS/Android 小+中）+ 每日通知
- [ ] Phase 4 交付（APK + install_ios.sh）

## Git

- 分支：`main` 保持可 build；每個 phase 一個 feature branch
- Commit message 用英文、細粒度；phase 完成先 merge
- 唔好 commit：`build/`、`.dart_tool/`、`.env`、`.gh-token`、任何含出生資料嘅測試 dump

### Phase 1 開波時裝 auto-push（跟 stephanie-personal 做法，一次過）
Stephanie 用緊一個 launchd auto-push daemon，唔想每個 session 問佢攞 GitHub token。喺 Phase 1 `flutter create` 完、有真 code 之後裝一次：
1. `git init`；喺 GitHub 開空 repo 後 `git remote add origin <https url>`
2. 複製 `~/Desktop/Stephanie-Google Drive/dev/stephanie-personal/scripts/github_push.py` 落 `scripts/github_push.py`
3. `.env` 加 `GITHUB_TOKEN=<PAT>`（問 Stephanie 攞一次，或 copy 現有 repo 嘅）；確保 `.gitignore` 有 `.env` 同 `.gh-token`
4. 喺 `~/Desktop/Stephanie-Google Drive/dev/stephanie-personal/scripts/autopush-registry.txt` 加一行本 repo 絕對路徑
5. 之後現有 daemon（每 120s）+ `push-now.command` 自動涵蓋，idempotent；驗證：`python3 scripts/github_push.py "init xuanli"`
