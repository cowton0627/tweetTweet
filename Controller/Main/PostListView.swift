//
//  PostListView.swift
//  tweetTweet
//  Created by 鄭淳澧 on 2021/5/7.
//

import SwiftUI

struct PostListView: View { //顯示推特列表
    let category: PostListCategory
    let onSelectPost: (Post) -> Void
    let onSelectAuthor: (String) -> Void

    @EnvironmentObject var userData: UserData
    @State private var bottomState: BottomState = .idle
    @State private var didTriggerEndCheck: Bool = false

    var body: some View {
        Group {
            switch userData.loadState(for: category) {
            case .idle, .loading:
                FeedStatusView.loading
            case .empty:
                FeedStatusView.empty
            case .failed(let message):
                FeedStatusView.error(message: message) {
                    Task {
                        await userData.retry(category)
                    }
                }
            case .loaded:
                postList
            }
        }
        .background(Color(.systemBackground))
    }

    private var postList: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                let posts = userData.postList(for: category).list

                ForEach(Array(posts.enumerated()), id: \.element.id) { index, post in
                    Button(action: {
                        onSelectPost(post)
                    }) {
                        PostCell(
                            post: post,
                            onComment: { onSelectPost(post) },
                            onAuthorTap: onSelectAuthor
                        )
                    }
                    .buttonStyle(PlainButtonStyle())
                    .accessibilityHint("開啟貼文詳情")
                    .onAppear {
                        if index == posts.count - 1 {
                            triggerBottomCheckIfNeeded()
                        }
                    }
                }

                if bottomState != .idle {
                    BottomStatusView(state: bottomState)
                        .padding(.top, 12)
                        .padding(.bottom, 24)
                }
            }
        }
    }

    private func triggerBottomCheckIfNeeded() {
        guard !didTriggerEndCheck else { return }
        didTriggerEndCheck = true
        bottomState = .loading
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.9) {
            bottomState = .ended
        }
    }
}

private struct FeedStatusView: View {
    enum Kind {
        case loading
        case empty
        case error(message: String, retry: () -> Void)
    }

    let kind: Kind

    static var loading: FeedStatusView {
        FeedStatusView(kind: .loading)
    }

    static var empty: FeedStatusView {
        FeedStatusView(kind: .empty)
    }

    static func error(message: String, retry: @escaping () -> Void) -> FeedStatusView {
        FeedStatusView(kind: .error(message: message, retry: retry))
    }

    var body: some View {
        VStack(spacing: 14) {
            switch kind {
            case .loading:
                ProgressView()
                Text("正在載入動態")
                    .font(.headline)
                Text("請稍候一下。")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            case .empty:
                Image(systemName: "tray")
                    .font(.system(size: 30))
                    .foregroundColor(.secondary)
                Text("目前沒有貼文")
                    .font(.headline)
                Text("稍後再回來看看。")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            case .error(let message, let retry):
                Image(systemName: "wifi.exclamationmark")
                    .font(.system(size: 30))
                    .foregroundColor(.secondary)
                Text("無法載入動態")
                    .font(.headline)
                Text(message)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                Button("重試", action: retry)
                    .buttonStyle(.borderedProminent)
                    .tint(.orange)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.horizontal, 28)
    }
}

private enum BottomState {
    case idle
    case loading
    case ended
}

private struct BottomStatusView: View {
    let state: BottomState

    var body: some View {
        HStack(spacing: 10) {
            if state == .loading {
                ProgressView()
            } else {
                Image(systemName: "checkmark.circle")
                    .font(.system(size: 15, weight: .semibold))
            }

            Text(state == .loading ? "載入下一批內容中" : "已經沒有更多內容了")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
    }
}


struct PostListView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            PostListView(
                category: .recommend,
                onSelectPost: { _ in },
                onSelectAuthor: { _ in }
            )
        }
        .environmentObject(
            UserData(initialRecommendPosts: PostList(list: []))
        )
    }
}
