import XCTest
@testable import tweetTweet

@MainActor
final class UserDataTests: XCTestCase {
    func testLoadsWithInjectedRepository() async {
        let repository = MockPostRepository(
            recommendPosts: [makePost(id: 1, name: "推薦")],
            hotPosts: [makePost(id: 2, name: "熱門")]
        )

        let userData = UserData(repository: repository)
        await userData.loadAll()

        XCTAssertEqual(userData.recommendPostList.list.map(\.id), [1])
        XCTAssertEqual(userData.hotPostList.list.map(\.id), [2])
        XCTAssertEqual(userData.post(forId: 1)?.name, "推薦")
        XCTAssertEqual(userData.post(forId: 2)?.name, "熱門")
        XCTAssertEqual(userData.loadState(for: .recommend), .loaded)
        XCTAssertEqual(userData.loadState(for: .hot), .loaded)
    }

    func testEmptyRepositoryProducesEmptyState() async {
        let userData = UserData(
            repository: MockPostRepository(recommendPosts: [], hotPosts: [])
        )

        await userData.loadAll()

        XCTAssertEqual(userData.loadState(for: .recommend), .empty)
        XCTAssertEqual(userData.loadState(for: .hot), .empty)
    }

    func testFailedLoadCanRetryOneCategory() async {
        let repository = RetryableMockPostRepository()
        let userData = UserData(repository: repository)

        await userData.loadAll()
        XCTAssertEqual(
            userData.loadState(for: .recommend),
            .failed(message: MockError.offline.localizedDescription)
        )

        repository.shouldFail = false
        await userData.retry(.recommend)

        XCTAssertEqual(userData.loadState(for: .recommend), .loaded)
        XCTAssertEqual(userData.recommendPostList.list.map(\.id), [90])
    }

    func testUpdateChangesMatchingPostInEveryList() {
        let sharedPost = makePost(id: 10, name: "原始")
        let userData = makeUserData(
            recommendPosts: [sharedPost],
            hotPosts: [sharedPost]
        )
        var updatedPost = sharedPost
        updatedPost.isLiked = true
        updatedPost.likeCount = 8

        userData.update(updatedPost)

        XCTAssertTrue(userData.recommendPostList.list[0].isLiked)
        XCTAssertTrue(userData.hotPostList.list[0].isLiked)
        XCTAssertEqual(userData.recommendPostList.list[0].likeCount, 8)
        XCTAssertEqual(userData.hotPostList.list[0].likeCount, 8)
    }

    func testInsertRebuildsIndex() {
        let userData = makeUserData(
            recommendPosts: [makePost(id: 1)],
            hotPosts: []
        )

        userData.insert(makePost(id: 2, name: "新貼文"), into: .recommend)

        XCTAssertEqual(userData.recommendPostList.list.map(\.id), [2, 1])
        XCTAssertEqual(userData.post(forId: 2)?.name, "新貼文")
    }

    func testInsertClampsIndexToEndOfList() {
        let userData = makeUserData(
            recommendPosts: [makePost(id: 1)],
            hotPosts: []
        )

        userData.insert(makePost(id: 2), into: .recommend, at: 99)

        XCTAssertEqual(userData.recommendPostList.list.map(\.id), [1, 2])
    }

    func testNextPostIDUsesHighestIDAcrossCategories() {
        let userData = makeUserData(
            recommendPosts: [makePost(id: 12)],
            hotPosts: [makePost(id: 40)]
        )

        XCTAssertEqual(userData.nextPostID(), 41)
    }

    func testImageLibraryPreservesOrderAndRemovesDuplicates() {
        let userData = makeUserData(
            recommendPosts: [
                makePost(id: 1, avatar: "avatar-a.jpg", images: ["one.jpg", "two.jpg"])
            ],
            hotPosts: [
                makePost(id: 2, avatar: "avatar-a.jpg", images: ["two.jpg", "three.jpg"])
            ]
        )

        XCTAssertEqual(
            userData.imageLibrary(),
            ["avatar-a.jpg", "one.jpg", "two.jpg", "three.jpg"]
        )
    }
}

private struct MockPostRepository: PostRepository {
    let recommendPosts: [Post]
    let hotPosts: [Post]

    func loadRecommendPosts() async throws -> PostList {
        PostList(list: recommendPosts)
    }

    func loadHotPosts() async throws -> PostList {
        PostList(list: hotPosts)
    }
}

private final class RetryableMockPostRepository: PostRepository {
    var shouldFail = true

    func loadRecommendPosts() async throws -> PostList {
        if shouldFail {
            throw MockError.offline
        }
        return PostList(list: [makePost(id: 90)])
    }

    func loadHotPosts() async throws -> PostList {
        PostList(list: [])
    }
}

private enum MockError: LocalizedError {
    case offline

    var errorDescription: String? {
        "測試網路離線"
    }
}

@MainActor
private func makeUserData(
    recommendPosts: [Post],
    hotPosts: [Post]
) -> UserData {
    UserData(
        repository: MockPostRepository(
            recommendPosts: recommendPosts,
            hotPosts: hotPosts
        ),
        initialRecommendPosts: PostList(list: recommendPosts),
        initialHotPosts: PostList(list: hotPosts)
    )
}

private func makePost(
    id: Int,
    avatar: String = "avatar.jpg",
    name: String = "測試使用者",
    images: [String] = []
) -> Post {
    Post(
        id: id,
        avatar: avatar,
        vip: false,
        name: name,
        date: "2026-07-27 12:00",
        isFollowed: false,
        text: "測試貼文",
        images: images,
        commentCount: 0,
        likeCount: 0,
        isLiked: false
    )
}
