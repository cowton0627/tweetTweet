//
//  CommentInputView.swift
//  tweetTweet
//  Created by 鄭淳澧 on 2021/5/24.
//

import SwiftUI

struct CommentInputView: View {
    let post: Post
    
    @State private var text: String = ""
    @State private var showEmptyTextHUD: Bool = false   //顯示hud提示語
    
    @Environment(\.presentationMode) var presentationMode
    
    @EnvironmentObject var userData: UserData
    
    @ObservedObject private var keyboardResponder = KeyboardResponder()
    
    var body: some View {
        VStack(spacing: 0) {
//            CommentTextView(text: $text)
            CommentTextView(text: $text, beginEdittingOnAppear: true)
            
            HStack(spacing: 0) {
                Button(action: {
    //                print("Cancel")
                    self.presentationMode.wrappedValue.dismiss()
                }) {
                    Text("取消").padding()
                }
                
                Spacer()
                
                Button(action: {
                    if self.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {  //過濾空白符號
//                        withAnimation {
                            self.showEmptyTextHUD = true
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                            self.showEmptyTextHUD = false
                        }
                            return
//                        }
                    }
                    print(self.text)
    //                print("Send")
                    var post = self.post
                    post.commentCount += 1
                    self.userData.update(post)
                    self.presentationMode.wrappedValue.dismiss()
                }) {
                    Text("傳送").padding()
                }
            }
            .font(.system(size: 18))
            .foregroundColor(.black)
        }
        .overlay(
            Text("評論不得空白")
                .scaleEffect(showEmptyTextHUD ? 1 : 0.5)
                .animation(.spring(dampingFraction: 0.75))
                .opacity(showEmptyTextHUD ? 1 : 0)
                .animation(.easeInOut)
        )
        .padding(.bottom, keyboardResponder.keyboardHeight)
        .edgesIgnoringSafeArea(keyboardResponder.keyboardShow ? .bottom : [])   //如果輸入時, 忽略底部安全區域, 使取消、輸入按鈕 與 鍵盤之間的間隙縮小 ;如果消失時, 不忽略安全區域
        

    }
}

struct CommentInputView_Previews: PreviewProvider {
    static var previews: some View {
        CommentInputView(post: UserData().recommendPostList.list[0])
    }
}
