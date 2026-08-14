//
//  PostDetailView.swift
//  tweetTweet
//  Created by 鄭淳澧 on 2021/5/7.
//

import SwiftUI

/// A post and its replies, on one screen.
///
/// The thread used to open in a sheet over the post. Reading and writing now
/// share the screen with what is being replied to, which is what Facebook,
/// Threads and Instagram all do — a reply is a response to what you can see,
/// and covering it up to write one throws that away.
struct PostDetailView: View {
    let post: Post

    @EnvironmentObject private var userData: UserData
    @EnvironmentObject private var authStore: AuthStore

    @StateObject private var thread: CommentThread
    @State private var draft: String = ""
    @State private var failureMessage: String?
    @State private var selectedAuthor: AuthorHandle?

    /// The service is passed in rather than reached for: choosing what talks to
    /// the network is the composition root's job, and a view that reads the
    /// configuration itself would build a fresh client every time it appears.
    /// Nil offline and in previews, where the thread is read-only.
    init(post: Post, commentService: CommentService? = nil) {
        self.post = post
        // The feed's copy of the newest replies seeds the list, so the screen
        // is never blank while the first page is in flight.
        _thread = StateObject(
            wrappedValue: CommentThread(
                postID: post.id,
                service: commentService,
                seeded: post.recentComments
            )
        )
    }

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
                    // No onComment: the thread is already below, and there
                    // is nowhere for that button to go.
                    PostCell(
                        post: post,
                        onAuthorTap: { selectedAuthor = AuthorHandle(handle: $0) }
                    )

                    Divider()

                    VStack(alignment: .leading, spacing: 16) {
                        HStack {
                            Text("回應")
                                .font(.headline)
                            Spacer()
                            Text(post.commentCountText)
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }

                        CommentListView(
                            thread: thread,
                            onLoadEarlier: {
                                Task { await thread.loadEarlier(token: authStore.token) }
                            },
                            onDelete: { comment in
                                Task { await thread.delete(comment, token: authStore.token) }
                            }
                        )
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
            }
            .font(.body.weight(.medium))
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Color(.systemBackground))
            .buttonStyle(BorderlessButtonStyle())

            if thread.canWrite {
                Divider()
                CommentComposer(
                    text: $draft,
                    isSending: thread.isSending,
                    onSend: sendComment
                )
            }
        }
        .navigationBarTitle("詳情", displayMode: .inline)
        .task {
            // The seeded replies are only the newest two; this fetches the
            // real page and replaces them.
            await thread.load(token: authStore.token)
        }
        // The server owns the count. Writing it back keeps the feed's number
        // in step with a thread the reader just changed.
        .onChange(of: thread.latestCount) { count in
            guard let count, var updated = userData.post(forId: post.id) else { return }
            updated.commentCount = count
            userData.update(updated)
        }
        .sheet(item: $selectedAuthor) { author in
            AccountView(
                handle: author.handle,
                profileService: userData.profileService,
                interactions: userData.interactionService
            )
            .environmentObject(userData)
            .environmentObject(authStore)
        }
        .alert(
            "無法完成",
            isPresented: Binding(
                get: { message != nil },
                set: { if !$0 { failureMessage = nil; thread.failureMessage = nil } }
            ),
            presenting: message
        ) { _ in
            Button("好", role: .cancel) {}
        } message: { message in
            Text(message)
        }
    }

    /// Whichever complaint is outstanding. The thread reports its own failures
    /// and the post's actions report theirs; one alert shows either.
    private var message: String? {
        failureMessage ?? thread.failureMessage
    }

    private func sendComment() {
        let text = draft
        Task {
            if await thread.send(text, token: authStore.token) {
                // Cleared only on success, so a failed send does not cost the
                // reader what they wrote. The count follows from latestCount.
                draft = ""
            }
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
