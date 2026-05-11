//
//  PostListView.swift
//  tweetTweet
//  Created by 鄭淳澧 on 2021/5/7.
//

import SwiftUI

struct PostListView: View { //顯示推特列表
    let category: PostListCategory

    @EnvironmentObject var userData: UserData

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                ForEach(userData.postList(for: category).list) { post in
                    NavigationLink(destination: PostDetailView(post: post)) {
                        PostCell(post: post)
                    }
                    .buttonStyle(PlainButtonStyle())    //避免 NavigationLink 的整個 cell 顯示成藍色
                }
            }
        }
        .background(Color(.systemBackground))
    }
}


struct PostListView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            PostListView(category: .recommend)
        }
        .environmentObject(UserData())
    }
}
