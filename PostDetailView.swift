//
//  PostDetailView.swift
//  tweetTweet
//  Created by 鄭淳澧 on 2021/5/7.
//

import SwiftUI

struct PostDetailView: View {
    let post: Post
    
    var body: some View {
        List {
            PostCell(post: post)
                .listRowInsets(EdgeInsets())        //Insets 上下左右的間距
            
            ForEach(1...10, id: \.self) { i in
                Text("回應\(i)")
            }
        }
        .navigationBarTitle("詳情", displayMode: .inline) //inline 只顯示小標題
    }
}


struct PostDetailView_Previews: PreviewProvider {
    static var previews: some View {
        let userData = UserData()
//        PostDetailView(post: postList.list[0])
        return PostDetailView(post: userData.recommendPostList.list[0]).environmentObject(userData)
    }
}
