# tweetTweet

`tweetTweet` 是一個以 SwiftUI 實作的社群動態 App 原型，提供推薦與熱門兩種貼文情境，展示動態流、貼文詳情、發文與搜尋畫面。

## 專案簡介

這個 App 以社群動態頁為主軸，啟動後會進入首頁，使用者可以在不同分頁之間切換，快速查看動態流在不同資料來源下的 UI 呈現。

目前支援兩種展示分頁：

- 推薦動態
- 熱門動態

## 主要功能

- 推薦 / 熱門雙分頁動態流
- 動態列表與貼文卡片
- 貼文詳情頁與留言互動
- 追蹤、喜歡、回應等本地狀態更新
- 貼文內容即時搜尋
- 發文流程與圖片選擇
- 列表到底狀態提示
- 自訂導覽列與 chrome 元件

## 技術內容

- Swift 5
- SwiftUI
- MVVM 基本分層
- 本地 JSON 資料載入
- 自訂 View、Navigation Bar、Toolbar Button、Image Cell
- `ObservableObject` 與 `@Published` 管理本地狀態

## 資料來源

專案使用本地 JSON 作為展示資料：

- `Resources/PostListData_recommend_1.json`
- `Resources/PostListData_hot_1.json`

圖片與頭像素材也放在 `Resources/` 底下，App 啟動時會從 bundle 內讀取。

## 專案結構

```
tweetTweet/
├── Controller/
│   ├── Friend/
│   ├── Main/
│   ├── MainTabBarController/
│   └── Scenario/
├── Model/
├── Network/
├── View/
│   ├── Customised/
│   └── TableViewCell/
├── ViewModel/
├── Extension/
└── Resources/
```

各層責任：

- `Controller/Main`：首頁、分頁、搜尋、貼文詳情與發文流程
- `Controller/Scenario`：App 啟動與 Scene 設定
- `Model`：純資料結構與資料載入邏輯
- `Network`：之後接 API 時放網路層
- `View/Customised`：共用 SwiftUI 元件與 chrome
- `View/TableViewCell`：可重複使用的貼文卡片
- `ViewModel`：本地資料狀態、鍵盤狀態等
- `Extension`：共用 extension 與工具方法
- `Resources`：本地種子資料與圖片素材

## 執行環境

- Xcode 16 或以上
- iOS 15.0 或以上
- Swift 5

## 如何執行

1. 開啟 `tweetTweet.xcodeproj`
2. 選擇 iOS Simulator
3. 執行 `tweetTweet` scheme

建議使用較新的 iPhone Simulator,例如:

- iPhone 17 Pro Max

## 備註

此專案主要作為 UI 與資料狀態展示用途,並非完整社群服務 App。畫面、資料與操作流程皆以展示社群動態頁情境為主,後續若要接後端 API,可直接替換 `Network` 與 `ViewModel` 層,UI 不需重寫。

## 授權與隱私

- 程式碼採用 [MIT License](LICENSE)。
- 本 App 不收集任何使用者資料,詳見 [PRIVACY.md](PRIVACY.md)。
- `Resources/` 內的部分圖片素材僅作為展示用途,版權仍屬原作者所有。
