//
//  PostCellToolbarButton.swift
//  tweetTweet
//  Created by 鄭淳澧 on 2021/5/6.
//

import SwiftUI

struct PostCellToolbarButton: View {
    let image: String
    let text: String
    let color: Color
    let action: () -> Void  //closure, just like func ; 各種值在下方預覽處輸入
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 5) {
                Image(systemName: image)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 18, height: 18)
                Text(text)
                    .font(.system(size: 16))
            }
        }
        .foregroundColor(color)
        .buttonStyle(BorderlessButtonStyle())   //點擊按鈕變成淺灰色效果 ;似乎不是這樣
    }
}


struct PostCellToolbarButton_Previews: PreviewProvider {
    static var previews: some View {
        PostCellToolbarButton(image: "heart", text: "喜歡", color: .red) {
            print("喜歡")
        }
    }
}
