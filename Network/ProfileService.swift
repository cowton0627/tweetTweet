//
//  ProfileService.swift
//  tweetTweet
//
//  Someone's account, and what they have posted.
//

import Foundation

/// An account as its own page describes it.
struct Profile: Equatable {
    let user: Author
    let postCount: Int
    /// Adjusted locally when the reader follows or unfollows, so the number
    /// under the button agrees with the button.
    var followerCount: Int
    let followingCount: Int
    var isFollowed: Bool
    /// Whether this is the reader's own account. Reported by the server rather
    /// than worked out here: it knows who is asking, and a handle comparison
    /// is easy to get subtly wrong.
    let isMe: Bool
}

protocol ProfileService {
    func profile(forHandle handle: String, token: String?) async throws -> Profile
    func posts(byHandle handle: String, token: String?) async throws -> [Post]
}
