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
            XCTAssertEqual(error.errorDescription, "伺服器暫時無法回應，請稍後再試。")
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    // These messages are read by whoever is holding the phone, so they are
    // asserted as strings rather than as error cases.
    func testHTTPStatusesReadAsPlainChinese() async throws {
        let expectations: [(Int, String)] = [
            (401, "沒有存取這些動態的權限。"),
            (404, "找不到動態資料。"),
            (429, "請求太頻繁，請稍後再試。"),
            (500, "伺服器暫時無法回應，請稍後再試。")
        ]

        for (statusCode, expected) in expectations {
            URLProtocolStub.requestHandler = { request in
                let response = HTTPURLResponse(
                    url: try XCTUnwrap(request.url),
                    statusCode: statusCode,
                    httpVersion: nil,
                    headerFields: nil
                )
                return (try XCTUnwrap(response), Data())
            }

            do {
                _ = try await makeRemoteRepository().loadHotPosts()
                XCTFail("Expected an error for status \(statusCode)")
            } catch let error as RemotePostRepositoryError {
                XCTAssertEqual(error.errorDescription, expected, "status \(statusCode)")
            }
        }
    }

    // An unplanned status should still be nameable when someone reports it.
    func testUnexpectedHTTPStatusKeepsItsCode() async {
        URLProtocolStub.requestHandler = { request in
            let response = HTTPURLResponse(
                url: try XCTUnwrap(request.url),
                statusCode: 418,
                httpVersion: nil,
                headerFields: nil
            )
            return (try XCTUnwrap(response), Data())
        }

        do {
            _ = try await makeRemoteRepository().loadHotPosts()
            XCTFail("Expected an error")
        } catch let error as RemotePostRepositoryError {
            XCTAssertEqual(error.errorDescription, "伺服器回應異常（418）。")
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    // The regression that prompted all of this: a transport failure used to
    // reach the UI as URLError's own English description.
    func testTransportFailuresReadAsPlainChinese() async throws {
        let expectations: [(URLError.Code, String)] = [
            (.notConnectedToInternet, "目前沒有網路連線。"),
            (.networkConnectionLost, "網路連線中斷，請再試一次。"),
            (.timedOut, "連線逾時，請稍後再試。"),
            (.cannotFindHost, "找不到伺服器，請確認後端位址是否正確。"),
            (.cannotConnectToHost, "無法連線到伺服器，請確認後端是否已啟動。"),
            (.secureConnectionFailed, "連線失敗，請稍後再試。")
        ]

        for (code, expected) in expectations {
            URLProtocolStub.requestHandler = { _ in throw URLError(code) }

            do {
                _ = try await makeRemoteRepository().loadRecommendPosts()
                XCTFail("Expected an error for \(code)")
            } catch let error as RemotePostRepositoryError {
                XCTAssertEqual(error.errorDescription, expected, "code \(code)")
            }
        }
    }

    func testTransportFailureMessageContainsNoEnglish() async {
        URLProtocolStub.requestHandler = { _ in throw URLError(.cannotFindHost) }

        do {
            _ = try await makeRemoteRepository().loadRecommendPosts()
            XCTFail("Expected an error")
        } catch {
            let message = error.localizedDescription
            XCTAssertFalse(
                message.contains(where: { $0.isASCII && $0.isLetter }),
                "Surfaced a developer-facing message: \(message)"
            )
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
