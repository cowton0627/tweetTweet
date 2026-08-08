# Project Status

最後更新：2026-07-31（Asia/Taipei）

## 目前狀態

tweetTweet 目前是可在 Simulator 操作的 SwiftUI 社群動態 App 原型。`main` 分支與遠端同步；最新提交為 `8e3df8c`，內容是 VoiceOver 驗證流程與清單的文件化。

## 已完成

- 推薦／熱門動態、貼文詳情、搜尋、發文與圖片選擇流程。
- `PostRepository`、本地 JSON repository、可注入的遠端 repository，以及共享 `UserData` 狀態。
- 深色模式與 Dynamic Type 支援。
- Simulator accessibility hierarchy 驗證，包含 VoiceOver 語意、圖片群組、custom actions、選取狀態與最大輔助字級。
- XCTest 與 GitHub Actions build/test 流程。
- Private Family Network 產品 brief 與後端可行性分析；兩者仍屬探索文件，不代表已承諾的產品範圍。

## 尚未完成

- 實體 iPhone VoiceOver 操作驗證；驗證清單見 [`ACCESSIBILITY_VALIDATION.md`](ACCESSIBILITY_VALIDATION.md)。
- 補齊全新素材版本的流程截圖或操作影片。
- 若未來決定接正式服務，再規劃登入、寫入 API、快取與離線策略。
- `Controller/` 仍保留早期 UIKit 命名，尚未進行目錄整理。

## 目前工作目錄注意事項

Xcode project 目前有未提交的本機簽署設定變更。公開 repository 不應提交個人 Apple Developer Team ID；後續應依專案規則改用 shared xcconfig 搭配被忽略的本機 signing 設定，並確認 Simulator 與 CI 在沒有本機設定時仍可執行。

## 建議續作順序

1. 先移除或隔離未提交的個人簽署設定，避免誤提交敏感值。
2. 連接實體 iPhone，依 accessibility 清單完成 VoiceOver 測試並記錄裝置與 iOS 版本。
3. 更新 README 與本文件的驗證狀態，再補展示素材。
