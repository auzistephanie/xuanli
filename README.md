# 玄曆 XuanLi

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

Vercel 專案冇 build 步驟（Flutter 唔喺 Vercel 度），`vercel.json` 已停用 GitHub 自動部署。
更新線上版：`flutter build web --release`，再喺 `build/web` 內用 `vercel deploy --prod`。

## 重新生成 app icon／字體

- Icon 原圖喺 `assets/icon/`，改完行 `dart run flutter_launcher_icons`
- 字體係 subset 版（Big5 常用字＋repo 內出現過嘅字，約 8MB）；冇收錄嘅罕見字會 fallback 去系統字體
