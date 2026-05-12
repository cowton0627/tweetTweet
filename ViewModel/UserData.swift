//
//  UserData.swift
//  tweetTweet
//  Created by 鄭淳澧 on 2021/5/8.
//

import Combine

class UserData: ObservableObject {
    @Published var recommendPostList: PostList
    @Published var hotPostList: PostList

    private let repository: PostRepository
    private var recommendPostDic: [Int: Int] = [:]   //id: index
    private var hotPostDic: [Int: Int] = [:]

    init(repository: PostRepository = LocalPostRepository()) {
        self.repository = repository
        self.recommendPostList = repository.loadRecommendPosts()
        self.hotPostList = repository.loadHotPosts()
        rebuildIndex(for: .recommend)
        rebuildIndex(for: .hot)
    }
}

extension UserData {
    func postList(for category: PostListCategory) -> PostList {
        switch category {
        case.recommend: return recommendPostList
        case.hot: return hotPostList
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
            rebuildIndex(for: .recommend)
        case .hot:
            hotPostList.list.insert(post, at: min(index, hotPostList.list.count))
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

    private func rebuildIndex(for category: PostListCategory) {
        switch category {
        case .recommend:
            recommendPostDic = Dictionary(uniqueKeysWithValues: recommendPostList.list.enumerated().map { ($1.id, $0) })
        case .hot:
            hotPostDic = Dictionary(uniqueKeysWithValues: hotPostList.list.enumerated().map { ($1.id, $0) })
        }
    }
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
