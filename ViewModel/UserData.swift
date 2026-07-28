//
//  UserData.swift
//  tweetTweet
//  Created by 鄭淳澧 on 2021/5/8.
//

import Combine
import Foundation

@MainActor
final class UserData: ObservableObject {
    @Published private(set) var recommendPostList: PostList
    @Published private(set) var hotPostList: PostList
    @Published private(set) var loadStates: [PostListCategory: FeedLoadState]

    private let repository: PostRepository
    private var recommendPostDic: [Int: Int] = [:]
    private var hotPostDic: [Int: Int] = [:]

    init(
        repository: PostRepository = LocalPostRepository(),
        initialRecommendPosts: PostList? = nil,
        initialHotPosts: PostList? = nil
    ) {
        self.repository = repository
        self.recommendPostList = initialRecommendPosts ?? PostList(list: [])
        self.hotPostList = initialHotPosts ?? PostList(list: [])
        self.loadStates = [
            .recommend: Self.initialState(for: initialRecommendPosts),
            .hot: Self.initialState(for: initialHotPosts)
        ]
        rebuildIndex(for: .recommend)
        rebuildIndex(for: .hot)
    }

    func loadAll() async {
        setLoadState(.loading, for: .recommend)
        setLoadState(.loading, for: .hot)

        async let recommendRequest = repository.loadRecommendPosts()
        async let hotRequest = repository.loadHotPosts()

        do {
            apply(try await recommendRequest, to: .recommend)
        } catch {
            apply(error, to: .recommend)
        }

        do {
            apply(try await hotRequest, to: .hot)
        } catch {
            apply(error, to: .hot)
        }
    }

    func retry(_ category: PostListCategory) async {
        setLoadState(.loading, for: category)

        do {
            let posts: PostList
            switch category {
            case .recommend:
                posts = try await repository.loadRecommendPosts()
            case .hot:
                posts = try await repository.loadHotPosts()
            }
            apply(posts, to: category)
        } catch {
            apply(error, to: category)
        }
    }

    func loadState(for category: PostListCategory) -> FeedLoadState {
        loadStates[category] ?? .idle
    }

    func postList(for category: PostListCategory) -> PostList {
        switch category {
        case .recommend: return recommendPostList
        case .hot: return hotPostList
        }
    }

    func post(forId id: Int) -> Post? {
        if let index = recommendPostDic[id] {
            return recommendPostList.list[index]
        }
        if let index = hotPostDic[id] {
            return hotPostList.list[index]
        }
        return nil
    }

    func update(_ post: Post) {
        if let index = recommendPostDic[post.id] {
            recommendPostList.list[index] = post
        }
        if let index = hotPostDic[post.id] {
            hotPostList.list[index] = post
        }
    }

    func insert(_ post: Post, into category: PostListCategory, at index: Int = 0) {
        switch category {
        case .recommend:
            recommendPostList.list.insert(post, at: min(index, recommendPostList.list.count))
            setLoadState(.loaded, for: .recommend)
            rebuildIndex(for: .recommend)
        case .hot:
            hotPostList.list.insert(post, at: min(index, hotPostList.list.count))
            setLoadState(.loaded, for: .hot)
            rebuildIndex(for: .hot)
        }
    }

    func nextPostID() -> Int {
        let recommendMax = recommendPostList.list.map(\.id).max() ?? 0
        let hotMax = hotPostList.list.map(\.id).max() ?? 0
        return max(recommendMax, hotMax) + 1
    }

    func imageLibrary() -> [String] {
        var seen: Set<String> = []
        var result: [String] = []
        let names = recommendPostList.list.flatMap { [$0.avatar] + $0.images }
            + hotPostList.list.flatMap { [$0.avatar] + $0.images }
        for name in names where seen.insert(name).inserted {
            result.append(name)
        }
        return result
    }

    private static func initialState(for posts: PostList?) -> FeedLoadState {
        guard let posts else { return .idle }
        return posts.list.isEmpty ? .empty : .loaded
    }

    private func apply(_ postList: PostList, to category: PostListCategory) {
        switch category {
        case .recommend:
            recommendPostList = postList
        case .hot:
            hotPostList = postList
        }
        rebuildIndex(for: category)
        setLoadState(postList.list.isEmpty ? .empty : .loaded, for: category)
    }

    private func apply(_ error: Error, to category: PostListCategory) {
        setLoadState(.failed(message: error.localizedDescription), for: category)
    }

    private func setLoadState(_ state: FeedLoadState, for category: PostListCategory) {
        loadStates[category] = state
    }

    private func rebuildIndex(for category: PostListCategory) {
        switch category {
        case .recommend:
            recommendPostDic = Dictionary(
                uniqueKeysWithValues: recommendPostList.list.enumerated().map { ($1.id, $0) }
            )
        case .hot:
            hotPostDic = Dictionary(
                uniqueKeysWithValues: hotPostList.list.enumerated().map { ($1.id, $0) }
            )
        }
    }
}

enum FeedLoadState: Equatable {
    case idle
    case loading
    case loaded
    case empty
    case failed(message: String)
}

enum PostListCategory: String, CaseIterable {
    case recommend, hot

    var title: String {
        switch self {
        case .recommend:
            return "推薦"
        case .hot:
            return "熱門"
        }
    }
}
