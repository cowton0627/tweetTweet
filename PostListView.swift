//
//  PostListView.swift
//  tweetTweet
//  Created by 鄭淳澧 on 2021/5/7.
//

import SwiftUI

struct PostListView: View { //顯示推特列表
    let category: PostListCategory

    @EnvironmentObject var userData: UserData
    @State private var bottomState: BottomState = .idle
    @State private var didTriggerEndCheck: Bool = false

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                let posts = userData.postList(for: category).list

                ForEach(Array(posts.enumerated()), id: \.element.id) { index, post in
                    NavigationLink(destination: PostDetailView(post: post)) {
                        PostCell(post: post)
                    }
                    .buttonStyle(PlainButtonStyle())    //避免 NavigationLink 的整個 cell 顯示成藍色
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
        .background(Color(.systemBackground))
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
                .font(.system(size: 14))
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
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
