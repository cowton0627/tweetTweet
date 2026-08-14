import XCTest
@testable import tweetTweet

@MainActor
final class ProfileTests: XCTestCase {
    func testLoadsTheAccountAndItsPosts() async {
        let service = SpyProfileService()
        service.profile = makeProfile(postCount: 2)
        service.posts = [makeProfilePost(id: 1), makeProfilePost(id: 2)]
        let store = ProfileStore(handle: "ep", service: service)

        await store.load(token: "token")

        XCTAssertEqual(store.state, .loaded)
        XCTAssertEqual(store.profile?.user.handle, "ep")
        XCTAssertEqual(store.posts.map(\.id), [1, 2])
        XCTAssertEqual(service.tokens, ["token", "token"])
    }

    func testReportsAFailureRatherThanAnEmptyPage() async {
        let service = SpyProfileService()
        service.error = MockProfileError.offline
        let store = ProfileStore(handle: "ep", service: service)

        await store.load(token: nil)

        guard case .failed = store.state else {
            return XCTFail("expected a failure state, got \(store.state)")
        }
        XCTAssertNil(store.profile)
    }

    // Without a backend there is no account to look at, and the screen says so
    // rather than spinning forever.
    func testSaysSoWithoutABackend() async {
        let store = ProfileStore(handle: "ep", service: nil)

        await store.load(token: nil)

        guard case .failed = store.state else {
            return XCTFail("expected a failure state, got \(store.state)")
        }
    }

    // The button and the number under it have to agree, so both move together.
    func testFollowMovesTheButtonAndTheCount() async {
        let service = SpyProfileService()
        service.profile = makeProfile(followerCount: 4)
        let interactions = SpyFollowing()
        let store = ProfileStore(handle: "ep", service: service, interactions: interactions)
        await store.load(token: "token")

        await store.setFollow(true, token: "token")

        XCTAssertEqual(store.profile?.isFollowed, true)
        XCTAssertEqual(store.profile?.followerCount, 5)
        XCTAssertEqual(interactions.calls.map(\.handle), ["ep"])
    }

    func testFollowRollsBackWhenRefused() async {
        let service = SpyProfileService()
        service.profile = makeProfile(followerCount: 4)
        let interactions = SpyFollowing()
        interactions.error = MockProfileError.offline
        let store = ProfileStore(handle: "ep", service: service, interactions: interactions)
        await store.load(token: "token")

        await store.setFollow(true, token: "token")

        XCTAssertEqual(store.profile?.isFollowed, false)
        XCTAssertEqual(store.profile?.followerCount, 4)
        XCTAssertNotNil(store.failureMessage)
    }

    func testDoesNothingWhenSignedOut() async {
        let service = SpyProfileService()
        service.profile = makeProfile()
        let interactions = SpyFollowing()
        let store = ProfileStore(handle: "ep", service: service, interactions: interactions)
        await store.load(token: nil)

        await store.setFollow(true, token: nil)

        XCTAssertTrue(interactions.calls.isEmpty)
        XCTAssertEqual(store.profile?.isFollowed, false)
    }
}

private enum MockProfileError: Error {
    case offline
}

private final class SpyProfileService: ProfileService {
    var profile: Profile?
    var posts: [Post] = []
    var error: Error?
    private(set) var tokens: [String?] = []

    func profile(forHandle handle: String, token: String?) async throws -> Profile {
        if let error { throw error }
        tokens.append(token)
        return profile ?? makeProfile()
    }

    func posts(byHandle handle: String, token: String?) async throws -> [Post] {
        if let error { throw error }
        tokens.append(token)
        return posts
    }
}

private final class SpyFollowing: PostInteractions {
    var error: Error?
    private(set) var calls: [(followed: Bool, handle: String)] = []

    func setLike(_ liked: Bool, postID: Int, token: String) async throws -> LikeState {
        LikeState(likeCount: 0, isLiked: liked)
    }

    func setFollow(_ followed: Bool, handle: String, token: String) async throws {
        if let error { throw error }
        calls.append((followed, handle))
    }
}

private func makeProfile(
    postCount: Int = 0,
    followerCount: Int = 0,
    isMe: Bool = false
) -> Profile {
    Profile(
        user: Author(
            handle: "ep",
            displayName: "EP",
            avatar: "avatar.jpg",
            vip: true
        ),
        postCount: postCount,
        followerCount: followerCount,
        followingCount: 0,
        isFollowed: false,
        isMe: isMe
    )
}

private func makeProfilePost(id: Int) -> Post {
    Post(
        id: id,
        author: Author(
            handle: "ep",
            displayName: "EP",
            avatar: "avatar.jpg",
            vip: true
        ),
        date: "2026-07-27T04:00:00.000Z",
        isFollowed: false,
        text: "測試貼文",
        images: [],
        commentCount: 0,
        likeCount: 0,
        isLiked: false
    )
}
