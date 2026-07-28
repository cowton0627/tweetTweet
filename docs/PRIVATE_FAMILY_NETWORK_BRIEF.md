# Private Family Network：產品與後端研究 Brief

狀態：探索中，尚未承諾為 tweetTweet 的正式產品方向

來源：2026-07-28 的產品討論

目的：讓後端研究專案能獨立理解問題、評估架構，並產出可實作的技術方案。

## 一句話定位

一個沒有公開動態、沒有廣告的家庭私密空間；使用者自行決定成員、群組、每則生活紀錄的可見範圍，以及照片與影片實際存放的位置。

它不應被定位成「另一個家庭版 Instagram」，而比較接近：

> Private family control plane：平台提供身分、邀請、權限、同步與操作介面；家庭保有資料控制權，並可選擇自有雲端儲存。

## 問題與價值

家庭目前常透過即時通訊、公開社群、共享相簿或雲端資料夾交換照片與生活紀錄，但通常會遇到：

- 不同親疏關係混在同一個分享範圍。
- 精確位置、兒童照片等敏感內容容易誤分享。
- 原始資料被鎖在單一服務，匯出或轉移不直覺。
- 免費服務可能依賴廣告、行為分析或日後改變資料政策。
- 長輩需要簡單介面，管理者則需要明確的邀請與撤銷權限。

產品主張：

- 只有受邀成員能看見空間。
- 每則貼文可選擇分享給哪些群組。
- 不做公開搜尋、推薦演算法或廣告画像。
- 原始媒體可存放在家庭選擇的儲存服務。
- 使用者離開平台時能匯出完整資料。

## 市場不是空白，差異化要放對位置

FamilyAlbum、Cluster 與 Apple Shared Albums／CloudKit Sharing 已證明「私密家庭分享」存在需求。因此，單純做邀請制相簿不足以形成差異。

本方向的差異化假設是以下組合：

1. 私密家庭動態與生活紀錄，不只照片相簿。
2. 同一家庭空間內可建立多個 audience group。
3. 每則內容都有明確 ACL，而非所有家庭成員一律可見。
4. Bring Your Own Storage（BYOS），原始媒體可放在使用者自己的 Drive。
5. 可攜性與退出機制是核心功能，不是事後補上的匯出工具。
6. 以訂閱或服務費營運，不使用廣告。

真正需要驗證的產品假設：

> 家庭是否願意為「沒有廣告、私密分群、資料可以存在自己的帳戶，而且長輩也容易使用」付費？

## 建議的系統邊界

### Control Plane：由產品後端管理

後端應負責：

- 帳號、登入 session 與裝置管理。
- 家庭空間與成員邀請。
- 角色、群組與每則內容的 ACL。
- 貼文 metadata、留言、反應及排序索引。
- 推播通知與未讀狀態。
- 儲存服務的連線狀態。
- 稽核紀錄、成員移除與權限撤銷。
- 匯出工作與帳號刪除生命週期。

### Data Plane：媒體儲存

照片與影片可分階段支援：

1. 產品管理的 object storage。
2. Google Drive。
3. OneDrive。
4. Dropbox。
5. NAS／WebDAV 或其他自架儲存。

第一版只應實作一種儲存方式。多 provider 不是單純增加 adapter；每個服務都有不同的 OAuth、token、分享、縮圖、變更通知、版本與刪除語意。

## 初步資料模型

```text
User
├── id
├── profile
└── devices

FamilySpace
├── id
├── ownerID
└── storagePolicy

Membership
├── userID
├── spaceID
├── role
└── status

AudienceGroup
├── id
├── spaceID
└── members

Post
├── id
├── authorID
├── spaceID
├── text
├── placeLabel?
├── preciseLocation?       # 預設不分享
├── occurredAt
└── audienceGroupIDs

MediaAsset
├── id
├── postID
├── storageProvider
├── providerObjectID
├── contentType
├── checksum
└── encryptionMetadata?

StorageConnection
├── id
├── ownerID
├── provider
├── credentialReference
└── status
```

`Post` 不應只用一個 `familyID` 代表權限。可見性需要能回答：「這個使用者現在是否仍是某個 audience group 的有效成員？」

## BYOS 最重要的架構難題

核心問題不是上傳檔案，而是：

> 照片存在某一位家庭成員的 Drive 時，其他成員如何長期、穩定且可撤銷地讀取？

候選方案：

### A. Provider-native shared folder

由儲存擁有者把資料夾分享給家庭成員。

優點：

- Provider 自己處理檔案 ACL。
- 使用者可直接在 Drive 看見資料。

缺點：

- 每個成員可能都需要同一 provider 的帳號。
- App 內群組 ACL 與 Drive ACL 容易不一致。
- 成員退出時必須同時撤銷兩邊權限。

### B. 後端代理存取

後端持有儲存擁有者的 refresh token，驗證 App ACL 後代理讀取媒體。

優點：

- 家庭成員不必擁有相同 provider 帳號。
- App 內權限是唯一決策來源。

缺點：

- 後端持有高敏感憑證，安全與營運責任最大。
- token 撤銷、過期、rotation 與 provider outage 都會影響內容。
- 需要避免媒體經由後端形成昂貴的頻寬瓶頸。

### C. Client-side encryption

媒體上傳前加密，群組成員取得可解密的金鑰。

優點：

- 儲存 provider 與產品後端無法直接看到原始內容。

缺點：

- 成員新增／移除、裝置遺失、帳號復原與 key rotation 很複雜。
- server-side thumbnail、搜尋、內容處理及轉碼受到限制。
- 「使用者忘記密碼但仍要救回家庭回憶」會成為產品級難題。

### D. 家庭共用儲存帳號

每個 FamilySpace 指定一個共用 storage identity。

優點：

- 實作與心智模型相對簡單。

缺點：

- 共用帳密不是理想安全模型。
- 難以追蹤個人操作與乾淨撤銷單一成員。

後端研究應先選定 threat model，再比較方案；不能只以 API 串接速度決定。

## 隱私與安全底線

- 精確位置預設關閉；優先儲存地點名稱或模糊位置。
- 打卡應支援延遲發布，避免透露家庭成員即時所在位置。
- 所有查詢都必須在 server-side 驗證 space membership 與內容 ACL。
- Storage OAuth 採 least privilege，不要求讀取使用者整個 Drive。
- Refresh token 不可下放到其他家庭成員，也不可明文存進資料庫。
- 成員退出後應立即失去 metadata、媒體與快取存取權。
- 刪除要定義 tombstone、provider deletion failure 與備份保留政策。
- 需保留「誰邀請誰、誰改變分享範圍、誰移除成員」的 audit trail。
- 兒童資料、家庭照片與定位資料應視為高敏感資料。

## 建議 MVP

第一版：

- Sign in with Apple／Email 登入。
- 建立一個家庭空間。
- 邀請與移除家庭成員。
- 內建「全家」群組與自訂群組。
- 文字、照片與非精確地點紀錄。
- 發文時選擇可見群組。
- 一種媒體儲存方式。
- 動態牆、詳情、留言或簡單反應。
- 下載單筆原始檔與匯出全部資料。
- 完整帳號／家庭空間刪除流程。

第一版不做：

- 公開社群或帳號探索。
- 即時聊天。
- 多種 Drive provider。
- AI 人臉辨識或內容訓練。
- 影片編輯與複雜轉碼。
- 限時動態。
- 尚未完成 threat model 前的「端對端加密」行銷宣稱。

## 與目前 tweetTweet 的關係

可重用：

- SwiftUI feed、貼文詳情、搜尋與發文 UI。
- `PostRepository` dependency injection seam。
- async loading、error、retry 狀態。
- 本地 fixture 與測試架構。
- Accessibility、Dynamic Type 與 Dark Mode 基礎。

需要重做或擴充：

- `Post`、使用者、家庭、membership、group 與 ACL 模型。
- 真正的 API client、登入與 token lifecycle。
- 圖片識別由 bundle filename 改成 remote media descriptor。
- 本地 cache、離線 mutation queue 與 conflict policy。
- 權限變更後的畫面更新與媒體 cache 清除。

tweetTweet 應先保持為可執行的 iOS 作品集；若概念驗證成立，再決定將它演進或建立獨立產品 repo，避免研究性後端需求破壞目前可重現的 demo。

## 後端研究任務

後端研究專案應回答：

1. 第一版採 CloudKit、BaaS 或自建 API，各自的限制與退出成本是什麼？
2. `FamilySpace`、`Membership`、`AudienceGroup` 與 `PostAudience` 的授權查詢如何建模？
3. ACL 在 SQL／RLS 中如何防止跨家庭讀取與 IDOR？
4. 邀請 link 如何做到 single-use、到期、撤銷與防止轉傳濫用？
5. 成員被移除時，metadata、媒體 URL、離線 cache 與 push subscription 如何撤銷？
6. 第一個 storage provider 應選產品 object storage 還是 Google Drive？
7. 若採 Google Drive，使用 `drive.file`、app folder 或 shared folder，哪一種符合分享模型？
8. 誰持有 refresh token？如何加密、rotation、撤銷及偵測失效？
9. 大型媒體如何上傳、產生縮圖、避免重複並控制 egress 成本？
10. 使用者匯出與刪除如何涵蓋 provider 上操作失敗的情況？
11. 第一版 threat model 是否需要 E2EE？若需要，帳號復原模型是什麼？
12. 如何建立可供 iOS mock 的 OpenAPI contract 與測試 fixture？

## 初步 API 面

```text
POST   /v1/spaces
POST   /v1/spaces/{spaceID}/invitations
POST   /v1/invitations/{token}/accept
GET    /v1/spaces/{spaceID}/members
DELETE /v1/spaces/{spaceID}/members/{memberID}

POST   /v1/spaces/{spaceID}/groups
PATCH  /v1/spaces/{spaceID}/groups/{groupID}

GET    /v1/spaces/{spaceID}/feed
POST   /v1/spaces/{spaceID}/posts
GET    /v1/posts/{postID}
PATCH  /v1/posts/{postID}/audience
DELETE /v1/posts/{postID}

POST   /v1/media/upload-intents
POST   /v1/media/{mediaID}/complete

POST   /v1/storage-connections
DELETE /v1/storage-connections/{connectionID}

POST   /v1/exports
GET    /v1/exports/{exportID}
```

API contract 必須明確區分：

- authentication failure；
- space membership failure；
- audience authorization failure；
- storage provider unavailable；
- storage credential revoked；
- media still processing。

## 參考資料

- [Apple：Sharing CloudKit Data with Other iCloud Users](https://developer.apple.com/documentation/CloudKit/sharing-cloudkit-data-with-other-icloud-users)
- [Google Drive：Choose API scopes](https://developers.google.com/workspace/drive/api/guides/api-specific-auth)
- [Google Drive：Store application-specific data](https://developers.google.com/workspace/drive/api/guides/appdata)
- [Microsoft Graph：Using app folder in OneDrive and SharePoint](https://learn.microsoft.com/en-us/graph/onedrive-sharepoint-appfolder)
- [Dropbox：File Access Guide](https://developers.dropbox.com/dbx-file-access-guide)
- [FamilyAlbum：Safety and privacy](https://help.family-album.com/hc/en-us/articles/360056570294-Is-FamilyAlbum-safe)
- [Cluster：Private group sharing](https://cluster.co/)
