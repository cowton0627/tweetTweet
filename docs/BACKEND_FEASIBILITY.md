# Private Family Network：後端可行性分析與技術方案

狀態：研究性評估，回應 `docs/PRIVATE_FAMILY_NETWORK_BRIEF.md`
日期：2026-07-28

本文件回答 Brief 的 12 個後端研究問題，並給出全端商品化的可行性判斷、技術棧與里程碑。立場是「先選定，再解釋」——給建議，不列選項清單。

---

## 1. 可行性總評

| 面向 | 判斷 | 關鍵理由 |
|---|---|---|
| 技術可行性 | 高 | 沒有需要突破的技術。難點（BYOS 代理、撤銷、匯出/刪除）都可延後，不影響 MVP。 |
| 產品/市場 | 中 | 賽道不空（FamilyAlbum / Cluster / CloudKit）。真正風險是「家庭願不願付費」——商業假設，不是工程問題。 |
| 工程量 | MVP 可控 | 前提是第一版砍掉 BYOS，只用產品自管 object storage。多 Drive provider 會讓範圍爆炸。 |

一句話：**技術上做得出來且不難；成敗在商業驗證。工程上最大的自我保護動作，就是 MVP 不要碰 BYOS。**

---

## 2. 12 個後端研究問題的實作立場

### Q1 Control Plane 選型 → 自建 API（Postgres 為核心），不要 CloudKit
- CloudKit 淘汰：與三個核心需求衝突——(a) BYOS 代理需後端持有第三方 token，CloudKit 沒有這位置；(b)「可攜性/低退出成本」是賣點，CloudKit 是最強 lock-in；(c) 跨平台（未來 Web/Android）幾乎不可能。
- BaaS（Supabase）是合理加速起點：本質是 Postgres + Auth + RLS + Storage，退出成本低。求快可用。
- 建議：MVP 用自管 Postgres + FastAPI + SQLAlchemy + Alembic，RLS 當防禦縱深；不綁 BaaS 專有功能，保留退出能力（這正好也是產品主張）。

### Q2 / Q3 授權模型與 RLS（整個後端的心臟）
可見性判定要能回答：「這個 user 現在是否仍是 post 所屬某個 audience group 的有效成員？」用兩張 join table：

```
GroupMembership(group_id, user_id, status)   -- 成員在群組內
PostAudience(post_id, group_id)              -- 貼文對哪些群組可見
```

一則 post 對 user 可見 ⇔
`user 是 space 的 active member` AND `EXISTS(PostAudience ∩ user 的 active GroupMembership)`。

- 防 IDOR 鐵律：後端永不信任 client 傳來的 space_id/post_id 作為授權依據，一律透過 membership join 反查。RLS policy 綁 `auth.uid()`，即使 API 層有 bug，DB 層也擋掉跨家庭讀取（defense-in-depth）。
- `Post` 不能只有一個 `familyID`——權限必須走 `PostAudience`。

### Q4 邀請 link → single-use + hash 儲存 + 到期 + 可撤銷
- DB 只存 token 的 hash（如 SHA-256），不存原文；比對時 hash 再查。
- 欄位：`space_id, role, invited_email?, expires_at, status(pending/accepted/revoked), used_at`。
- accept 端做 rate-limit；可選綁定 email 降低轉傳濫用。撤銷 = 改 status，不刪。

### Q5 成員移除的撤銷鏈 → 靠「短 TTL signed URL」讓撤銷變自然
移除時一次收掉：`Membership` + `GroupMembership` 失效 → 該 user 在此 space 的 session/device token 撤銷 → push subscription 移除 → CDN/cache 清除。
- 關鍵設計：媒體一律走短命 signed URL（分鐘級），不發長效連結。撤銷不需追殺已發出的 URL——它們很快自然過期。此設計同時簡化 Q5 + Q8。

### Q6 第一個 storage provider → 產品自管 object storage，用 Cloudflare R2
- MVP 不要 Google Drive。自管 object storage 讓 Q7/Q8/Q9 大半消失。
- 選 R2：S3 相容 + egress 免費，直接解掉 Brief 反覆擔心的 egress 成本問題。

### Q7 若日後上 Google Drive → `drive.file` scope + 後端代理（方案 B）
- least privilege 用 `drive.file`（只能碰 app 自己建立的檔案），不要 full-drive scope。
- 不要 provider-native shared folder（方案 A）——App ACL 與 Drive ACL 雙寫必然不一致、退出時要撤兩邊。以 App ACL 為唯一決策來源（方案 B）。

### Q8 refresh token 歸屬 → 後端持有，envelope encryption
- token 存後端、per-connection、envelope 加密（KMS 管 master key，加密 DEK，再加密 token），絕不明文進 DB、絕不下放給其他成員。
- rotation + 定期健康檢查偵測失效；失效時把 `StorageConnection.status` 標記並在 API 回 `storage_credential_revoked`。

### Q9 大型媒體 → presigned 直傳 + 非同步縮圖 + checksum 去重
- 上傳不經後端：client 拿 presigned multipart URL 直傳 object storage，後端只發 upload-intent、收 complete callback——避免頻寬瓶頸。
- 縮圖走非同步 worker（佇列）或 image CDN on-the-fly；回 `media_still_processing` 狀態。
- 去重靠 content checksum（content-addressable），同一張照片多人發只存一份。

### Q10 匯出/刪除 → 狀態機 async job + tombstone + 兩階段刪除
- 匯出/刪除都是非同步 job（狀態：queued/running/partial_failure/done）。
- provider 刪除失敗（Q10 核心）：軟刪先寫 tombstone，進 retry queue，狀態對使用者可見；保留窗過後才 hard delete。定義好 backup 保留政策。

### Q11 E2EE → MVP 明確不做
E2EE 與三件事直接衝突：server-side 縮圖/搜尋/轉碼、成員增刪的 key rotation、以及「長輩忘記密碼但要救回家庭回憶」的帳號復原。
- MVP 定位為「傳輸/靜態加密 + 嚴格 ACL + BYOS」，行銷不宣稱 E2EE。
- 真要做，需 per-space 內容金鑰、用成員裝置金鑰 wrap、外加 recovery key / 社交復原——列 v2+。

### Q12 契約 → OpenAPI 3.1 spec-first
spec 當單一事實來源 → 自動生成 Swift client → contract test + fixture 給 iOS mock。Brief 的錯誤分類（auth / membership / audience / storage-unavailable / credential-revoked / processing）要進 spec 當標準錯誤 enum。

---

## 3. 建議全端技術棧（MVP）

- Client：沿用現有 tweetTweet SwiftUI（feed / detail / `PostRepository` seam / async 狀態 / a11y 皆可重用）。
- API：FastAPI + SQLAlchemy + Alembic（複用既有 Python / `uv` 技能）；求快可改 Supabase。
- DB：Postgres + RLS（ACL 的防禦縱深）。
- Storage：Cloudflare R2（S3 相容、egress 免費）。
- Auth：Sign in with Apple + Email；session 用短命 access + refresh。
- Push：APNs。
- 非同步：佇列（Python 生態用 RQ/Redis 或 Postgres-based job）處理縮圖/匯出/刪除/token 健康檢查。

---

## 4. 里程碑（把 BYOS 推到最後）

1. M1 骨架：Auth + FamilySpace + Membership + 邀請/撤銷 + RLS。
2. M2 內容：AudienceGroup + Post + PostAudience + feed 授權查詢（Q2/Q3 落地）。
3. M3 媒體：R2 presigned 直傳 + async 縮圖 + 短命 signed URL（Q9）。
4. M4 生命週期：匯出 + 兩階段刪除 + tombstone（Q10）。
5. M5（v2）：Google Drive `drive.file` + 後端代理 + token envelope 加密（Q7/Q8）。

前四個里程碑是「完整可上線商品」，第五個才是差異化賣點。此順序讓你先驗證「有沒有人付費」，再投入 BYOS 的高成本。

---

## 5. 最大風險

1. 商業，不是技術：付費意願未驗證。建議 M2 完成就找真實家庭做付費意向測試，別等 BYOS。
2. BYOS 是範圍黑洞：每個 provider 的 OAuth / 分享 / 縮圖 / 變更通知 / 刪除語意都不同。務必單一 provider 起步。
3. 撤銷正確性：成員移除後仍能讀到快取/URL 會是信任災難——短命 signed URL 是關鍵護欄。
