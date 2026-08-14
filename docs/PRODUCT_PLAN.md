# 產品與架構規劃 v2

狀態：設計中，尚未實作
日期：2026-08-14

這份文件規劃 tweetTweet 從「單一 demo 使用者的動態牆」變成「有帳號、有互動、有回文的社群 App」。寫在動手之前，因為這個規模的變更邊寫邊想會很痛。

---

## 0. 現況盤點

三件事需要先攤開來看。

### 導覽重複，而且是同一段程式碼

`HomeView` 把完全相同的 closure 同時給了頂部與底部：

```swift
HomeTopChromeView(   onCamera: { showingSourceSheet = true },
                     onCompose: { composeDraft = ... })
HomeBottomChromeView(onCamera: { showingSourceSheet = true },   // 同一個
                     onCompose: { composeDraft = ... })          // 同一個
```

底部五個 tab 有三個是頂部已經有的：

| 底部 | 重複於 |
| --- | --- |
| 推薦 / 熱門 | 頂部分頁指示器（同一個 `leftPercent`） |
| 搜尋 | —— |
| 圖片 | 左上相機 |
| 發文 | 右上加號 |

根因不是手滑，是**沒有分層規則**：頂部與底部各自長出來，沒人決定過哪一層負責什麼。所以修法不是刪按鈕，是先定規則。

### 所有貼文屬於同一個人

`DEMO_AUTHOR` 是一個常數。伺服器建立的每一則貼文都掛在它底下，`avatar`／`name` 直接寫進 `posts` 資料列。

### `commentCount` 是死的數字

種子資料裡有 `commentCount: 2200`，但沒有任何一則回文存在。目前按下「回應」只是把數字加一，內容丟掉。

---

## 1. 導覽資訊架構

### 分層規則

先定規則，再談畫面：

- **底部 tab bar** ＝ 你**在哪個區域**。互斥的目的地，切換不丟失狀態。
- **頂部** ＝ 當前區域**內部**的分頁或動作。換區域時它應該跟著換。

一個東西只能出現在一層。

### 新結構

```
底部（5 個，固定）
  首頁    搜尋    發文    通知    個人

頂部（依區域而異）
  首頁 → [ 推薦 | 熱門 ] segmented
  其他 → 該區域自己的標題與動作
```

### 對照現況的處置

| 現有元素 | 處置 | 理由 |
| --- | --- | --- |
| 底部 推薦／熱門 | **移除** | 那不是「區域」，是首頁內的分頁，屬於頂部 |
| 頂部 加號 | **移除** | 發文是主要動作，位置在底部中央 |
| 頂部 相機 | **移除** | 見下方 |
| 底部 圖片 | **移除** | 見下方 |
| 底部 搜尋 | 保留 | |
| 底部 發文 | 保留，移到中央 | |
| —— | **新增** 通知、個人 | 有了帳號才有意義 |

### 「加入圖片」不是導覽入口

這是這一節最重要的判斷。

現在點「圖片」或相機，會先問你要哪個來源，選完**才跳到發文畫面**。所以它其實是「發文流程的第一步」，卻被放在導覽層，讓人以為那是一個可以去的地方。

正確位置是**發文畫面裡的一個按鈕**。使用者的心智模型是「我要發一則文，順便加張圖」，不是「我要去圖片區」。Threads、Instagram、Facebook 都是這樣。

改完之後發文只有一個入口，而現在有四個。

---

## 2. 資料模型

### 核心改變：互動是「關係」，不是貼文的屬性

現在 `posts` 表裡有 `is_liked` 和 `is_followed`。這隱含了一個假設：**全世界只有一個人在看**。

有了帳號之後，同一則貼文對不同人顯示不同狀態，所以它們不是貼文的欄位，而是「你和這則貼文的關係」：

```
users
  id, handle (unique), display_name, avatar, password_hash, created_at

posts
  id, user_id → users, category, position, text, date, created_at
  ⚠️ 移除 avatar / name（改由 user_id 取得）
  ⚠️ 移除 is_liked / is_followed（見下）

post_images
  post_id → posts, position, filename        （不變）

likes
  user_id → users, post_id → posts, created_at
  PRIMARY KEY (user_id, post_id)

follows
  follower_id → users, followee_id → users, created_at
  PRIMARY KEY (follower_id, followee_id)
  CHECK (follower_id <> followee_id)

comments
  id, post_id → posts, user_id → users, text, created_at
```

`like_count` 與 `comment_count` 保留在 `posts` 上作為**計數快取**，由寫入時維護。理由是 feed 每則都要算一次 `COUNT(*)` 太貴；代價是要記得同步，所以更新一律走同一個函式。

### 查詢的形狀跟著變

feed 現在需要知道「誰在看」：

```sql
SELECT p.*, u.handle, u.display_name, u.avatar,
       EXISTS(SELECT 1 FROM likes   WHERE user_id = ?viewer AND post_id = p.id) AS is_liked,
       EXISTS(SELECT 1 FROM follows WHERE follower_id = ?viewer AND followee_id = p.user_id) AS is_followed
  FROM posts p
  JOIN users u ON u.id = p.user_id
 WHERE p.category = ?
 ORDER BY p.position
```

未登入時 viewer 為 null，兩個 EXISTS 都是 false——**未登入仍然可以瀏覽**，這對展示很重要。

### ⚠️ Migration 的限制

`db.ts` 已記錄：託管的 libSQL **不允許關閉外鍵**，而 `DROP TABLE` 會 cascade 刪光 `post_images`。所以「建新表→複製→DROP→RENAME」這個模式**不能用在 `posts` 上**。

從 `posts` 移除欄位必須用 `ALTER TABLE ... DROP COLUMN`（SQLite 3.35+ 支援），或者接受欄位留著不用。實作前要先在 Turso 上驗證 `DROP COLUMN` 可用。

---

## 3. 認證

### 選型：email + password，先不做 Sign in with Apple

SIWA 對 iOS 使用者體驗更好，但它把「使用者管理」外包出去，展示不到密碼雜湊、token 生命週期這些後端該會的東西。而這個專案的目的正是展示後端。

之後要加 SIWA 不衝突——`users` 表多一個 `apple_user_id` 欄位即可。

### 決策

| 項目 | 選擇 | 理由 |
| --- | --- | --- |
| 密碼雜湊 | **argon2id** | 目前的建議預設值；bcrypt 也可以，但 argon2 是 OWASP 現行推薦 |
| Token | **JWT access token**，14 天 | 展示規模不需要 refresh token 的複雜度，但要在文件寫明這是刻意簡化 |
| 儲存（iOS） | **Keychain** | 絕不能用 UserDefaults，那是明文 |
| 傳輸 | `Authorization: Bearer <token>` | |
| 未登入 | **可讀不可寫** | demo 要能被打開來看 |

### 需要防的事

- **註冊與登入端點要限流**，比現在的 300/15min 嚴格得多（暴力破解）
- 登入失敗**不能區分**「帳號不存在」與「密碼錯誤」（避免帳號枚舉）
- `handle` 要有格式限制與保留字（`admin`、`api`…）

---

## 4. API 契約

### 新增

```
POST   /api/auth/register     { handle, displayName, password }  → { token, user }
POST   /api/auth/login        { handle, password }               → { token, user }
GET    /api/auth/me                                              → { user }

GET    /api/users/:handle                                        → { user, isFollowed, postCount }
GET    /api/users/:handle/posts                                  → { list: [...] }
POST   /api/users/:handle/follow                                 → 204
DELETE /api/users/:handle/follow                                 → 204

POST   /api/posts/:id/like                                       → { likeCount, isLiked }
DELETE /api/posts/:id/like                                       → { likeCount, isLiked }

GET    /api/posts/:id/comments?limit&before                      → { list: [...], hasMore }
POST   /api/posts/:id/comments  { text }                         → { comment }
DELETE /api/comments/:id                                         → 204   （只能刪自己的）
```

### 既有端點的形狀改變

`PostDto` 的 `avatar`／`name` 改成巢狀的作者物件：

```json
{
  "id": 1000,
  "author": { "handle": "ep", "displayName": "EP", "avatar": "/media/avatar-01.jpg", "vip": true },
  "text": "…",
  "images": ["/media/post-01.jpg"],
  "date": "2020-01-05T14:51:00.000Z",
  "likeCount": 11319,
  "commentCount": 2200,
  "isLiked": false,
  "isFollowed": false,
  "recentComments": [ … ]
}
```

**這是破壞性變更**，iOS 的 `Post` 要跟著改。既然要破壞，就一次改到位。

### feed 要不要帶回文？

要，帶最新 2 則。理由是 FB 與 Threads 都這樣做——回文是內容的一部分，不是點進去才存在的東西。代價是 feed 查詢多一個 join，以及要決定排序（採最新 2 則，展開後改為由舊到新）。

---

## 5. iOS 結構

### 新增

```
Auth/
  AuthStore.swift          登入狀態（@Published user, token）
  KeychainStore.swift      token 存取
  LoginView.swift
  RegisterView.swift
Profile/
  ProfileView.swift        個人頁（自己或別人）
Notifications/
  NotificationsView.swift  先做空狀態即可
Comments/
  CommentListView.swift
  CommentComposer.swift    底部固定輸入列
```

### `UserData` 要拆

它現在同時管「推薦與熱門兩份清單」「載入狀態」「插入與更新」。加上個人頁的貼文、回文、通知之後會變成什麼都管的物件。

拆成：

- `FeedStore` —— 推薦／熱門
- `PostStore` —— 單一貼文與它的回文
- `AuthStore` —— 登入狀態

三者共用同一個 repository 層。

### 回文的互動：不要 action sheet

現在按「回應」跳出一個 sheet，這在 FB／Threads 都不是這樣。

**採用的模式**：點貼文進入詳情頁 → 回文列表在下方 → **底部固定一列輸入框**（跟隨鍵盤上推）。這是 FB、Threads、Instagram 一致的做法，因為它讓「讀回文」和「寫回文」在同一個畫面，不需要切換脈絡。

長按或右滑一則回文才出現刪除等次要動作。

---

## 6. 實作順序

每個階段結束時 App 都要是可用的。

**Phase 1 — 導覽重整** ✅ 已完成
照第 1 節重排。通知與個人先放空狀態畫面。發文入口收斂成一個。

**Phase 2 — 帳號** ✅ 已完成
`users` 表、註冊／登入、JWT、Keychain、登入畫面、未登入可讀。
種子貼文分給七個假使用者（不是同一個），feed 才看起來像真的。

實際與規劃的差異：
- **argon2 換成 scrypt**。argon2 要編譯原生模組，Render 的免費容器與
  Turso 的 Rust binding 已經讓 build 夠脆弱了；scrypt 是 Node 內建，
  參數（N、r、p）直接寫進 hash 字串，日後要調強度不必動既有帳號。
- **沒有 email**。註冊只要 handle + 顯示名稱 + 密碼。email 的用途是找回
  密碼與通知，這個 demo 兩者都沒有，收了只是多存一份個資。
- **未登入仍可發文**，會歸到 demo 帳號。原本打算擋，但那會讓沒帳號的人
  連 App 在做什麼都看不出來。登入的意義改成「貼文掛你的名字」。

**Phase 3 — 互動移到關聯表**（一到兩天）← 下一步
`likes`、`follows`，feed 查詢加入 viewer。
⚠️ `ALTER TABLE posts DROP COLUMN` 已在 Turso 上驗證可用（v5 migration 走過
一次，`post_images` 沒被波及）。

**Phase 4 — 回文**（兩天）
`comments` 表、端點、詳情頁列表、底部輸入列、feed 帶最新 2 則。

**Phase 5 — 個人頁與通知**（兩天）
個人頁（自己／別人、追蹤按鈕、該使用者的貼文）。通知需要另一份設計，先不做。

---

## 7. 未決事項

- **通知**要做到什麼程度？真正的推播需要 APNs 憑證與裝置 token 管理，是獨立的一塊。先做「站內通知列表」還是整個延後？
- **OpenAPI spec**：端點從 4 個變成十幾個之後，iOS 與後端對契約的理解會開始漂移。要不要導入 spec-first？
- **圖片降取樣**（已知問題）：相簿原圖經 JPEG 編碼後實測 2.8 MB。要排進哪個階段？
- ~~**既有種子資料**的作者要怎麼分配？~~ 已決定：七個假使用者，見 `seed/users.json`。

---

## 8. 明確不做的事

- **推播通知**（APNs）：需要付費開發者帳號與憑證管理，與本專案要展示的東西無關
- **即時更新**（WebSocket）：feed 靠下拉刷新就夠
- **私訊**：完全獨立的功能領域
- **Refresh token 輪替**：14 天的 access token 對展示足夠，但要在文件寫明這是刻意簡化，不是沒想到
