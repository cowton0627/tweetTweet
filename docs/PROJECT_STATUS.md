# Project Status

最後更新：2026-08-10（Asia/Taipei）

## 目前狀態

tweetTweet 已從純本地原型變成真正的前後端專案。動態牆由 [tweettweet-api](https://github.com/cowton0627/tweettweet-api)（Express + TypeScript + SQLite）供應，並已透過 Cloudflare Tunnel 對外，實體 iPhone 走行動網路驗收通過。沒有設定後端位址時仍讀取內建 JSON，clone 後即可離線操作的性質沒有改變。

貼文圖片也已改由後端供應，App 端做記憶體快取與併發請求去重；發文（含圖片上傳）同樣寫回後端。內建的 JSON 與圖片檔案留著，作為未設定後端時的離線 fallback。

後端已部署到雲端（https://tweettweet-api.onrender.com ），不再依賴任何一台自己的機器保持開機：API 跑在 Render，貼文資料在 Turso（libSQL），圖片在 AWS S3。網域固定，App 不需要為了追網域而重新 build。

Render 免費方案閒置 15 分鐘會休眠，冷啟動約一分鐘——示範前先打一次 `/health` 叫醒它。

## 已完成

- 推薦／熱門動態、貼文詳情、搜尋、發文與圖片選擇流程。
- `PostRepository`、本地 JSON repository、遠端 repository，以及共享 `UserData` 狀態。
- 後端動態牆 API（`GET /api/feeds/:category`），回應格式與既有 fixture 逐字相同，因此 `Post`、`PostList`、`RemotePostRepository` 均未改動。
- 後端位址透過 `Config/API.xcconfig` 與 gitignored 的本機 override 注入，未設定時退回 bundle JSON。
- 後端對外曝露前的處理：helmet、`/api/*` 流量限制、request log，以及以 hop 數表示的 proxy 信任設定。
- 網路與 HTTP 錯誤訊息依原因分類為繁體中文，不再外洩 URLSession 的英文描述。
- 圖片由後端 `/media` 供應：`PostImage` 依 reference 判斷來源，`RemoteImageLoader` 快取解碼後的圖並將同一 URL 的併發請求收斂為一次下載。
- 發文寫回後端：圖片以內容雜湊命名並去重，貼文由伺服器建立並回傳，時間戳一律為 ISO 8601 UTC、顯示時才轉本地時間。
- 簽章與 bundle id：Team ID 只存在 gitignored 的 xcconfig，`project.pbxproj` 不含該設定；bundle id 為 `io.github.cowton0627.tweettweet`。
- 深色模式與 Dynamic Type 支援。
- Simulator accessibility hierarchy 驗證，包含 VoiceOver 語意、圖片群組、custom actions、選取狀態與最大輔助字級。
- 39 個 XCTest 與 GitHub Actions build/test 流程。
- 端到端驗證：直接修改 SQLite 資料列後重啟 App，畫面內容隨之改變；把後端位址改成不存在的網域則顯示錯誤而非退回內建資料，確認畫面內容確實來自 API。
- 發文端到端驗證：在 Simulator 選相簿照片發文，後端依序收到 `POST /api/posts/media`（201）與 `POST /api/posts`（201），檔案以內容雜湊落地，App 隨即取回該圖並顯示於列表最上方。
- Private Family Network 產品 brief 與後端可行性分析；兩者仍屬探索文件，不代表已承諾的產品範圍。後端選型已不採用其中的 FastAPI 建議，理由記於 `DECISIONS.md`。

## 尚未完成

- 讚與追蹤仍是本地狀態，未持久化。
- 沒有離線佇列：未設定後端時發文只留在記憶體。
- 上傳前未降取樣：相簿原圖經 `jpegData(0.85)` 後實測仍有 2.8 MB，而顯示時最寬只到螢幕寬度。建議上傳前限制最長邊（如 2048px），在行動網路下差別明顯。
- 實體 iPhone VoiceOver 操作驗證；驗證清單見 [`ACCESSIBILITY_VALIDATION.md`](ACCESSIBILITY_VALIDATION.md)。
- 補齊全新素材版本的流程截圖或操作影片。
- `Controller/` 仍保留早期 UIKit 命名，尚未進行目錄整理。

## 建議續作順序

1. 讚與追蹤寫回後端。
2. 圖片上傳前降取樣。
4. 依 accessibility 清單完成實機 VoiceOver 測試並記錄裝置與 iOS 版本。
5. 更新 README 與本文件的驗證狀態，再補展示素材。
