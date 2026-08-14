import XCTest
@testable import tweetTweet

/// The thread a detail screen owns.
@MainActor
final class CommentTests: XCTestCase {
    func testLoadReplacesWhateverTheFeedSeeded() async {
        let service = SpyCommentService()
        service.pages = [CommentPage(list: [makeComment(id: 5)], hasMore: false)]
        let thread = CommentThread(
            postID: 1,
            service: service,
            seeded: [makeComment(id: 99)]
        )
        // The seeded copy shows immediately, so the screen is never blank.
        XCTAssertEqual(thread.comments.map(\.id), [99])

        await thread.load(token: nil)

        XCTAssertEqual(thread.comments.map(\.id), [5])
        XCTAssertEqual(service.requestedBefore, [nil])
    }

    // Paging walks backwards while display runs forwards, so an older page
    // goes on the front.
    func testEarlierPageIsPrepended() async {
        let service = SpyCommentService()
        service.pages = [
            CommentPage(list: [makeComment(id: 10), makeComment(id: 11)], hasMore: true),
            CommentPage(list: [makeComment(id: 8), makeComment(id: 9)], hasMore: false)
        ]
        let thread = CommentThread(postID: 1, service: service)

        await thread.load(token: nil)
        XCTAssertTrue(thread.hasEarlier)

        await thread.loadEarlier(token: nil)

        XCTAssertEqual(thread.comments.map(\.id), [8, 9, 10, 11])
        XCTAssertFalse(thread.hasEarlier)
        // The cursor is the oldest held, not an offset.
        XCTAssertEqual(service.requestedBefore, [nil, 10])
    }

    func testSendAppendsAndReportsTheNewCount() async {
        let service = SpyCommentService()
        service.created = makeComment(id: 20, text: "回應")
        service.createdCount = 7
        let thread = CommentThread(postID: 1, service: service)

        let sent = await thread.send("回應", token: "token")

        XCTAssertTrue(sent)
        XCTAssertEqual(thread.comments.map(\.text), ["回應"])
        XCTAssertEqual(thread.latestCount, 7)
        XCTAssertEqual(service.sentText, "回應")
    }

    // The composer keeps what was typed when this returns false, so a failed
    // send does not cost the reader their words.
    func testSendReportsFailureWithoutAppending() async {
        let service = SpyCommentService()
        service.error = MockCommentError.offline
        let thread = CommentThread(postID: 1, service: service)

        let sent = await thread.send("回應", token: "token")

        XCTAssertFalse(sent)
        XCTAssertTrue(thread.comments.isEmpty)
        XCTAssertNotNil(thread.failureMessage)
    }

    func testSendRefusesWhenSignedOut() async {
        let service = SpyCommentService()
        let thread = CommentThread(postID: 1, service: service)

        let sent = await thread.send("回應", token: nil)

        XCTAssertFalse(sent)
        XCTAssertNil(service.sentText)
        XCTAssertNotNil(thread.failureMessage)
    }

    func testSendIgnoresWhitespaceOnly() async {
        let service = SpyCommentService()
        let thread = CommentThread(postID: 1, service: service)

        let sent = await thread.send("   \n ", token: "token")

        XCTAssertFalse(sent)
        XCTAssertNil(service.sentText)
    }

    func testDeleteRemovesAndReportsTheNewCount() async {
        let service = SpyCommentService()
        service.pages = [CommentPage(list: [makeComment(id: 3, isMine: true)], hasMore: false)]
        service.deletedCount = 0
        let thread = CommentThread(postID: 1, service: service)
        await thread.load(token: nil)

        await thread.delete(thread.comments[0], token: "token")

        XCTAssertTrue(thread.comments.isEmpty)
        XCTAssertEqual(thread.latestCount, 0)
    }

    // Optimistic, like liking: the row goes at once and comes back where it
    // was if the server refuses.
    func testDeleteRestoresTheRowWhenRefused() async {
        let service = SpyCommentService()
        service.pages = [
            CommentPage(
                list: [makeComment(id: 3), makeComment(id: 4, isMine: true), makeComment(id: 5)],
                hasMore: false
            )
        ]
        let thread = CommentThread(postID: 1, service: service)
        await thread.load(token: nil)
        service.error = MockCommentError.offline

        await thread.delete(thread.comments[1], token: "token")

        XCTAssertEqual(thread.comments.map(\.id), [3, 4, 5])
        XCTAssertNotNil(thread.failureMessage)
    }

    // Without a backend there is nowhere to write, and the composer is hidden
    // rather than failing when tapped.
    func testWithoutAServiceThereIsNothingToWriteWith() async {
        let thread = CommentThread(postID: 1, service: nil, seeded: [makeComment(id: 1)])

        XCTAssertFalse(thread.canWrite)
        let sent = await thread.send("回應", token: "token")
        XCTAssertFalse(sent)
        // What the feed carried is still there to read.
        XCTAssertEqual(thread.comments.map(\.id), [1])
    }
}

/// Decoding, where the field may be absent.
final class CommentDecodingTests: XCTestCase {
    func testPostDecodesWithoutRecentComments() throws {
        let json = """
        {
          "id": 1, "author": { "handle": "ep", "displayName": "EP", "avatar": "a.jpg", "vip": false },
          "date": "2026-07-28T04:00:00.000Z", "isFollowed": false, "text": "hi",
          "images": [], "commentCount": 0, "likeCount": 0, "isLiked": false
        }
        """
        // The bundled JSON predates comments, and a server one version behind
        // will not send the key. Neither is a reason to fail to show a post.
        let post = try JSONDecoder().decode(Post.self, from: Data(json.utf8))
        XCTAssertEqual(post.recentComments, [])
    }

    func testPostDecodesRecentComments() throws {
        let json = """
        {
          "id": 1, "author": { "handle": "ep", "displayName": "EP", "avatar": "a.jpg", "vip": false },
          "date": "2026-07-28T04:00:00.000Z", "isFollowed": false, "text": "hi",
          "images": [], "commentCount": 2, "likeCount": 0, "isLiked": false,
          "recentComments": [
            { "id": 7, "author": { "handle": "me", "displayName": "我", "avatar": "b.jpg", "vip": false },
              "text": "第一則", "date": "2026-07-28T05:00:00.000Z", "isMine": true }
          ]
        }
        """
        let post = try JSONDecoder().decode(Post.self, from: Data(json.utf8))
        XCTAssertEqual(post.recentComments.map(\.text), ["第一則"])
        XCTAssertTrue(post.recentComments[0].isMine)
    }
}

private enum MockCommentError: Error {
    case offline
}

private final class SpyCommentService: CommentService {
    var pages: [CommentPage] = []
    var created: Comment?
    var createdCount = 1
    var deletedCount = 0
    var error: Error?

    private(set) var requestedBefore: [Int?] = []
    private(set) var sentText: String?
    private var pageIndex = 0

    func comments(
        forPost postID: Int,
        before: Int?,
        token: String?
    ) async throws -> CommentPage {
        if let error { throw error }
        requestedBefore.append(before)
        defer { pageIndex += 1 }
        guard pageIndex < pages.count else {
            return CommentPage(list: [], hasMore: false)
        }
        return pages[pageIndex]
    }

    func addComment(
        toPost postID: Int,
        text: String,
        token: String
    ) async throws -> (comment: Comment, commentCount: Int) {
        if let error { throw error }
        sentText = text
        return (created ?? makeComment(id: 1, text: text), createdCount)
    }

    func deleteComment(id: Int, token: String) async throws -> CommentMutation {
        if let error { throw error }
        return CommentMutation(commentCount: deletedCount)
    }
}

private func makeComment(
    id: Int,
    text: String = "測試回應",
    isMine: Bool = false
) -> Comment {
    Comment(
        id: id,
        author: Author(
            handle: "ep",
            displayName: "EP",
            avatar: "avatar.jpg",
            vip: false
        ),
        text: text,
        date: "2026-07-28T05:00:00.000Z",
        isMine: isMine
    )
}
