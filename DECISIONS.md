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

### 圖片素材版權風險(2026-07-27 已處理)

公開作品集不應依賴名人照或來源不明的網路圖片。原有 `Elsa-Pataky-*.jpg` 等 54 張素材已全部移除,改成:

- 9 張虛構人物頭像(`avatar-*.jpg`)
- 16 張台灣日常、飲食、城市與自然情境照片(`post-*.jpg`)
- 兩份展示 JSON 改用新素材,同時保留零圖、單圖與多圖排版情境

新素材以生成式工具製作,提示詞明確排除名人、公眾人物、品牌、Logo、可辨識文字與受版權保護角色。選擇自有生成素材而非外部圖庫,是為了讓 repo 可以獨立展示,不必逐張維護第三方作者、授權條款與下載來源。

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

**第二次踩坑(2026-05-12 才發現):** Asset catalog 進 Resources phase 還**不夠**讓 app icon 顯示。`actool` 雖然會編 `Assets.xcassets`,但需要 build setting `ASSETCATALOG_COMPILER_APPICON_NAME = AppIcon` 告訴它「哪個 icon set 是 primary」。沒這個設定,actool 編完不輸出任何 icon metadata,Info.plist 不會有 `CFBundleIcons`、`Assets.car` 不會被 link 進 .app,iOS Home Screen 永遠顯示空白。

驗證方式:看 build 產物 `.app/Info.plist` 有沒有 `CFBundleIcons`,以及 `.app/Assets.car` 是否存在。若兩者皆無,就是這個 setting 漏了。

順手把 `ASSETCATALOG_COMPILER_GLOBAL_ACCENT_COLOR_NAME = AccentColor` 也加上,避免後續 accent color 警告。

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

### 單元測試 target(2026-07-27 已建立)

最初因手刻 minimal pbxproj 的設定風險而暫緩建立 test target。作品集清整時重新評估後,Repository protocol 與 shared state 已有足夠的可測試行為,因此建立 `tweetTweetTests` hosted unit-test target。

第一批 8 個測試刻意集中在高訊號行為:

- 用 mock repository 證明 dependency injection 可替換資料來源
- 驗證貼文更新、插入、索引重建、ID 產生與圖片去重
- 直接讀取 repo 內的正式 JSON fixture,避免展示資料格式悄悄失效

測試 target 設定包含 app target dependency、`TEST_HOST`、`BUNDLE_LOADER` 與 shared scheme testable entry。首次以 iPhone 15 / iOS 17.5 Simulator 執行結果為 8 passed、0 failed。

## 2026-07-28

### Async Repository 與完整 feed load state

把原本同步的 `PostRepository` 升級為 `async throws`,並新增:

- `RemotePostRepository`:注入推薦／熱門 endpoint、`URLSession` 與 decoder
- HTTP 2xx 驗證、JSON decoding error 與使用者可讀錯誤
- 每個 feed 獨立的 idle、loading、loaded、empty、failed 狀態
- 單一分頁 retry,避免一個資料源失敗時重載整個首頁

App 預設仍注入 `LocalPostRepository`,讓作品集 clone 後可以離線、無設定地展示。`RemotePostRepository` 是可執行且有 URLProtocol stub 測試的 production seam,但在沒有正式後端 URL 前不硬編假 endpoint。

本地 JSON loader 也從 `fatalError` 改為 `throws`,確保缺檔、讀取或 decoding 失敗會進入同一套 error/retry UI,而不是直接讓 App crash。

測試從 8 個增加到 12 個,新增 empty、failed/retry、遠端成功 decoding 與 HTTP error 情境。iPhone 15 / iOS 17.5 Simulator 驗證結果為 12 passed、0 failed、0 skipped。

### GitHub Actions iOS CI

新增 `.github/workflows/ios-ci.yml`,在 main push、針對 main 的 Pull Request 與手動觸發時執行 `xcodebuild test`。

安全與成本控制:

- 使用 public repository 免費的標準 `macos-15` runner,不使用 larger runner
- `permissions: contents: read`,不授予寫入 repository、issue 或 deployment 的權限
- 設定 20 分鐘 timeout
- 同一 branch 有新 commit 時取消已過時的執行
- 不上傳 build artifact,避免不必要的儲存空間與保留成本
- `CODE_SIGNING_ALLOWED=NO`,不需要憑證、Team ID 或 secrets

### 第一輪 Accessibility semantics

以 Simulator accessibility hierarchy 盤點首頁,發現 SF Symbols 直接被朗讀為英文 `Camera`、`Add`,分頁缺少選取狀態,VIP badge 會被讀成無意義的 `✓`,貼文 toolbar action 只剩數字。

第一輪修正:

- 圖片入口、發文與推薦／熱門分頁加入中文 label、hint 與 selected trait
- VIP 純裝飾 badge 與頭像從重複朗讀內容中隱藏
- 多圖版型合併成「N 張貼文圖片」
- 回應與喜歡 action 同時描述動作、目前狀態與完整數量
- 素材選擇器提供圖片序號與已選取狀態

再次擷取 hierarchy 後,首頁已不再出現 `Camera`、`Add` 或 `✓`,貼文 custom actions 也能表達「回應,2200 則」與「取消喜歡,目前 11319 個喜歡」。Dynamic Type、VoiceOver 實際手勢順序與深色模式仍需後續人工驗證。
