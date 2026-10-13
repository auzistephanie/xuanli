# Kairo 吉時

中國傳統擇日 × 八字五行 × 紫微 × MBTI：同一日，唔同人有唔同宜忌。
全離線、免註冊，出生資料絕不離開你部機。

- **今日宜忌**：命理分＋MBTI 狀態契合度雙環，宜忌按你嘅喜忌神排序
- **我想做…**：剪髮、搬屋、簽約、睇醫生…幫你揀未來 1 週／1 月／3 月最順嘅日子，一撳加入日曆
- **月曆**：吉凶一眼睇晒，同部機日曆行程並排
- **組合詳解**：10 日主 × 16 MBTI = 160 個組合嘅性格解讀

試玩（web）：https://xuanli-opal.vercel.app

## 開發

```bash
flutter pub get
dart test test/engine/            # 引擎測試
flutter analyze && flutter test   # 全項目檢查
dart run tool/demo.dart 1999-09-20 09:30 ISFP
flutter build web --release       # 輸出 build/web
```

產品規格：[XUANLI_SPEC.md](XUANLI_SPEC.md)　視覺稿：[design/design-preview.html](design/design-preview.html)　協作規則：[CLAUDE.md](CLAUDE.md)

## 部署（web）

合併去 `main` 之後，GitHub Actions（`.github/workflows/deploy-web.yml`，名稱 **Deploy web to Vercel**）會裝 Flutter 3.47.7、跑 `flutter build web --release`，再把 `build/web` 部署到 Vercel 專案 `xuanli` 嘅 production。線上網址仍然係 https://xuanli-opal.vercel.app。你部 Mac 唔使再跑 Flutter 同 `vercel deploy`。

`vercel.json` 繼續停用 Vercel 自己嘅 Git 部署。唔好喺 Vercel 打開 Git 自動部署：repo 根目錄冇建好嘅網頁，打開會令線上版變成 404。

### 合併之後做一次

Token 要你自己喺 Vercel 建立。呢個 repo 冇現成 token。

1. 打開 [Vercel → Account → Tokens](https://vercel.com/account/tokens)，登入之後撳 **Create Token**。名稱可以寫 `GitHub Actions xuanli`。Scope 揀團隊 **auzistephanies-projects**。建立之後複製 token；呢一頁只會顯示一次。
2. 打開 [呢個 repo 嘅 Actions secrets](https://github.com/auzistephanie/xuanli/settings/secrets/actions)，撳 **New repository secret**，加下面三個。名稱要一字不差：
   - `VERCEL_TOKEN`：上一步複製嘅 token
   - `VERCEL_ORG_ID`：`team_c0Yvocg1t5umToddd9egwK7A`（團隊 ID，可喺 [團隊設定](https://vercel.com/auzistephanies-projects/~/settings) 再對一次）
   - `VERCEL_PROJECT_ID`：`prj_MDLTeMT2HmLbkCYcy9l8oeOrlFNa`（專案 ID，可喺 [xuanli 專案設定](https://vercel.com/auzistephanies-projects/xuanli/settings) 再對一次）
3. 打開 [Deploy web to Vercel](https://github.com/auzistephanie/xuanli/actions/workflows/deploy-web.yml)，撳 **Run workflow**，分支揀 **main**。

如果合併之前已經加好三個 secret，合併嗰一下就會自己跑，可以跳過第 3 步。如果合併時 secret 未齊，嗰次會失敗；加完 secret 再撳 Run workflow 就得。Token 過期或者被刪，部署會變 403，就再建立一粒新 token，改 `VERCEL_TOKEN` 呢個 secret。

### 點樣確認線上已經係 Kairo

Actions 行到綠色之後，打開 https://xuanli-opal.vercel.app 。分頁標題應該係 **Kairo**。睇網頁原始碼，`<title>` 係「Kairo 吉時」。如果仲係「玄曆 XuanLi」，就係 2026-10-11 嗰次舊部署，先睇 Actions 有冇綠剔。

## 重新生成 app icon／字體

- Icon 原圖喺 `assets/icon/`，改完行 `dart run flutter_launcher_icons`
- 字體係 subset 版（Big5 常用字＋repo 內出現過嘅字，約 8MB）；冇收錄嘅罕見字會 fallback 去系統字體
