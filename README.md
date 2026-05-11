# tweetTweet

`tweetTweet` 是一個用 SwiftUI 製作的 iOS 社群動態 App 原型，重點在貼文瀏覽、左右分頁切換、搜尋、發文與貼文詳情互動。  
目前專案以本地資料與本地狀態為主，方便先把介面、流程與資料結構整理清楚，再接後端 API。

## 主要功能

- 推薦 / 熱門雙分頁動態流
- 貼文詳情頁
- 追蹤、喜歡、回應等互動
- 搜尋貼文內容
- 圖片選擇與發文
- 底部列表到底狀態提示
- 本地種子資料與圖片資源

## 專案結構

- `HomeView.swift`
  - 首頁 shell，負責整體狀態協調與 sheet 顯示
- `HomeChromeViews.swift`
  - 首頁上方與下方的操作列
- `HomeFeedPagerView.swift`
  - 左右分頁容器，切換推薦與熱門
- `PostListView.swift`
  - 貼文列表與底部狀態
- `PostDetailView.swift`
  - 貼文詳情與互動
- `ComposePostView.swift`
  - 發文流程
- `MediaPickerView.swift`
  - 圖片選擇
- `HomeSearchView.swift`
  - 搜尋 sheet
- `UserData.swift`
  - 本地資料與貼文更新邏輯
- `Post.swift`
  - 資料模型與圖片載入
- `Resources/`
  - 種子 JSON、頭像、貼文圖片

## 執行方式

1. 用 Xcode 開啟 `tweetTweet.xcodeproj`
2. 選擇 `tweetTweet` scheme
3. 在 Simulator 或真機上執行

建議使用 iPhone Simulator 測試。專案目前支援的最低版本是 iOS 15。

## 資料來源

目前畫面上的內容來自本地 JSON：

- `Resources/PostListData_recommend_1.json`
- `Resources/PostListData_hot_1.json`

圖片與頭像也都放在 `Resources/` 底下，App 啟動時會複製到 bundle 內可讀取的位置。

## 架構說明

這個專案目前的切法是：

- `UserData` 管理貼文集合與更新
- `HomeView` 管理首頁狀態與各種 sheet
- `PostListView` 只負責列表顯示
- `PostDetailView` 負責單篇貼文與動作
- `ComposePostView`、`MediaPickerView`、`HomeSearchView` 各自處理單一流程

這樣做的目的，是先把 UI、資料與流程拆開，後續接 API 時可以直接替換資料層，而不用整個首頁重寫。

## 目前限制

- 目前仍是本地資料，還沒有接後端 API
- 發文、追蹤、喜歡、回應都先以本地狀態更新
- 搜尋是本地貼文集合內搜尋

## 備註

如果之後要接 API，建議先把以下幾層拆出來：

- API client
- feed repository
- post detail repository
- compose / upload service

這樣 UI 就可以保留，資料來源只換實作。
