//
//  HomeSearchView.swift
//  tweetTweet
//
//  Created by Codex on 2026/5/11.
//

import SwiftUI

struct HomeSearchView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var userData: UserData
    @State private var query: String = ""

    private var posts: [Post] {
        var seen: Set<Int> = []
        let combined = userData.recommendPostList.list + userData.hotPostList.list
        let unique = combined.filter { seen.insert($0.id).inserted }

        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return unique }

        return unique.filter {
            $0.name.localizedCaseInsensitiveContains(trimmed) ||
            $0.text.localizedCaseInsensitiveContains(trimmed) ||
            $0.date.localizedCaseInsensitiveContains(trimmed)
        }
    }

    var body: some View {
        Group {
            if #available(iOS 16.0, *) {
                NavigationStack {
                    searchShell
                }
            } else {
                NavigationView {
                    searchShell
                }
                .navigationViewStyle(StackNavigationViewStyle())
            }
        }
    }

    private var searchShell: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                VStack(alignment: .leading, spacing: 10) {
                    TextField("搜尋人名、內容、日期", text: $query)
                        .textFieldStyle(RoundedBorderTextFieldStyle())

                    Text(posts.isEmpty ? "沒有找到符合的內容" : "共 \(posts.count) 則結果")
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)

                Divider()

                if posts.isEmpty {
                    VStack(spacing: 10) {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 28, weight: .regular))
                            .foregroundColor(.secondary)
                        Text("找不到內容")
                            .font(.system(size: 16, weight: .medium))
                        Text("換個關鍵字再試一次。")
                            .font(.system(size: 13))
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 56)
                } else {
                    ForEach(posts) { post in
                        NavigationLink(destination: PostDetailView(post: post)) {
                            PostCell(post: post)
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
            }
        }
        .navigationTitle("搜尋")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("完成") {
                    dismiss()
                }
            }
        }
    }
}
