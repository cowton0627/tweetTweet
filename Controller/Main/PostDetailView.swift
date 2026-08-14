//
//  PostDetailView.swift
//  tweetTweet
//  Created by 鄭淳澧 on 2021/5/7.
//

import SwiftUI

struct PostDetailView: View {
    let post: Post
    
    @EnvironmentObject private var userData: UserData
    @EnvironmentObject private var authStore: AuthStore
    @State private var showingCommentInput = false
    @State private var failureMessage: String?

    private var isOwnPost: Bool {
        authStore.user?.handle == post.author.handle
    }

    private var currentPost: Post {
        userData.post(forId: post.id) ?? post
    }

    var body: some View {
        let post = currentPost
        VStack(spacing: 0) {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0) {
                    PostCell(post: post)

                    Divider()

                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text("回應")
                                .font(.headline)
                            Spacer()
                            Text(post.commentCountText)
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }

                        if post.commentCount == 0 {
                            VStack(alignment: .leading, spacing: 6) {
                                Text("這則貼文還沒有回應")
                                    .font(.subheadline.weight(.medium))
                                Text("按右上角或底部按鈕開始回應。")
                                    .font(.caption)
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

            HStack(spacing: 12) {
                if !isOwnPost {
                    Button(action: { setFollow(!post.isFollowed, for: post) }) {
                        Label(post.isFollowed ? "已追蹤" : "追蹤", systemImage: post.isFollowed ? "checkmark.circle.fill" : "person.badge.plus")
                            .frame(maxWidth: .infinity)
                    }
                }

                Button(action: { setLike(!post.isLiked, for: post) }) {
                    Label(post.isLiked ? "已喜歡" : "喜歡", systemImage: post.isLiked ? "heart.fill" : "heart")
                        .frame(maxWidth: .infinity)
                }

                Button(action: { showingCommentInput = true }) {
                    Label("回應", systemImage: "message")
                        .frame(maxWidth: .infinity)
                }
            }
            .font(.body.weight(.medium))
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Color(.systemBackground))
            .buttonStyle(BorderlessButtonStyle())
        }
        .navigationBarTitle("詳情", displayMode: .inline)
        .alert(
            "無法完成",
            isPresented: Binding(
                get: { failureMessage != nil },
                set: { if !$0 { failureMessage = nil } }
            ),
            presenting: failureMessage
        ) { _ in
            Button("好", role: .cancel) {}
        } message: { message in
            Text(message)
        }
        .sheet(isPresented: $showingCommentInput) {
            CommentInputView(post: post)
                .environmentObject(userData)
        }
    }

    private func setLike(_ liked: Bool, for post: Post) {
        guard signedInOrComplain() else { return }
        Task {
            do {
                try await userData.setLike(liked, on: post.id, token: authStore.token)
            } catch {
                failureMessage = error.localizedDescription
            }
        }
    }

    private func setFollow(_ followed: Bool, for post: Post) {
        guard signedInOrComplain() else { return }
        Task {
            do {
                try await userData.setFollow(
                    followed,
                    forAuthor: post.author.handle,
                    token: authStore.token
                )
            } catch {
                failureMessage = error.localizedDescription
            }
        }
    }

    private func signedInOrComplain() -> Bool {
        guard userData.canInteract, authStore.token == nil else { return true }
        failureMessage = "請先到「個人」分頁登入。"
        return false
    }
}


struct PostDetailView_Previews: PreviewProvider {
    static var previews: some View {
        let post = Post.preview
        let userData = UserData(initialRecommendPosts: PostList(list: [post]))
        return NavigationView {
            PostDetailView(post: post)
        }
        .environmentObject(userData)
        .environmentObject(AuthStore(service: nil))
    }
}
