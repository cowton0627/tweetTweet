//
//  PostCell.swift
//  tweetTweet
//  Created by 鄭淳澧 on 2021/5/5.
//

import SwiftUI

struct PostCell: View {
    let post: Post
    
    var bindingPost: Post {
        userData.post(forId: post.id) ?? post
    }
    
    @State var presentComment: Bool = false
    @State private var failureMessage: String?

    @EnvironmentObject var userData: UserData
    @EnvironmentObject var authStore: AuthStore

    /// Whether this post is the reader's own. You cannot follow yourself, and
    /// the server refuses to try, so the button has no business being there.
    private var isOwnPost: Bool {
        authStore.user?.handle == post.author.handle
    }
    
    var body: some View {
        let post = bindingPost
        return VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                PostImage(reference: post.author.avatar)
                    .frame(width: 48, height: 48)
                    .clipShape(Circle())
                    .overlay(
                        PostVIPBadge(vip: post.author.vip)
                            .offset(x: 14, y: 14)
                    )
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 2) {
                    Text(post.author.displayName)
                        .font(.headline.weight(.semibold))
                        .foregroundColor(Color(red: 242 / 255, green: 99 / 255, blue: 4 / 255))
                        .lineLimit(1)
                    Text(post.displayDate)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }

                Spacer()

                if !post.isFollowed && !isOwnPost {
                    Button(action: { setFollow(true, on: post) }) {
                    Text("追蹤")
                        .font(.subheadline)
                        .foregroundColor(.orange)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .overlay(
                            Capsule()
                                .stroke(Color.orange, lineWidth: 1.5)
                        )
                    }
                    .buttonStyle(BorderlessButtonStyle())
                    .accessibilityHint("追蹤 \(post.author.displayName)")
                }
            }
            Text(post.text)
                .font(.body)
                .lineSpacing(4)
                .fixedSize(horizontal: false, vertical: true)
            
            
            if !post.images.isEmpty {
                PostImageCell(images: post.images, width: UIScreen.main.bounds.width - 30)
            }
            
            Divider()
            
            HStack(spacing: 0) {
                Spacer()
                
                PostCellToolbarButton(image: "message",
                                      text: post.commentCountText,
                                      color: .primary)
                {
//                    print("Click comment button")
                    self.presentComment =  true //點擊取消讓頁面消失
                }
                .sheet(isPresented: $presentComment) {
                    CommentInputView(post: post).environmentObject(self.userData)
                }
                .accessibilityLabel("回應，\(post.commentCount) 則")
                
                Spacer()
                
                PostCellToolbarButton(image: post.isLiked ? "heart.fill" : "heart",
                                      text: post.likeCountText,
                                      color: post.isLiked ? .red : .primary)
                {
                    setLike(!post.isLiked, on: post)
                }
                .accessibilityLabel(
                    post.isLiked
                        ? "取消喜歡，目前 \(post.likeCount) 個喜歡"
                        : "喜歡，目前 \(post.likeCount) 個喜歡"
                )
                
                Spacer()
            }
            
            Rectangle()
                .padding(.horizontal, -15)
                .frame(height: 10)
                .foregroundColor(Color(.secondarySystemBackground))
        }
        .padding(.horizontal, 15)
        .padding(.top, 15)
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
    }

    // Both of these hand the work to UserData rather than editing the post in
    // place: a like has to reach the server, be reconciled with what it says,
    // and be rolled back if it never arrives — none of which belongs in a cell.
    private func setLike(_ liked: Bool, on post: Post) {
        guard signedInOrComplain() else { return }
        Task {
            do {
                try await userData.setLike(liked, on: post.id, token: authStore.token)
            } catch {
                failureMessage = error.localizedDescription
            }
        }
    }

    private func setFollow(_ followed: Bool, on post: Post) {
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

    /// Offline the taps still work and simply never leave the device, which is
    /// what keeps the app usable with no server. Online they need an account,
    /// because there is nobody for the relationship to belong to otherwise.
    private func signedInOrComplain() -> Bool {
        guard userData.canInteract, authStore.token == nil else { return true }
        failureMessage = "請先到「個人」分頁登入。"
        return false
    }
}


struct PostCell_Previews: PreviewProvider {
    static var previews: some View {
        let post = Post.preview
        let userData = UserData(initialRecommendPosts: PostList(list: [post]))
        return PostCell(post: post)
            .environmentObject(userData)
            .environmentObject(AuthStore(service: nil))
    }
}
