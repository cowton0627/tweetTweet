//
//  PostRepository.swift
//  tweetTweet
//

import UIKit

protocol PostRepository {
    /// The token is what makes `isLiked` and `isFollowed` mean anything: those
    /// describe a relationship between the reader and the post, so an
    /// anonymous request gets a feed where nothing is liked and nobody is
    /// followed. Reading itself never requires one.
    func loadRecommendPosts(token: String?) async throws -> PostList
    func loadHotPosts(token: String?) async throws -> PostList
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
    ///
    /// The token identifies the author. Without one the server attributes the
    /// post to its demo account, which is what keeps composing usable before
    /// anyone signs in.
    func compose(
        text: String,
        images: [String],
        category: PostListCategory,
        token: String?
    ) async throws -> Post
}
