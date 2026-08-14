//
//  PostInteractions.swift
//  tweetTweet
//
//  Liking a post and following an author.
//

import Foundation

/// A post's like state as the server reports it.
///
/// The count comes back from the server rather than being inferred locally:
/// other people are liking the same post, so the number after your tap is not
/// necessarily the number before it plus one.
struct LikeState: Equatable {
    let likeCount: Int
    let isLiked: Bool
}

/// Kept apart from `PostRepository` for the same reason `PostComposer` is: the
/// bundled-JSON repository has nothing to offer here, and folding these in
/// would force it to carry methods that can only throw.
protocol PostInteractions {
    /// Sets whether the signed-in reader likes this post.
    func setLike(_ liked: Bool, postID: Int, token: String) async throws -> LikeState

    /// Sets whether the signed-in reader follows this account.
    func setFollow(_ followed: Bool, handle: String, token: String) async throws
}
