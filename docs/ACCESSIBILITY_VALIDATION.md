# Accessibility Validation

最後更新：2026-07-28

## 已完成的 Simulator 驗證

驗證環境：

- iPhone 15 Simulator
- iOS 17.5
- Accessibility hierarchy snapshot
- 系統淺色／深色模式
- `accessibility-extra-extra-extra-large` 最大輔助字級

首頁 accessibility focus 順序：

1. 加入圖片
2. 推薦動態
3. 熱門動態
4. 發表新貼文
5. 依畫面順序排列的貼文
6. 推薦、熱門、搜尋、圖片、發文底部操作

已確認：

- 推薦／熱門會表達目前選取狀態。
- 貼文會一次朗讀作者、時間、內容與圖片數量。
- 純裝飾頭像與 VIP badge 不會重複進入焦點。
- 貼文圖片群組會朗讀「N 張貼文圖片」，不逐張重複。
- 貼文提供追蹤、回應、喜歡／取消喜歡 custom actions。
- 回應與喜歡會朗讀完整數量與目前狀態。
- 點選整張貼文的 hint 是「開啟貼文詳情」，不會誤用內部追蹤提示。
- 最大輔助字級下內容可垂直捲動，主要導覽仍保持可操作。
- 深色模式下文字、背景與互動狀態仍可辨識。

## 實體裝置 VoiceOver 驗證

Apple 的測試文件指出 iOS VoiceOver 無法在 Simulator 執行，完整驗證必須使用實體裝置。因此，下列項目在 iPhone 連線前保持未完成：

- [ ] 開啟 Screen Curtain，在不看畫面的情況下完成主要任務。
- [ ] 以左右滑逐項確認實際朗讀順序。
- [ ] 切換推薦／熱門，確認選取狀態與焦點位置。
- [ ] 對貼文使用 Actions rotor 執行追蹤、回應與喜歡。
- [ ] 開啟貼文詳情、返回首頁並確認焦點沒有跳到不合理位置。
- [ ] 開啟搜尋、輸入查詢、清除查詢並關閉畫面。
- [ ] 開啟發文、輸入文字、送出並確認新貼文可被讀取。
- [ ] 開啟圖片選擇器，確認圖片序號與已選取狀態。
- [ ] 在 VoiceOver 開啟時確認所有主要操作都能完成。
- [ ] 記錄 iPhone 型號、iOS 版本與測試結果。

## 完成標準

只有在上述實體裝置清單完成後，README 才應宣稱「已完成實機 VoiceOver 操作驗證」。Simulator hierarchy 與 Accessibility Inspector 適合提早發現問題，但不能取代實際 VoiceOver 手勢測試。

參考：

- [Apple：Performing accessibility testing for your app](https://developer.apple.com/documentation/Accessibility/performing-accessibility-testing-for-your-app)
- [Apple：VoiceOver evaluation criteria](https://developer.apple.com/help/app-store-connect/manage-app-accessibility/voiceover-evaluation-criteria/)
