import XCTest
@testable import tweetTweet

final class PostDecodingTests: XCTestCase {
    func testRecommendFixtureDecodes() throws {
        let postList = try decodeFixture(named: "PostListData_recommend_1")

        XCTAssertFalse(postList.list.isEmpty)
        XCTAssertEqual(Set(postList.list.map(\.id)).count, postList.list.count)
        XCTAssertTrue(postList.list.contains { $0.images.count == 6 })
    }

    func testHotFixtureDecodes() throws {
        let postList = try decodeFixture(named: "PostListData_hot_1")

        XCTAssertFalse(postList.list.isEmpty)
        XCTAssertEqual(Set(postList.list.map(\.id)).count, postList.list.count)
        XCTAssertTrue(postList.list.allSatisfy { !$0.avatar.isEmpty })
    }

    private func decodeFixture(named name: String) throws -> PostList {
        let testFileURL = URL(fileURLWithPath: #filePath)
        let projectRootURL = testFileURL
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let fixtureURL = projectRootURL
            .appendingPathComponent("Resources")
            .appendingPathComponent("\(name).json")
        let data = try Data(contentsOf: fixtureURL)

        return try JSONDecoder().decode(PostList.self, from: data)
    }
}

final class RemotePostRepositoryTests: XCTestCase {
    override func tearDown() {
        URLProtocolStub.requestHandler = nil
        super.tearDown()
    }

    func testRemoteRepositoryDecodesSuccessfulResponse() async throws {
        let responseBody = """
        {
          "list": [{
            "id": 42,
            "avatar": "avatar-01.jpg",
            "vip": false,
            "name": "遠端貼文",
            "date": "2026-07-28 09:00",
            "isFollowed": false,
            "text": "由測試伺服器回傳",
            "images": [],
            "commentCount": 0,
            "likeCount": 0,
            "isLiked": false
          }]
        }
        """
        URLProtocolStub.requestHandler = { request in
            let response = HTTPURLResponse(
                url: try XCTUnwrap(request.url),
                statusCode: 200,
                httpVersion: nil,
                headerFields: ["Content-Type": "application/json"]
            )
            return (try XCTUnwrap(response), Data(responseBody.utf8))
        }
        let repository = makeRemoteRepository()

        let result = try await repository.loadRecommendPosts()

        XCTAssertEqual(result.list.map(\.id), [42])
        XCTAssertEqual(result.list.first?.name, "遠端貼文")
    }

    func testRemoteRepositoryRejectsHTTPError() async {
        URLProtocolStub.requestHandler = { request in
            let response = HTTPURLResponse(
                url: try XCTUnwrap(request.url),
                statusCode: 503,
                httpVersion: nil,
                headerFields: nil
            )
            return (try XCTUnwrap(response), Data())
        }
        let repository = makeRemoteRepository()

        do {
            _ = try await repository.loadHotPosts()
            XCTFail("Expected HTTP status error")
        } catch let error as RemotePostRepositoryError {
            XCTAssertEqual(error.errorDescription, "伺服器回傳錯誤狀態碼 503。")
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    private func makeRemoteRepository() -> RemotePostRepository {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [URLProtocolStub.self]
        let session = URLSession(configuration: configuration)
        let endpoint = URL(string: "https://example.test/posts")!

        return RemotePostRepository(
            recommendURL: endpoint,
            hotURL: endpoint,
            session: session
        )
    }
}

private final class URLProtocolStub: URLProtocol {
    static var requestHandler: ((URLRequest) throws -> (HTTPURLResponse, Data))?

    override class func canInit(with request: URLRequest) -> Bool {
        true
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    override func startLoading() {
        guard let handler = Self.requestHandler else {
            client?.urlProtocol(self, didFailWithError: URLError(.badServerResponse))
            return
        }

        do {
            let (response, data) = try handler(request)
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }

    override func stopLoading() {}
}
