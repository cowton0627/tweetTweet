//
//  CommentThread.swift
//  tweetTweet
//
//  One post's replies, while its detail screen is open.
//

import Foundation

/// Owned by the detail screen rather than by `UserData`.
///
/// A thread is only interesting while you are looking at it, and holding every
/// post's replies in the shared store would mean deciding when to let them go.
/// The feed's copy of the newest two lives on the post itself and is enough for
/// the list.
@MainActor
final class CommentThread: ObservableObject {
    @Published private(set) var comments: [Comment] = []
    @Published private(set) var hasEarlier = false
    @Published private(set) var isLoading = false
    @Published private(set) var isSending = false
    @Published var failureMessage: String?

    /// The post's comment count as the server last reported it.
    ///
    /// Published rather than handed to a callback because the thread is built
    /// in a view's initialiser, where the shared store is not reachable yet.
    /// The screen watches this and writes it back.
    @Published private(set) var latestCount: Int?

    private let postID: Int
    private let service: CommentService?

    /// Whether replies can be written at all. False with no backend, where the
    /// thread is whatever the feed already carried.
    var canWrite: Bool { service != nil }

    init(
        postID: Int,
        service: CommentService?,
        seeded: [Comment] = []
    ) {
        self.postID = postID
        self.service = service
        // Shown immediately so the screen is never blank while the first page
        // is in flight: the feed already handed over the newest few.
        self.comments = seeded
    }

    /// Loads the newest page, replacing whatever the feed seeded.
    func load(token: String?) async {
        guard let service, !isLoading else { return }
        isLoading = true
        defer { isLoading = false }

        do {
            let page = try await service.comments(
                forPost: postID,
                before: nil,
                token: token
            )
            comments = page.list
            hasEarlier = page.hasMore
        } catch {
            failureMessage = error.localizedDescription
        }
    }

    /// Loads the page before the oldest one held, for "查看先前的回應".
    func loadEarlier(token: String?) async {
        guard let service, !isLoading, let oldest = comments.first else { return }
        isLoading = true
        defer { isLoading = false }

        do {
            let page = try await service.comments(
                forPost: postID,
                before: oldest.id,
                token: token
            )
            // Prepended, because these are older than everything held.
            comments.insert(contentsOf: page.list, at: 0)
            hasEarlier = page.hasMore
        } catch {
            failureMessage = error.localizedDescription
        }
    }

    /// Posts a reply. Returns false when it did not go through, so the
    /// composer can keep what was typed.
    func send(_ text: String, token: String?) async -> Bool {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !isSending, let service else { return false }

        // A reply has to belong to someone. Offline the composer is not shown
        // at all (`canWrite` is false); signed out it is, because being told
        // what to do beats a control that is mysteriously missing.
        guard let token else {
            failureMessage = "請先到「個人」分頁登入。"
            return false
        }

        isSending = true
        defer { isSending = false }

        do {
            let (comment, count) = try await service.addComment(
                toPost: postID,
                text: trimmed,
                token: token
            )
            comments.append(comment)
            latestCount = count
            return true
        } catch {
            failureMessage = error.localizedDescription
            return false
        }
    }

    /// Removes one of the reader's own replies.
    func delete(_ comment: Comment, token: String?) async {
        guard let service, let token else { return }

        // Optimistic, like liking: the row goes as soon as it is asked for and
        // comes back if the server refuses.
        guard let index = comments.firstIndex(where: { $0.id == comment.id })
        else { return }
        comments.remove(at: index)

        do {
            let result = try await service.deleteComment(id: comment.id, token: token)
            latestCount = result.commentCount
        } catch {
            comments.insert(comment, at: index)
            failureMessage = error.localizedDescription
        }
    }
}
