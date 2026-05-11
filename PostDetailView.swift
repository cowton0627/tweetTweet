//
//  PostDetailView.swift
//  tweetTweet
//  Created by 鄭淳澧 on 2021/5/7.
//

import SwiftUI

struct PostDetailView: View {
    let post: Post
    
    @EnvironmentObject private var userData: UserData
    @State private var showingCommentInput = false

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0) {
                    PostCell(post: post)

                    Divider()

                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text("回應")
                                .font(.system(size: 17, weight: .semibold))
                            Spacer()
                            Text(post.commentCountText)
                                .font(.system(size: 15))
                                .foregroundColor(.secondary)
                        }

                        if post.commentCount == 0 {
                            VStack(alignment: .leading, spacing: 6) {
                                Text("這則貼文還沒有回應")
                                    .font(.system(size: 15, weight: .medium))
                                Text("按右上角或底部按鈕開始回應。")
                                    .font(.system(size: 13))
                                    .foregroundColor(.secondary)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.vertical, 8)
                        }
                    }
                    .padding(.horizontal, 15)
                    .padding(.vertical, 16)
                }
            }
            .background(Color(.systemBackground))

            Divider()

            Button(action: { showingCommentInput = true }) {
                Label("回應這則貼文", systemImage: "message")
                    .frame(maxWidth: .infinity)
            }
            .font(.system(size: 16, weight: .medium))
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Color(.systemBackground))
            .buttonStyle(BorderlessButtonStyle())
        }
        .navigationBarTitle("詳情", displayMode: .inline)
        .sheet(isPresented: $showingCommentInput) {
            CommentInputView(post: post)
                .environmentObject(userData)
        }
    }
}


struct PostDetailView_Previews: PreviewProvider {
    static var previews: some View {
        let userData = UserData()
        return NavigationView {
            PostDetailView(post: userData.recommendPostList.list[0])
        }
        .environmentObject(userData)
    }
}
