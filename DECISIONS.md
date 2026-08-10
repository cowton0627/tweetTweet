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
