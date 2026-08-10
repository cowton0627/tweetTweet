# Project Status

最後更新：2026-08-10（Asia/Taipei）

## 目前狀態

tweetTweet 已從純本地原型變成真正的前後端專案。動態牆由 [tweettweet-api](https://github.com/cowton0627/tweettweet-api)（Express + TypeScript + SQLite）供應，並已透過 Cloudflare Tunnel 對外，實體 iPhone 走行動網路驗收通過。沒有設定後端位址時仍讀取內建 JSON，clone 後即可離線操作的性質沒有改變。

貼文圖片目前仍來自 App bundle，是刻意保留的過渡狀態。

後端目前掛在一台 Windows 機器上，用臨時 quick tunnel 對外，網域重啟即失效。要長時間可用需把後端與 cloudflared 都做成開機自啟；長期方案是部署到雲端。

## 已完成

- 推薦／熱門動態、貼文詳情、搜尋、發文與圖片選擇流程。
- `PostRepository`、本地 JSON repository、遠端 repository，以及共享 `UserData` 狀態。
- 後端動態牆 API（`GET /api/feeds/:category`），回應格式與既有 fixture 逐字相同，因此 `Post`、`PostList`、`RemotePostRepository` 均未改動。
- 後端位址透過 `Config/API.xcconfig` 與 gitignored 的本機 override 注入，未設定時退回 bundle JSON。
- 後端對外曝露前的處理：helmet、`/api/*` 流量限制、request log，以及以 hop 數表示的 proxy 信任設定。
- 網路與 HTTP 錯誤訊息依原因分類為繁體中文，不再外洩 URLSession 的英文描述。
- 簽章與 bundle id：Team ID 只存在 gitignored 的 xcconfig，`project.pbxproj` 不含該設定；bundle id 為 `io.github.cowton0627.tweettweet`。
- 深色模式與 Dynamic Type 支援。
- Simulator accessibility hierarchy 驗證，包含 VoiceOver 語意、圖片群組、custom actions、選取狀態與最大輔助字級。
- 21 個 XCTest 與 GitHub Actions build/test 流程。
- 端到端驗證：直接修改 SQLite 資料列後重啟 App，畫面內容隨之改變；把後端位址改成不存在的網域則顯示錯誤而非退回內建資料，確認畫面內容確實來自 API。
- Private Family Network 產品 brief 與後端可行性分析；兩者仍屬探索文件，不代表已承諾的產品範圍。後端選型已不採用其中的 FastAPI 建議，理由記於 `DECISIONS.md`。

## 尚未完成

- 貼文圖片改由後端供應：`Model/Post.swift` 的 `loadImage(name:)` 目前同步回傳 `Image`，需改為非同步載入與快取，連帶影響 `PostImageCell`、`PostCell`、`HScrollView`。
- 發文寫回後端（含圖片上傳）；`ComposePostView` 現在只寫入記憶體。
- 讚與追蹤仍是本地狀態，未持久化。
- 實體 iPhone VoiceOver 操作驗證；驗證清單見 [`ACCESSIBILITY_VALIDATION.md`](ACCESSIBILITY_VALIDATION.md)。
- 補齊全新素材版本的流程截圖或操作影片。
- `Controller/` 仍保留早期 UIKit 命名，尚未進行目錄整理。

## 建議續作順序

1. 圖片改由後端供應，完成 App 端的非同步圖片載入與快取（工程量最大的一段）。
2. 發文寫回後端，含圖片上傳。
3. 後端 Docker 化並部署到雲端，讓展示不依賴特定機器保持開機。
4. 依 accessibility 清單完成實機 VoiceOver 測試並記錄裝置與 iOS 版本。
5. 更新 README 與本文件的驗證狀態，再補展示素材。
