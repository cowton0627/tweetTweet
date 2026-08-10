//
//  PostRepository.swift
//  tweetTweet
//

import UIKit

protocol PostRepository {
    func loadRecommendPosts() async throws -> PostList
    func loadHotPosts() async throws -> PostList
}

/// Publishing a post, kept apart from reading one.
///
/// `LocalPostRepository` reads from the app bundle, which cannot be written
/// to, so it genuinely has nothing to offer here — folding these methods into
/// `PostRepository` would force it to carry a method that can only throw.
protocol PostComposer {
    /// Uploads an image and returns the path the server stores it at.
    func upload(_ image: UIImage) async throws -> String

    /// Publishes a post and returns it as the server recorded it.
    func compose(
        text: String,
        images: [String],
        category: PostListCategory
    ) async throws -> Post
}
