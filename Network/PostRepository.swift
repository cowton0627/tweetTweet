//
//  PostRepository.swift
//  tweetTweet
//

import Foundation

protocol PostRepository {
    func loadRecommendPosts() async throws -> PostList
    func loadHotPosts() async throws -> PostList
}
