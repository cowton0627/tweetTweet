//
//  Comment.swift
//  tweetTweet
//
//  A reply to a post.
//

import Foundation

struct Comment: Codable, Identifiable, Equatable {
    let id: Int
    var author: Author
    let text: String
    let date: String
    /// Whether the reader wrote it, and may therefore delete it. Decided by the
    /// server, which is the only party that knows who is asking.
    let isMine: Bool
}

extension Comment {
    /// Local wall-clock time, the same conversion `Post` does — the server
    /// sends an instant, because it cannot know which clock a reader is on.
    var displayDate: String {
        guard let instant = Comment.instantParser.date(from: date) else {
            return date
        }
        return Comment.displayFormatter.string(from: instant)
    }

    private static let instantParser: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()

    private static let displayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd HH:mm"
        return formatter
    }()
}

/// One page of a thread.
struct CommentPage: Codable {
    let list: [Comment]
    /// Whether older comments exist before the first one here.
    let hasMore: Bool
}

#if DEBUG
extension Comment {
    static let preview = Comment(
        id: 1,
        author: Author(
            handle: "ep",
            displayName: "EP",
            avatar: "avatar-01.jpg",
            vip: false
        ),
        text: "這是一則用於 Xcode Preview 的回應。",
        date: "2026-07-28T05:00:00.000Z",
        isMine: false
    )
}
#endif
