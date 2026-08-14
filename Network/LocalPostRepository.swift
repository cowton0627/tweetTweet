//
//  LocalPostRepository.swift
//  tweetTweet
//
//  Loads posts from JSON files bundled with the app.
//

import Foundation

struct LocalPostRepository: PostRepository {
    func loadRecommendPosts(token: String?) async throws -> PostList {
        try loadPostListData("PostListData_recommend_1.json")
    }

    func loadHotPosts(token: String?) async throws -> PostList {
        try loadPostListData("PostListData_hot_1.json")
    }
}
