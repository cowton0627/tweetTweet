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

再次擷取 hierarchy 後,首頁已不再出現 `Camera`、`Add` 或 `✓`,貼文 custom actions 也能表達「回應,2200 則」與「取消喜歡,目前 11319 個喜歡」。Dynamic Type 與 VoiceOver 實際手勢順序仍需後續人工驗證。

### 深色模式驗證與修正

實際把 Simulator 切換為深色模式後,發現 App 仍維持淺色外觀。原因不是 SwiftUI 元件不支援 Dark Mode,而是 Scene bootstrap 同時對 `UIHostingController` 與 `UIWindow` 設定 `.light`,首頁也直接使用 `Color.white`。

移除固定的 interface style,並把容器背景、貼文互動按鈕與列表分隔區改為 semantic system colors。重新冷啟動後確認首頁可跟隨系統外觀,並將明暗兩種 Simulator 截圖放入 README。

這次驗證也再次證明:只檢查程式碼中是否使用 `systemBackground` 不足以宣稱支援 Dark Mode,還要用實際 runtime 外觀切換與截圖確認 Scene／Window 層沒有覆寫系統設定。

### Dynamic Type 最大輔助字級驗證

第一次把 Simulator 設成 `accessibility-extra-extra-extra-large` 時,首頁文字幾乎沒有變化。原因是早期畫面大量使用 `.font(.system(size:))`,視覺上雖然整齊,卻繞過了使用者的 Dynamic Type 設定。

這次把貼文、搜尋、詳情、載入狀態與留言操作改用 `.body`、`.headline`、`.subheadline`、`.caption` 等 semantic text styles。內容區完整跟隨最大輔助字級並允許垂直捲動;頂部與底部 chrome 則限制到 `accessibility1`,避免五個固定導覽操作在窄螢幕互相覆蓋。

同時把主要導覽操作的 layout target 擴充到至少 44pt,並在最大輔助字級的 iPhone 15 Simulator 冷啟動後確認文字可讀、內容可捲動、主要操作仍可見。驗證截圖為 `screenshots/home-dynamic-type.png`。

## 2026-08-10

### 後端沿用既有 Express 專案,不照原方案重寫 FastAPI

`docs/BACKEND_FEASIBILITY.md` 當初建議 FastAPI + Postgres,理由是「複用既有 Python / uv 技能」。實際盤點後發現另一個 repo `tweettweet-api`(當時名為 `backend-practice`)已經是帶測試、CI 與版本化 migration 的 Express + TypeScript + SQLite 專案,那個理由就不存在了。為了貼合一份研究文件而重寫一遍能跑的後端是純粹的浪費。

同理也放棄 monorepo:後端已有自己的 commit 歷史與 CI,併進來會丟掉這些。改成雙 repo,兩邊 README 互相連結。

SQLite 也留著沒換 Postgres。已經有可用的 migration 機制,換 DB 換不到展示價值,單機 demo 的併發量下也綽綽有餘。

### API 契約對齊既有 fixture,而不是讓 App 遷就後端

後端的 `GET /api/feeds/:category` 回傳 `{ "list": [...] }`,欄位與 `Resources/PostListData_*.json` 逐字相同。`Post`、`PostList` 與 `RemotePostRepository` 因此一行都沒改,連既有測試都原封不動。

代價落在後端:DB 用 snake_case,對外輸出 camelCase,中間多一層 row → DTO 映射。這本來就是該有的分層——API 契約不該讓呼叫端知道資料表長什麼樣——所以代價其實是把設計做對的成本。

布林值的轉換是硬性的而非美觀問題:SQLite 沒有 boolean 型別,欄位存 0/1,而 Swift 的 `JSONDecoder` 不接受用 0/1 解 `Bool`。少了這層轉換,client 根本解不開 feed。

### base URL 走 xcconfig,而且拆成 scheme 與 host

沿用 `Signing.xcconfig` 已經在用的模式:tracked 檔提供結構,gitignored 的 `API.local.xcconfig` 提供實際值。新增 `Base.xcconfig` 當唯一的 base configuration 入口,往後要加設定只需多一個 `#include`,不必再動 `project.pbxproj`。

拆成 `APIScheme` 與 `APIHost` 兩個變數不是潔癖:**xcconfig 把 `//` 當註解起始**,寫成 `http://localhost:3000` 會被靜默截成 `http:`。之後填 tunnel 網域的人會撞到同一個坑,所以 example 檔直接寫明。

### 沒有設定時退回 bundle JSON,而且預設就是沒有設定

第一版讓 Debug 預設指向 `localhost:3000`,結果是 clone 下來沒跑後端的人會看到載入失敗,而不是內容——為那個情境寫的 fallback 永遠觸發不到。「clone 後即可在 Simulator 完整操作」是這個 repo 對外的宣稱,不該為了開發方便犧牲。

改成兩個 configuration 都從 local override 讀,沒有 override 就解析成空值並退回 bundle JSON。接後端變成一次性的明確設定,CI 也因此不需要任何本機檔案。

### repository 在 SceneDelegate 注入,不放進 `UserData` 的預設參數

把 `RemotePostRepository` 設成預設參數只要改一行,但 `UserData()` 同時被十幾個 SwiftUI preview 使用,那樣等於讓每個 preview 都去打網路。composition root 是唯一該知道「有伺服器存在」的地方,preview 與測試繼續拿 bundle JSON。

### pre-commit hook 的 Team ID 檢查其實從未執行過

`.githooks/pre-commit` 的規則格式是 `"pattern|label"`,用 `${entry%%|*}` 取 pattern。但 DEVELOPMENT_TEAM 那條 pattern 自己就含 alternation `(^|[^_A-Za-z0-9])`,從第一個 `|` 切開會把它截成 `(^`——不合法的 regex。grep 回 exit 2,再被 `|| true` 吞掉,於是這個 hook 存在的主要理由靜默失效。唯一症狀是每次 commit `project.pbxproj` 都會印一行 `grep: parentheses not balanced`,看起來像雜訊。

改成從最後一個 `|` 切開(label 是人寫的描述,不含 `|`),並且讓不合法的 pattern 直接中止 commit:grep 的 exit 1(沒找到)與 2+(跑不起來)不能再等同處理。**跑不起來的檢查不可以回報安全。**

全域 hook 的同名檢查不受影響——它用單一 pattern 字串,沒有這個解析問題,而且會在 repo hook 結尾被 exec——所以第二道防線一直有效,Team ID 沒有實際外流風險。

## 2026-08-10（下午）

### 後端對外曝露前先補中介層,順序不能顛倒

在開 tunnel 之前先在後端加上 helmet、rate limit 與 request log。一旦有公開網域,這個 API 就是任何人都打得到的端點,先開洞再補防護等於賭沒人在那段空窗期找到它。

`TRUST_PROXY` 的取捨值得記:在 tunnel 後面,所有請求都從同一個本機位址進來,rate limiter 若不看 `X-Forwarded-For` 就會把全世界算成同一個來源,形同虛設;但無條件信任那個 header 更糟——直接連上來的人可以自行偽造,每個請求換一個假位址就取得無限額度。所以參數收的是「信任幾層 hop」而不是布林開關,而且預設不信任。細節記在後端 repo 的 README。

### 錯誤訊息不能外洩框架的語言

實機驗收前做了一次負向測試(把後端位址改成不存在的網域),畫面顯示的是 `A server with the specified hostname could not be found.`——URLSession 的 `localizedDescription`,出現在一個全繁體中文的介面裡。

原因是連線在 `session.data(for:)` 就拋 `URLError`,`RemotePostRepositoryError` 寫好的中文訊息一句都走不到,`UserData` 又直接把 `error.localizedDescription` 塞進畫面。現在傳輸錯誤會被包起來並依原因分類(沒網路、連線中斷、逾時、找不到主機、主機拒絕連線),HTTP 狀態碼也一樣——包含 `429`,因為後端現在真的會限流。無法辨識的狀態碼會把數字留在訊息裡,讓沒預期到的失敗至少講得出名字。

這件事在 local-first 時代不重要:沒有網路請求就沒有網路錯誤。接上後端之後,它變成使用者最可能看到的畫面之一。

### bundle id 與 Team ID:三個連在一起的坑

實機安裝一次踩到三個問題,值得完整記下來。

**一,`com.example.tweettweet` 註冊不到 profile。** `com.example.*` 早被其他開發者帳號佔走,Apple 直接回「not available」。改用 `io.github.cowton0627.tweettweet`——以 GitHub handle 當反向網域,對公開作品集而言唯一且不暴露私人資訊。順帶解決了另一個問題:手機上舊版是 `example.tweettweet`,bundle id 不同就是兩個 App,不再有跨 Team ID 覆蓋安裝的衝突。

**二,`security find-identity` 括號裡的不是 Team ID。** 那是憑證擁有者的 member ID。真正的 Team ID 要從簽好的產物讀:`codesign -dvv <app> 2>&1 | grep TeamIdentifier`。用錯值的症狀是 `No Account for Team "..."`,而錯誤訊息不會告訴你是拿錯了 ID 種類。

**三,Xcode 會把 `DEVELOPMENT_TEAM` 寫回 `project.pbxproj`,而它的優先序高於 xcconfig。** 所以 `Config/Signing.xcconfig` 不是靠「沒人去寫」來生效,而是必須主動確保 pbxproj 裡沒有那個 key——只要有,xcconfig 就被靜默覆蓋。這正是那個 pre-commit hook 存在的理由,而它在同一天稍早才被修好。

### xcconfig 的 file reference 不要重複宣告路徑

Xcode 開過一次專案之後,把 `Config` group 變成 `Recovered References`,並丟掉四個 xcconfig 的 file reference。原因是 group 宣告了 `path = Config`,而每個 file reference 又以 `SOURCE_ROOT` 為基準重複寫成 `Config/<檔名>`——路徑等於宣告兩次,Xcode 重新解讀時就判定檔案不存在。

改成 file reference 只寫檔名、`sourceTree = "<group>"`,相對於 group 的路徑。build 其實從頭到尾都正常(`baseConfigurationReference` 仍指得到檔案),壞掉的只有 Xcode 導覽列與每次開啟就被改寫的 pbxproj。

### 圖片:相對路徑由 repository 解析,快取存解碼後的結果

後端回傳的是 `/media/post-01.jpg` 這樣的相對路徑,不是完整網址。伺服器沒有可靠的方法知道自己被用什麼網域連上,而 quick tunnel 每次重啟都換一個;把絕對網址寫進資料庫等於把一個臨時網域烤進每一列資料。

解析放在 `RemotePostRepository` 解碼回應的當下,而不是 view 層。這樣「base URL 是什麼」這件事留在網路層邊界,下游每個顯示圖片的元件都不需要知道;也讓 `LocalPostRepository` 回傳的純檔名原封不動通過,離線路徑因此還能運作。

`RemoteImageLoader` 快取的是**解碼後的 `UIImage`,不是位元組**。URLSession 自己的快取已經能避免重複下載,但避不掉重複解碼——而 cell 每次捲動重建時,解碼才是貴的那一半。同一個 URL 的併發請求也會收斂成一次下載:一個畫面上好幾個 cell 會同時要同一張頭像。

失敗不進快取。這聽起來理所當然,但如果把 `Task` 直接留在 in-flight 表裡不清掉,一次 500 就會讓那張圖在整個 App 生命週期內都失敗。

### bundle 裡的圖片留著,它們不是殘留物

M2 的驗收標準原本寫的是「把 `Resources/` 的圖片從 bundle 移除,App 仍能正常顯示」。實際做完才發現這個標準是錯的:那些檔案是 `LocalPostRepository` 的素材,也就是沒設定後端時的離線 fallback。移除它們不會證明圖片來自後端,只會弄壞離線模式。

真正的驗收是後端的 request log——一次冷啟動產生 23 個 `/media/*.jpg` 請求,而 `PostImage` 對絕對 URL 只走遠端分支,不會回頭找 bundle。

## 2026-08-10（M3）

### 讀與寫分成兩個 protocol

`LocalPostRepository` 讀的是 App bundle,那是唯讀的。如果把 `compose()` 併進 `PostRepository`,它就得帶一個只能拋錯的方法——用型別宣稱一件做不到的事。

改成獨立的 `PostComposer`,由 factory 與 repository 一起回傳,離線時是 `nil`。「這個環境不能發文」因此是一個可以檢查的事實(`canPublish`),而不是呼叫之後才炸出來的例外。離線仍然可以發文,只是那則貼文不會離開這台裝置。

### 上傳與建立分成兩個端點

先 `POST /api/posts/media` 拿到路徑,再 `POST /api/posts` 帶那些路徑。分開的好處是重試很便宜——發文失敗不必重傳整張圖——而且同一張圖可以被多則貼文重用。

**檔名是內容的 SHA-256,不是使用者送來的檔名。** 這一個決定同時解掉三件事:呼叫端無法影響檔案落在哪裡(不可能路徑穿越,也不可能覆蓋別人的檔案)、相同內容重複上傳只佔一份、以及那個 URL 的內容永遠不會變,可以安心長期快取。

**格式由檔案開頭幾個 byte 判斷**,不看副檔名也不看 `Content-Type`——這兩者都是呼叫端隨意宣稱的。取名 `.jpg` 的 PHP 腳本被 `415` 擋下,測試有蓋。

建立貼文時,`images` 裡的每個路徑都被當成**宣稱**而非事實:不是這台伺服器實際持有的檔案就拒絕。貼文因此不可能指向 media 目錄以外的東西。

### 時間戳:instant 存檔,顯示時才變成牆上時鐘

原本的 `"2020-01-05 22:51"` 沒有時區,這沒辦法當 API 契約——伺服器無從得知那是誰的時鐘,也無從用它表達新貼文的時間。

全部改成 ISO 8601 UTC(含 bundle 內的 fixture),顯示格式交給 client。fixture 寫於台北,而台灣沒有日光節約,所以 +08:00 的轉換是無損的。

這個改動意外牽動了搜尋:`HomeSearchView` 原本拿 `post.date` 做字串比對,改成 ISO 之後搜「22:51」會找不到(存的是 UTC 的 14:51)。改用 `displayDate` 比對才符合使用者的認知。**改變一個欄位的格式,要找的不只是顯示它的地方,還有拿它做比較的地方。**

### 發文失敗不清空輸入

送出失敗時畫面留在原地、文字原封不動,只跳一個 alert。因為網路閃一下就把人寫的東西吃掉,是最糟糕的回應方式。對應的測試斷言失敗時**不會**留下一則只存在本機的貼文——否則使用者會以為發成功了。

## 2026-08-14（M4：部署）

### 免費雲端的真實選項比想像少

盤點後只有三種組合能同時滿足「免費、資料持久、不休眠」，而且沒有一個是單一服務就能做到的：Fly.io 的免費方案 2024 年就取消了，Render 免費不用信用卡但**不能掛持久磁碟**，Oracle 永久免費 VM 要自己維運。

最後拆成三個各自免費的部分:API 在 Render、資料在 Turso(libSQL,9GB 免費且不需信用卡)、圖片在 S3。這反而是比較正確的架構——應用本身無狀態,有狀態的東西各自託管,任何一塊都能單獨替換。

### Turso 的 embedded replica 不支援 transaction,這是換掉整個 driver 的原因

同步的 `libsql` 套件在本機檔案上與 better-sqlite3 幾乎完全相容,但對託管資料庫**拒絕交易**:`db.transaction()` 回 `InvalidParserState`,手動 `BEGIN`/`COMMIT` 說「沒有進行中的交易」,named parameters 則靜默地不綁值——症狀是 NOT NULL 違規,完全指不到真正的原因。

而資料完整性依賴交易(貼文與圖片必須一起落地),所以改用 `@libsql/client`。它是 async-only,資料層因此全面 async,又因為它只出 ESM 型別而專案是 CommonJS,連帶把整個專案轉成 ESM——能繞過的 legacy 解析在 TypeScript 7 會移除,與其買時間不如直接搬。

**教訓:換 driver 前先對真實環境寫探測腳本。** 本機測試全綠不代表遠端可用,而這兩者的差異全部是靜默失敗。那份 20 行的 probe 比事後從壞掉的 migration 反推便宜太多。

### 部署踩到的坑:精簡 image 沒有 CA 憑證

容器 build 成功,啟動第一秒就死於 `TLS error: no valid native root CA certificates found`。

`node:22-slim` 為了體積拿掉了系統憑證庫。Node 二進位檔內建一份 CA bundle,所以 JavaScript 的 HTTPS(包含 S3 SDK)完全正常——但 libSQL 的綁定是原生 Rust,讀的是作業系統的信任庫,於是只有資料庫連線斷掉。同一個 process 裡兩套信任來源。

這種問題在開發機上永遠看不到,因為 macOS 與桌面 Linux 一定有憑證。裝 `ca-certificates` 幾百 KB 解決。

### 金鑰外洩事故,以及窄權限的回報

驗證 S3 時我把憑證放進 shell 參數且漏了 quote,AWS CLI 的錯誤訊息把完整的 secret access key 印了出來。金鑰已撤銷更換。

損害之所以可控,是因為那把金鑰的政策只允許讀寫 `tweettweet-media` 這一個 bucket 裡 `tweettweet/` 開頭的物件——列不出 bucket、刪不掉東西、碰不到其他專案。如果當初共用了既有的金鑰,善後就不是「換一把」而是「盤點所有資產」。

**做法上的修正:憑證只透過 `node --env-file` 進入程序,不經過 shell。** 值不出現在指令參數、不出現在 history、不會被任何工具的錯誤訊息回吐。

---

## 2026-08-14（Phase 1–2：導覽與帳號）

### 發文有四個入口,是因為它被當成一個地方

下方分頁的「圖片」與左上角相機是同一段程式碼,右上角的加號與下方的「發文」也是。這不是複製貼上的疏忽——是資訊架構的錯誤:發文被建模成一個**分頁**,而分頁是「你在哪裡」,發文是「你要做什麼」。一旦它成為一個地方,每個畫面都會想給它一條路。

`AppTab` 因此刻意不含發文這個 case,並在程式碼裡寫明理由。發文改成覆蓋在當前畫面上的 sheet,只有一個入口。

同樣的判斷讓「加入圖片」從導覽層消失:選圖是寫貼文的**第一步**,不是一個目的地。移進發文畫面之後,四個入口自然塌成一個,不需要額外的規則去防止它們長回來。

### 密碼雜湊用 scrypt,不用 argon2

規劃時寫的是 argon2,實作時換掉。argon2 需要編譯原生模組,而這個部署已經有兩個脆弱點:Render 免費容器的 build 環境,以及 libSQL 的 Rust binding(見上一則 CA 憑證事故)。再加一個原生相依只是把賭注加大。

scrypt 是 Node 內建,沒有 build step。強度參數(N、r、p)連同 salt 一起寫進 hash 字串 `scrypt$N$r$p$salt$hash`,所以日後要調高成本不必動既有帳號——舊記錄用舊參數驗,下次改密碼自然升級。

**這個格式差點變成漏洞,是測試抓到的。** 一筆壞掉的記錄 `scrypt$$$` 解析後 N/r/p 都是 0、salt 與 expected 都是空 buffer,而比較兩個空 buffer 會**成功**——任何密碼都能登入。現在解析後強制檢查每個欄位都夠實在(N ≥ 2^10、salt ≥ 8 bytes、hash ≥ 32 bytes),不滿足就直接拒絕。教訓是:驗證函式的失敗路徑要當成主要路徑來測,而不是只測「正確密碼過、錯誤密碼不過」。

### 不收 email

規劃寫的是 email + password,實作只留 handle。email 的用途是找回密碼與寄通知,這個 demo 兩者都沒有;收了就只是多存一份個資、多一個外洩面。要做找回密碼時再加,那時才會有寄信的基礎設施。

登入失敗一律回同一句 401,不分「密碼錯」與「帳號不存在」——後者會把註冊過的 handle 變成可枚舉的清單。

### 未登入仍可發文

原本打算要求登入才能發文,後來改掉。這是 demo:第一次打開就被登入牆擋住的人,連 App 在做什麼都看不出來。

所以登入的意義從「能不能發文」改成「貼文掛誰的名字」——有 token 就掛自己,沒有就歸 demo 帳號。這讓登入是可觀察的(發完的貼文上就是你的名字與頭像),又不必為了展示而先註冊。

### 種子貼文分給七個假使用者

原本要全部歸給一個 seed 使用者,省事。但那樣的動態牆一眼就看得出是假的——同一個人自言自語七十則,而追蹤、按讚、回文這些之後要做的功能全都需要「別人」才成立。

七個使用者(`seed/users.json`)加一個 demo 帳號。migration v5 從既有貼文的 inline 作者欄位反推出帳號,所以線上那份資料不必重灌。

### 帳號 migration 不能重建 `posts` 表

`posts` 要加 `user_id` 外鍵,而 SQLite 改欄位的標準做法是「建新表、搬資料、丟舊表、改名」。這在這裡**不能用**:託管的 libSQL 不允許關掉外鍵檢查,而 `DROP TABLE posts` 會 cascade 進 `post_images`,把每一列圖片靜默刪光。`PRAGMA defer_foreign_keys` 沒有用,它延後的是檢查,不是 cascade。

改用 `ALTER TABLE ADD COLUMN`,並在寫 migration 之前先在 Turso 上實測 `ADD`/`DROP COLUMN` 確實不會波及子表。這個限制寫進 `src/db.ts` 的註解,因為下一個要改 `posts` 的人會直覺地伸手去拿重建法。

### Embedded replica 只在啟動時同步,所以資料庫不是即時的真相

清掉測試貼文時發現的:直接對 Turso primary 下 `DELETE` 之後,線上 API 仍然回傳那幾筆。`createDb` 只在開啟連線時呼叫一次 `db.sync()`,沒有週期性同步——執行中的伺服器讀的是自己那份本機 replica 快照。

單一實例的情況下這是對的:所有寫入都經過這個 process,replica 就是最新的。但它有兩個推論要記住:

1. **繞過 API 改資料,要重啟才看得到。** 早先「直接改 SQLite 資料列再重啟 App」的驗證之所以成立,是因為當時後端也一起重啟了。
2. **不能水平擴展。** 兩個實例各自持有 replica,A 寫的東西 B 要到重啟才知道。真要多實例就得改成直連 primary,或加上週期性 sync。

目前放著不改:Render 免費方案只跑一個實例,而閒置 15 分鐘就休眠、下次請求冷啟動,等於自帶一個上限 15 分鐘的同步週期。

---

## 2026-08-14（Phase 3：讚與追蹤）

### `is_liked` 這個欄位假設全世界只有一個人在看

`posts` 表上有 `is_liked` 與 `is_followed`,這在沒有帳號的時候不是錯的,只是把「唯一那個讀者」的狀態存進了貼文本身。有了帳號之後同一則貼文對不同人不一樣,所以它們不是貼文的屬性,是**讀者與貼文之間的關係**,改成 `likes` 與 `follows` 兩張表,查詢時用 `EXISTS` 依 viewer 算出來。

未登入時 viewer 是 null,兩個 `EXISTS` 都是 false——不是錯誤,是「你還沒按過任何東西」。未登入仍然讀得到完整 feed,這對展示比什麼都重要。

### `like_count` 留在貼文上,當作計數快取

理論上按讚數應該是 `COUNT(*)`,但 feed 一次二十則就是二十個子查詢。所以計數留在 `posts` 上,由寫入端維護,代價是它可能跟事實不符。

降低這個風險的做法是**只留一條寫入路徑**:所有增減都在 `likePost`／`unlikePost` 裡,和 `INSERT OR IGNORE` 同一個交易,而且只有在插入真的寫進去時才加。測試直接比對 `likes` 的列數與 `like_count`,因為快取會漂移正是它的本質。

`UPDATE ... MAX(0, like_count - 1)` 那個下限是防禦性的:快取一旦漂移,不該還能掉到負數去撞 CHECK 而讓整個請求失敗。

### 端點用 PUT／DELETE,而且必須可重複呼叫

按讚在描述一個**狀態**（「這個讚存在」或「不存在」）,不是一個事件。所以是 PUT 與 DELETE,不是兩個 POST。

可重複呼叫不是潔癖:使用者會連點兩下,而網路不好時 client 會重送一個回應遺失的請求。這兩件事都不該讓計數加兩次。`INSERT OR IGNORE` 回報實際寫入的列數,所以「已經按過」這個判斷不需要另外做一次存在性檢查——那個檢查本身會有競態。

### 種子資料的 `isLiked`／`isFollowed` 是刪掉,不是搬移

migration 會把舊欄位灌進 demo 帳號的關係列（它就是那個隱含的唯一讀者）,但**種子 JSON 裡的那兩個欄位直接移除**。理由是它們描述的是同一個不存在的人;要保留就得憑空幫某個假使用者製造追蹤關係。`likeCount` 留著,因為那是貼文的屬性,不是誰在看的問題。

副作用是 feed 上每個作者現在都顯示「追蹤」按鈕——這其實比較誠實,而且讓這個功能有事可做。

### App 端樂觀更新,失敗回捲

按讚要先變色再送請求,不然在慢速網路上整個 App 會像壞掉。但只更新不對帳就是在騙人,所以請求失敗時要把狀態放回去,並把錯誤丟給畫面。

兩個細節:
- **伺服器回傳的計數優先於本地推算。** 別人也在按同一則貼文,所以你按完的數字不一定是按之前加一。
- **追蹤要套用到該作者的每一則貼文**,兩個 feed 都算。追蹤的是人不是貼文,其他篇還留著「追蹤」會看起來像剛才那下沒成功。

原本這段邏輯在 `PostCell` 與 `PostDetailView` 各寫一份（而且兩份行為不一致:一個能取消追蹤,一個只能追蹤）。現在只在 `UserData` 裡有一份。

### `PostRepository` 也要帶 token

這個差點漏掉:登入之後如果 feed 請求還是匿名的,`isLiked` 永遠回 false,按讚看起來會在下次重新載入時「消失」。讀取本身不需要帳號,但**讀到的內容取決於你是誰**,所以 token 是選填參數而不是驗證要求。

### like／follow 的 router 不掛在 posts router 底下

`createPostsRouter` 只在設定了圖片儲存時才掛載——它存在的理由是上傳圖片。按讚跟圖片存在哪裡毫無關係,不該因為沒設定 S3 就消失。所以另開一個 router,兩個都掛在 `/api/posts`。Express 允許同一個路徑掛多個 router。

---

## 2026-08-14（Phase 4：回文）

### 回文的分頁游標是 comment id,不是 offset

`LIMIT ? OFFSET ?` 在一份會變動的清單上是錯的:有人在讀的同時也有人在寫,第二頁會漏掉或重複一則。游標用 comment id (`WHERE id < ?`) 就沒有這個問題,因為它指的是資料而不是位置。

**往回翻,但由舊到新顯示。** 這兩件事方向相反,一開始看起來像 bug,實際上就是一串對話真正的樣子:你從最新的到達,然後往過去走。所以查詢是 `ORDER BY id DESC LIMIT ?`（索引可以直接回答,不必掃描）,拿到之後在記憶體裡 reverse。多取一列來判斷「還有沒有更早的」,省掉第二次 COUNT。

### feed 帶的那兩則用 window function,不是每則貼文查一次

`ROW_NUMBER() OVER (PARTITION BY post_id ORDER BY id DESC)` 讓二十則貼文的回文變成一個 query。天真的做法是迴圈查二十次,而這是 feed 端點,每次冷啟動之後的第一個請求。

順帶一提這是第三個 statement 而不是 join 進主查詢:貼文已經跟 `post_images` 分開查了,回文再 join 進去會讓每則回文乘上圖片數量。

### 刪除的語意跟取消讚不一樣

Phase 3 說過按讚要可重複呼叫——取消一個從沒按過的讚不是錯誤,因為那個請求在描述一個**狀態**。

刪回文不是。它指名一個**列**,而那列不在了代表 client 拿的是過期清單。默默回成功會把這件事蓋掉,所以回 404。

刪別人的回文回 **403 不是 404**。404 這種「假裝不存在」的做法是用來避免洩漏資源存在與否的,但這則回文就在畫面上,對方剛剛才讀過——裝不知道騙不了人,也沒有東西可以保護。

### `CommentThread` 歸詳情頁,不歸 `UserData`

一串回文只在你正在看它的時候有意義。放進共用的 store 就要決定什麼時候把它丟掉,而那個決定沒有好答案。所以它是詳情頁的 `@StateObject`,離開畫面就沒了;feed 帶的那兩則存在貼文上,清單需要的起始內容從那裡來。

代價是計數要走回頭路:回文數是貼文的屬性,由伺服器決定,但 thread 是在 view 的 initialiser 裡建立的,那時候還拿不到 `UserData`。解法是 thread 用 `@Published var latestCount` 回報,畫面 `onChange` 之後寫回去——比在 init 裡塞一個 callback 乾淨。

### 回文輸入框在畫面上,不是蓋在貼文上

原本按「回應」跳出一個 sheet 把貼文整個蓋掉。FB、Threads、Instagram 都不是這樣,理由不是美感:**回文是對你看得到的東西的回應**,把它遮起來等於把被回應的對象拿走了。

所以改成詳情頁下方固定一列輸入框,回文列表在上面。刪除這類次要動作藏在長按之後——刪除很少發生,而每則回文旁邊掛一顆按鈕會變成整串裡最吵的東西。

（`TextField` 的 `axis: .vertical` 是 iOS 16 才有的,這個專案還支援 15,所以輸入框是單行。）

### 讀回文的 router 不能掛在 authSecret 底下

第一版把它跟 like/follow 一起掛進 `if (options.authSecret)`,而且還在旁邊寫了「讀回文是公開的」這句自相矛盾的註解。讀一串回文跟讀 feed 一樣公開,沒有簽章金鑰的部署也應該讀得到;寫回文才需要,那個由 router 內的 `requireSession` 擋。
