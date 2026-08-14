//
//  CommentService.swift
//  tweetTweet
//
//  Reading and writing a post's replies.
//

import Foundation

/// What the server says after a comment is added or removed.
struct CommentMutation: Equatable {
    let commentCount: Int
}

/// Separate from `PostRepository` for the same reason `PostComposer` is: the
/// bundled JSON has no thread to read and nowhere to write one.
protocol CommentService {
    /// A page of replies, oldest first. `before` is a comment id: paging walks
    /// backwards into older replies while display runs forwards.
    func comments(
        forPost postID: Int,
        before: Int?,
        token: String?
    ) async throws -> CommentPage

    func addComment(
        toPost postID: Int,
        text: String,
        token: String
    ) async throws -> (comment: Comment, commentCount: Int)

    /// Removes one of the reader's own replies.
    func deleteComment(id: Int, token: String) async throws -> CommentMutation
}
