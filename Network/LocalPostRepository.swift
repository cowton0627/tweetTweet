//
//  LocalPostRepository.swift
//  tweetTweet
//
//  Loads posts from JSON files bundled with the app.
//

import Foundation

struct LocalPostRepository: PostRepository {
    func loadRecommendPosts() -> PostList {
        loadPostListData("PostListData_recommend_1.json")
    }

    func loadHotPosts() -> PostList {
        loadPostListData("PostListData_hot_1.json")
    }
}
