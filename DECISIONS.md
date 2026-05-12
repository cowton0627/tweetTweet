# DECISIONS

紀錄這個專案做過、且不容易從程式碼或 git log 直接看出的決定。

## 2026-05-11

### 公開 release 前的清整

把 repo 從半私人狀態整理成可公開的作品集。包含:

- 把分散的 Swift 檔搬進分層資料夾(`Controller/`、`View/`、`ViewModel/`...)
- 改寫 README 為情境式架構
- 加入 LICENSE、PRIVACY、pre-commit hook

備份(包含整理前的完整歷史)曾保存在 `/tmp/tweetTweet-pre-cleanup.bundle`。`/tmp` 系統重啟後會被清空,所以這份備份視同短期保險,長期不可靠。[2026-05-12 已手動刪除]

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

## 2026-05-12

### 修 letterbox + 把資源真正掛進 build

症狀:Simulator 上主頁上下有黑邊、新 app icon 怎麼換都不更新。

根因(這個專案的 `pbxproj` 是手刻最小版,不是 Xcode 正規生成):

- `PBXResourcesBuildPhase` 的 `files = ();` 是空的,代表 `Assets.xcassets` 跟 `LaunchScreen.storyboard` 雖有 `PBXFileReference` 但**從未被打包進 bundle**
- `Info.plist` 沒有 `UILaunchScreen` 或 `UILaunchStoryboardName` key,iOS 找不到 launch screen 宣告 → fallback 到 iPhone 5/6 老尺寸 → 黑邊
- 由於 `Assets.xcassets` 沒進 build,`actool` 從未被呼叫,新 icon 自然永遠不生效

**為什麼選擇手補 pbxproj,不是重生整個專案:**

- 重生整個 Xcode project 會打亂現有 group 結構、ID 命名規律,影響 git diff 可讀性
- 手補只是新增 4 個 entries(2 個 BuildFile、2 個被引用、Resources phase 補 children),範圍可控、可 review
- 已用 `plutil -lint` + `xcodebuild -list` + 實際 build 驗證

**踩坑備忘:** 手刻 pbxproj 風格的專案,新增任何資源 / 程式碼檔案都要記得**四個地方同步更新**:
1. `PBXFileReference` section 加 file ref
2. `PBXBuildFile` section 加 build file
3. 所屬 group 的 `children = ()` 加 file ref
4. 對應 build phase 的 `files = ()` 加 build file(資源檔放 Resources phase,Swift 檔放 Sources phase)

不然檔案不會被編進 app。

### Repository pattern:抽 `PostRepository` protocol 為接 API 的 seam

原本 `UserData.swift` 直接呼叫 free function `loadPostListData(...)` 載 JSON。把這個耦合抽出來:

- `Network/PostRepository.swift`:protocol
- `Network/LocalPostRepository.swift`:現有 JSON 載入封裝
- `UserData` 改成 `init(repository: PostRepository = LocalPostRepository())`,DI 預設仍是本地

**為什麼選 protocol DI,不是其他模式:**

- 改動最小:現有 `UserData` 內部 state 結構不動,SceneDelegate 的 `UserData()` 呼叫也不變
- 測試友善:之後寫單元測試可注入 mock repository,不依賴 bundle 檔案
- 接 API 時:新增 `RemotePostRepository: PostRepository`,改 SceneDelegate 注入點即可

**為什麼是同步 (sync) protocol,不是 async:**

- 現在資料來源是 bundle JSON,async 等於是把 sync 包成假 async,徒增 boilerplate
- 真正接遠端 API 時,protocol 改成 async 是不可避免的二次改動,但屆時 UserData 內部的 state 流也要配合改(空白 → loading → loaded → error),不只是改 protocol 簽名
- 現在先換 sync 保留簡潔,等接 API 時一次性把 async + loading state 一起做完

### App icon 設計選擇

決定:藍紫漸層底(`#4F46E5` → `#7C3AED`) + 白色 `tt` lowercase monogram + SF Pro Rounded 字型。

**為什麼避開鳥造型:**

直覺反應「tweet → 鳥」,但這幾乎一定會撞到 Twitter / X 的視覺認知。Portfolio 不值得為了直覺感冒這個風險,recruiter 看到也容易誤認。改用文字 monogram 是中性、無爭議、辨識度也夠。

**為什麼選 monogram 而不是其他抽象圖形:**

兩個小寫 t 直接表達 app 名稱 "tt",讀者一秒對得起來;抽象幾何或 speech bubble 雖然好看,但需要二次解讀。

**為什麼藍紫漸層:**

Tech portfolio 的視覺安全牌:中性、現代、不會在 Home Screen 跟其他 app 撞色。粉紅或亮橘更引人注目但風險較高(看著像玩具 app 或娛樂類)。

**為什麼 SF Pro Rounded(`SFNSRounded.ttf`):**

第一版用 SF Compact Rounded Heavy,t 字頂端是斜切硬邊,跟「圓潤」直覺不符。SF Pro Rounded 是 Apple 自家 UI 標準圓潤字,t 的 ascender 與 stem 收尾都是真圓角,符合「親切、社群、易讀」這個情緒方向。

**生成方式:** Python + PIL 腳本(`/tmp/make_tweet_icon.py`),產 1024 master 後降採樣到 16 個 iOS 要求的尺寸。腳本沒 commit 進 repo(屬一次性工具),要重生請看 git log 對應 commit。

### 刪 3 個空資料夾

刪掉 `Controller/Friend/`、`Controller/MainTabBarController/`、`Extension/` — 三個只含 `.gitkeep` 的預留位置。

理由:Reader clone 看到空資料夾會以為功能未完成,不如直接拿掉。未來真要實作 Friend 功能,新增資料夾很快。pbxproj 同步移除這三個 `PBXGroup` 引用與定義,並用 `xcodebuild` 驗證 `** BUILD SUCCEEDED **`。

### 單元測試 target 暫不建立

DECISIONS 已記載「沒有單元測試」這個缺口,但今天決定不做。原因:

- 手刻 minimal pbxproj 加 test target 風險不小(新增 `PBXNativeTarget`、`xctest` product、`TEST_HOST`、`BUNDLE_LOADER`、framework link、build configs,漏一個就跑不起來)
- 目前資料全是靜態 JSON,沒有遠端 API、mutation 邏輯不複雜,寫出來多半是 sanity check
- 真正有 ROI 的時機是接 API 時:那時候 mock repository 才開始有意義
- 現在投入產出比偏低

接 API 時再一次性把測試 target 跟 async 改造一起做。
