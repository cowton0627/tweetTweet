//
//  AccountView.swift
//  tweetTweet
//
//  One account's page — yours or anybody's.
//

import SwiftUI

/// The same screen for yourself and for someone else.
///
/// Two screens would drift apart, and the difference between them is one
/// button: you cannot follow yourself. The server says which case this is
/// (`isMe`) rather than the client comparing handles.
struct AccountView: View {
    let handle: String
    /// Shown when the reader is looking at their own page from the tab bar.
    var onSignOut: (() -> Void)?

    @EnvironmentObject private var userData: UserData
    @EnvironmentObject private var authStore: AuthStore
    @StateObject private var store: ProfileStore
    @State private var selectedPost: Post?

    init(
        handle: String,
        profileService: ProfileService? = nil,
        interactions: PostInteractions? = nil,
        onSignOut: (() -> Void)? = nil
    ) {
        self.handle = handle
        self.onSignOut = onSignOut
        _store = StateObject(
            wrappedValue: ProfileStore(
                handle: handle,
                service: profileService,
                interactions: interactions
            )
        )
    }

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 0) {
                header

                switch store.state {
                case .loading:
                    ProgressView()
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 40)
                case .failed(let message):
                    VStack(spacing: 10) {
                        Text("讀不到這個帳號")
                            .font(.subheadline.weight(.medium))
                        Text(message)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                        Button("重試") {
                            Task { await store.load(token: authStore.token) }
                        }
                        .foregroundColor(.orange)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 40)
                    .padding(.horizontal, 32)
                case .loaded:
                    if store.posts.isEmpty {
                        Text("還沒有貼文。")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 15)
                            .padding(.vertical, 24)
                    } else {
                        ForEach(store.posts) { post in
                            Button(action: { selectedPost = post }) {
                                PostCell(
                                    post: post,
                                    onComment: { selectedPost = post }
                                )
                            }
                            .buttonStyle(PlainButtonStyle())
                            .accessibilityHint("開啟貼文詳情")
                        }
                    }
                }
            }
        }
        .background(Color(.systemBackground))
        .task { await store.load(token: authStore.token) }
        .sheet(item: $selectedPost) { post in
            PostDetailView(post: post, commentService: userData.commentService)
                .environmentObject(userData)
                .environmentObject(authStore)
        }
        .alert(
            "無法完成",
            isPresented: Binding(
                get: { store.failureMessage != nil },
                set: { if !$0 { store.failureMessage = nil } }
            ),
            presenting: store.failureMessage
        ) { _ in
            Button("好", role: .cancel) {}
        } message: { message in
            Text(message)
        }
    }

    private var header: some View {
        VStack(spacing: 14) {
            PostImage(reference: store.profile?.user.avatar ?? "")
                .frame(width: 88, height: 88)
                .clipShape(Circle())
                .overlay(
                    PostVIPBadge(vip: store.profile?.user.vip ?? false)
                        .offset(x: 30, y: 30)
                )
                .accessibilityHidden(true)

            VStack(spacing: 4) {
                Text(store.profile?.user.displayName ?? handle)
                    .font(.title3.weight(.semibold))
                Text("@\(handle)")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel(
                "\(store.profile?.user.displayName ?? handle)，帳號名稱 \(handle)"
            )

            if let profile = store.profile {
                HStack(spacing: 24) {
                    count(profile.postCount, "貼文")
                    count(profile.followerCount, "追蹤者")
                    count(profile.followingCount, "追蹤中")
                }

                if profile.isMe {
                    if let onSignOut {
                        Button(role: .destructive, action: onSignOut) {
                            Text("登出")
                        }
                        .padding(.top, 2)
                    }
                } else {
                    Button(action: toggleFollow) {
                        Text(profile.isFollowed ? "已追蹤" : "追蹤")
                            .font(.subheadline.weight(.semibold))
                            .foregroundColor(profile.isFollowed ? .secondary : .orange)
                            .padding(.horizontal, 24)
                            .padding(.vertical, 8)
                            .overlay(
                                Capsule().stroke(
                                    profile.isFollowed ? Color.secondary : Color.orange,
                                    lineWidth: 1.5
                                )
                            )
                    }
                    .buttonStyle(PlainButtonStyle())
                    .padding(.top, 2)
                }
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
        .padding(.horizontal, 16)
    }

    private func count(_ value: Int, _ label: String) -> some View {
        VStack(spacing: 2) {
            Text("\(value)").font(.headline)
            Text(label).font(.caption).foregroundColor(.secondary)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(label) \(value)")
    }

    private func toggleFollow() {
        guard let profile = store.profile else { return }
        guard authStore.token != nil else {
            store.failureMessage = "請先登入。"
            return
        }
        Task { await store.setFollow(!profile.isFollowed, token: authStore.token) }
    }
}

struct AccountView_Previews: PreviewProvider {
    static var previews: some View {
        AccountView(handle: "ep")
            .environmentObject(UserData())
            .environmentObject(AuthStore(service: nil))
    }
}
