//
//  ComposeTests.swift
//  tweetTweetTests
//

import XCTest
@testable import tweetTweet

@MainActor
final class ComposeTests: XCTestCase {

    // Offline there is no composer, and composing has to keep working —
    // it simply never leaves the device.
    func testComposesLocallyWithoutABackend() async throws {
        let userData = UserData(repository: EmptyRepository())

        try await userData.compose(text: "離線也要能寫", images: [], into: .recommend)

        let posts = userData.postList(for: .recommend).list
        XCTAssertEqual(posts.map(\.text), ["離線也要能寫"])
        XCTAssertFalse(userData.canPublish)
    }

    func testLocalPostCarriesAnInstantNotAWallClock() async throws {
        let userData = UserData(repository: EmptyRepository())

        try await userData.compose(text: "hi", images: [], into: .recommend)

        let date = try XCTUnwrap(userData.postList(for: .recommend).list.first?.date)
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        XCTAssertNotNil(formatter.date(from: date), "not an instant: \(date)")
    }

    func testPublishesThroughTheComposerAndShowsWhatTheServerReturned() async throws {
        let composer = SpyComposer()
        composer.result = Post(
            id: 900,
            author: Author(
                handle: "me",
                displayName: "我",
                avatar: "https://example.test/media/avatar-01.jpg",
                vip: false
            ),
            date: "2026-08-10T11:01:47.436Z",
            isFollowed: true,
            text: "伺服器記下的版本",
            images: [],
            commentCount: 0,
            likeCount: 0,
            isLiked: false
        )
        let userData = UserData(repository: EmptyRepository(), composer: composer)

        try await userData.compose(text: "送出去", images: [], into: .recommend)

        XCTAssertTrue(userData.canPublish)
        XCTAssertEqual(composer.composedText, "送出去")
        // The post shown is the server's record, not a local guess: the id and
        // timestamp only exist server-side.
        XCTAssertEqual(userData.postList(for: .recommend).list.map(\.id), [900])
        XCTAssertEqual(
            userData.postList(for: .recommend).list.first?.text,
            "伺服器記下的版本"
        )
    }

    // A picture already on the server costs no bandwidth to reuse; only a
    // freshly taken photo has to be uploaded.
    func testUploadsOnlyImagesTheServerDoesNotHave() async throws {
        let composer = SpyComposer()
        let existing = "https://example.test/media/post-01.jpg"
        let runtimeKey = RuntimeImageStore.store(UIImage())
        let userData = UserData(repository: EmptyRepository(), composer: composer)

        try await userData.compose(
            text: "混合來源",
            images: [existing, runtimeKey],
            into: .recommend
        )

        XCTAssertEqual(composer.uploadCount, 1)
        XCTAssertEqual(composer.composedImages, [existing, "/media/uploaded.jpg"])
    }

    // A bundled filename has no counterpart on the server, so sending it would
    // create a post pointing at something that cannot be fetched.
    func testDropsReferencesWithNoServerCounterpart() async throws {
        let composer = SpyComposer()
        let userData = UserData(repository: EmptyRepository(), composer: composer)

        try await userData.compose(
            text: "只有 bundle 檔名",
            images: ["post-01.jpg"],
            into: .recommend
        )

        XCTAssertEqual(composer.uploadCount, 0)
        XCTAssertEqual(composer.composedImages, [])
    }

    // A failed send must not leave a post that only exists on this device.
    func testDoesNotInsertWhenPublishingFails() async {
        let composer = SpyComposer()
        composer.error = RemotePostRepositoryError.httpStatus(500)
        let userData = UserData(repository: EmptyRepository(), composer: composer)

        do {
            try await userData.compose(text: "會失敗", images: [], into: .recommend)
            XCTFail("Expected the failure to propagate")
        } catch {
            XCTAssertEqual(
                error.localizedDescription,
                "伺服器暫時無法回應，請稍後再試。"
            )
        }

        XCTAssertTrue(userData.postList(for: .recommend).list.isEmpty)
    }
}

private struct EmptyRepository: PostRepository {
    func loadRecommendPosts(token: String?) async throws -> PostList { PostList(list: []) }
    func loadHotPosts(token: String?) async throws -> PostList { PostList(list: []) }
}

private final class SpyComposer: PostComposer {
    var result: Post?
    var error: Error?
    private(set) var uploadCount = 0
    private(set) var composedText: String?
    private(set) var composedImages: [String] = []

    func upload(_ image: UIImage) async throws -> String {
        uploadCount += 1
        return "/media/uploaded.jpg"
    }

    private(set) var composedToken: String?

    func compose(
        text: String,
        images: [String],
        category: PostListCategory,
        token: String?
    ) async throws -> Post {
        if let error { throw error }
        composedText = text
        composedImages = images
        composedToken = token
        return result ?? Post(
            id: 1,
            author: Author(handle: "n", displayName: "n", avatar: "a", vip: false),
            date: "2026-08-10T00:00:00.000Z",
            isFollowed: true,
            text: text,
            images: images,
            commentCount: 0,
            likeCount: 0,
            isLiked: false
        )
    }
}
