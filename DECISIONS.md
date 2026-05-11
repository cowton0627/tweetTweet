# DECISIONS

紀錄這個專案做過、且不容易從程式碼或 git log 直接看出的決定。

## 2026-05-11

### 公開 release 前的清整

把 repo 從半私人狀態整理成可公開的作品集。包含:

- 把分散的 Swift 檔搬進分層資料夾(`Controller/`、`View/`、`ViewModel/`...)
- 改寫 README 為情境式架構
- 加入 LICENSE、PRIVACY、pre-commit hook

備份(包含整理前的完整歷史)曾保存在 `/tmp/tweetTweet-pre-cleanup.bundle`,確認穩定後可刪。

### 為什麼選 MIT License

Portfolio 用途優先,MIT 對 recruiter / reviewer 來說最沒摩擦,任何人都能合法 clone、跑、改、看。Apache 2.0 的專利條款這個情境用不到。

### 為什麼用 pre-commit hook,不用 xcconfig

選 hook 是因為 setup 比較輕(不用動 Xcode 簽章設定),且可以同時擋多種類型的洩漏(Team ID、token、私鑰、自訂字串)。

代價是:hook 不會自動跨 repo 生效。

- Clone 新環境後必須跑一次 `git config core.hooksPath .githooks`
- `.githooks/patterns.local`(放個人敏感字串清單)是 gitignored,換機器要重建。範本在 `.githooks/patterns.local.example`

未來如果要在實體機 demo,可以考慮升級到 xcconfig 方案:把 `DEVELOPMENT_TEAM` 抽到 gitignored 的 `Signing.local.xcconfig`。

### 為什麼改寫 git 歷史

舊 commit 的 author/committer email 是當時 Xcode 自動帶入的工作信箱。用 `git filter-branch` 全部換成 GitHub noreply email,然後 force push 覆寫 `origin/main` 和 `origin/codex/home-layout-readme`。

副作用:所有 commit hash 都變了。如果這個 repo 之前被誰 fork / clone 過,他們本機那份還是舊歷史 — 無解,只能接受。

連帶把 `~/.gitconfig` 全域改成 noreply 格式 `83654992+cowton0627@users.noreply.github.com`,未來在任何 repo commit 都不會再洩。

### 為什麼 `Resources/` 內的名人照沒移除(尚未處理)

目前仍保留 `Elsa-Pataky-*.jpg` 等檔。理由:當下優先處理 git 機密外洩,版權問題暫緩。

**已知風險:**

- Getty / 圖片社可能對名人照發 DMCA takedown
- 對 portfolio 來說,看到名人照當 demo 素材會讓 reviewer 質疑對版權 / 合規的判斷

**將來處理方案:**

- 換 Unsplash / Pexels 等 CC0 素材
- 或改用程式產生的 placeholder(灰底 + 文字)
- 替換時連帶調整 `Resources/PostListData_*.json` 內的 `avatar` 與 `images` 欄位
