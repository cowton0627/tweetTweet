import XCTest
@testable import tweetTweet

/// Liking and following, as `UserData` performs them.
///
/// The interesting behaviour is not the happy path but what happens either side
/// of it: the change has to land on screen before the network answers, and it
/// has to be taken back if the answer never comes.
@MainActor
final class InteractionTests: XCTestCase {
    func testLikeAppliesBeforeTheServerAnswers() async throws {
        let spy = SpyInteractions()
        spy.likeResult = LikeState(likeCount: 99, isLiked: true)
        let userData = await makeUserData(interactions: spy)

        try await userData.setLike(true, on: 1, token: "token")

        XCTAssertEqual(spy.likeCalls.count, 1)
        XCTAssertEqual(spy.likeCalls[0].liked, true)
        XCTAssertEqual(spy.likeCalls[0].postID, 1)
        XCTAssertEqual(spy.likeCalls[0].token, "token")
        // The server's count is what sticks, not the local guess of 10 + 1.
        XCTAssertEqual(userData.post(forId: 1)?.likeCount, 99)
        XCTAssertEqual(userData.post(forId: 1)?.isLiked, true)
    }

    // An optimistic update that is never reconciled is a lie, so a refused
    // request has to put the heart back.
    func testLikeRollsBackWhenTheServerRefuses() async {
        let spy = SpyInteractions()
        spy.error = MockInteractionError.offline
        let userData = await makeUserData(interactions: spy)

        do {
            try await userData.setLike(true, on: 1, token: "token")
            XCTFail("expected the failure to propagate")
        } catch {
            // Expected: the view shows it.
        }

        XCTAssertEqual(userData.post(forId: 1)?.isLiked, false)
        XCTAssertEqual(userData.post(forId: 1)?.likeCount, 10)
    }

    // Following is a relationship with the person, so every post of theirs has
    // to change — leaving the rest showing "追蹤" reads as a failed tap.
    func testFollowAppliesToEveryPostByThatAuthor() async throws {
        let spy = SpyInteractions()
        let userData = await makeUserData(interactions: spy)

        try await userData.setFollow(true, forAuthor: "ep", token: "token")

        XCTAssertEqual(userData.post(forId: 1)?.isFollowed, true)
        XCTAssertEqual(userData.post(forId: 2)?.isFollowed, true)
        // A different author is untouched.
        XCTAssertEqual(userData.post(forId: 3)?.isFollowed, false)
        XCTAssertEqual(spy.followCalls.map(\.handle), ["ep"])
    }

    func testFollowRollsBackEveryPostItTouched() async {
        let spy = SpyInteractions()
        spy.error = MockInteractionError.offline
        let userData = await makeUserData(interactions: spy)

        do {
            try await userData.setFollow(true, forAuthor: "ep", token: "token")
            XCTFail("expected the failure to propagate")
        } catch {
            // Expected.
        }

        XCTAssertEqual(userData.post(forId: 1)?.isFollowed, false)
        XCTAssertEqual(userData.post(forId: 2)?.isFollowed, false)
    }

    // Without a backend the taps still work and simply never leave the device.
    // That is what keeps the app usable with nothing running.
    func testWithoutABackendTheChangeStaysLocal() async throws {
        let userData = await makeUserData(interactions: nil)

        try await userData.setLike(true, on: 1, token: nil)

        XCTAssertFalse(userData.canInteract)
        XCTAssertEqual(userData.post(forId: 1)?.isLiked, true)
        XCTAssertEqual(userData.post(forId: 1)?.likeCount, 11)
    }

    // isLiked and isFollowed describe a relationship with the reader, so the
    // feed request has to say who is reading.
    func testFeedRequestCarriesTheToken() async {
        let repository = TokenRecordingRepository()
        let userData = UserData(repository: repository)

        await userData.loadAll(token: "token")

        let tokens = await repository.tokens
        XCTAssertEqual(tokens, ["token", "token"])
    }

    private func makeUserData(interactions: PostInteractions?) async -> UserData {
        let userData = UserData(
            repository: TwoAuthorRepository(),
            interactions: interactions
        )
        await userData.loadAll()
        return userData
    }
}

private enum MockInteractionError: Error {
    case offline
}

private final class SpyInteractions: PostInteractions {
    var likeResult = LikeState(likeCount: 11, isLiked: true)
    var error: Error?
    private(set) var likeCalls: [(liked: Bool, postID: Int, token: String)] = []
    private(set) var followCalls: [(followed: Bool, handle: String)] = []

    func setLike(_ liked: Bool, postID: Int, token: String) async throws -> LikeState {
        if let error { throw error }
        likeCalls.append((liked, postID, token))
        return likeResult
    }

    func setFollow(_ followed: Bool, handle: String, token: String) async throws {
        if let error { throw error }
        followCalls.append((followed, handle))
    }
}

/// Two posts by one author and one by another, so a follow has something to
/// fan out across and something to leave alone.
private struct TwoAuthorRepository: PostRepository {
    func loadRecommendPosts(token: String?) async throws -> PostList {
        PostList(list: [
            makeInteractionPost(id: 1, handle: "ep"),
            makeInteractionPost(id: 2, handle: "ep")
        ])
    }

    func loadHotPosts(token: String?) async throws -> PostList {
        PostList(list: [makeInteractionPost(id: 3, handle: "ganane")])
    }
}

/// An actor rather than a class: `loadAll` issues both requests concurrently,
/// so an unsynchronised array loses one of the two appends and the test fails
/// for a reason that has nothing to do with what it is checking.
private actor TokenRecordingRepository: PostRepository {
    private(set) var tokens: [String?] = []

    func loadRecommendPosts(token: String?) async throws -> PostList {
        tokens.append(token)
        return PostList(list: [])
    }

    func loadHotPosts(token: String?) async throws -> PostList {
        tokens.append(token)
        return PostList(list: [])
    }
}

private func makeInteractionPost(id: Int, handle: String) -> Post {
    Post(
        id: id,
        author: Author(
            handle: handle,
            displayName: handle.uppercased(),
            avatar: "avatar.jpg",
            vip: false
        ),
        date: "2026-07-27T04:00:00.000Z",
        isFollowed: false,
        text: "測試貼文",
        images: [],
        commentCount: 0,
        likeCount: 10,
        isLiked: false
    )
}
