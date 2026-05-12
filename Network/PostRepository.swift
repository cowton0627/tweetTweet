//
//  PostRepository.swift
//  tweetTweet
//

import Foundation

protocol PostRepository {
    func loadRecommendPosts() -> PostList
    func loadHotPosts() -> PostList
}
