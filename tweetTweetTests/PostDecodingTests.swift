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
        XCTAssertTrue(postList.list.allSatisfy { !$0.author.avatar.isEmpty })
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
            "author": { "handle": "remote", "displayName": "遠端貼文", "avatar": "avatar-01.jpg", "vip": false },
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
        XCTAssertEqual(result.list.first?.author.displayName, "遠端貼文")
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

    // The server sends relative paths because it cannot know the hostname it
    // was reached by. Resolving them here keeps every view downstream from
    // needing to know a base URL.
    func testResolvesServerRelativeMediaPaths() async throws {
        URLProtocolStub.requestHandler = { request in
            let body = """
            {
              "list": [{
                "id": 1, "author": { "handle": "n", "displayName": "n", "avatar": "/media/avatar-01.jpg", "vip": false }, "date": "d", "isFollowed": false, "text": "t",
                "images": ["/media/post-01.jpg", "/media/post-02.jpg"],
                "commentCount": 0, "likeCount": 0, "isLiked": false
              }]
            }
            """
            let response = HTTPURLResponse(
                url: try XCTUnwrap(request.url),
                statusCode: 200,
                httpVersion: nil,
                headerFields: ["Content-Type": "application/json"]
            )
            return (try XCTUnwrap(response), Data(body.utf8))
        }

        let feed = try await makeRemoteRepository().loadRecommendPosts()
        let post = try XCTUnwrap(feed.list.first)

        XCTAssertEqual(post.author.avatar, "https://example.test/media/avatar-01.jpg")
        XCTAssertEqual(post.images, [
            "https://example.test/media/post-01.jpg",
            "https://example.test/media/post-02.jpg"
        ])
    }

    // Bundled filenames carry no leading slash and must survive untouched, so
    // the offline repository keeps working.
    func testLeavesNonPathReferencesAlone() async throws {
        URLProtocolStub.requestHandler = { request in
            let body = """
            {
              "list": [{
                "id": 1,
                "author": { "handle": "n", "displayName": "n", "avatar": "avatar-01.jpg", "vip": false }, "date": "d", "isFollowed": false, "text": "t",
                "images": ["https://cdn.example.test/already-absolute.jpg"],
                "commentCount": 0, "likeCount": 0, "isLiked": false
              }]
            }
            """
            let response = HTTPURLResponse(
                url: try XCTUnwrap(request.url),
                statusCode: 200,
                httpVersion: nil,
                headerFields: ["Content-Type": "application/json"]
            )
            return (try XCTUnwrap(response), Data(body.utf8))
        }

        let feed = try await makeRemoteRepository().loadRecommendPosts()
        let post = try XCTUnwrap(feed.list.first)

        XCTAssertEqual(post.author.avatar, "avatar-01.jpg")
        XCTAssertEqual(post.images, ["https://cdn.example.test/already-absolute.jpg"])
    }

    // The multipart body is hand-assembled, so its framing is asserted here:
    // a stray CRLF or a missing boundary terminator is rejected by the server
    // with a message that says nothing about which part was wrong.
    func testUploadSendsAWellFormedMultipartBody() async throws {
        var captured: URLRequest?
        URLProtocolStub.requestHandler = { request in
            captured = request
            let response = HTTPURLResponse(
                url: try XCTUnwrap(request.url),
                statusCode: 201,
                httpVersion: nil,
                headerFields: ["Content-Type": "application/json"]
            )
            let body = #"{"path":"/media/abc.jpg"}"#
            return (try XCTUnwrap(response), Data(body.utf8))
        }

        let image = UIGraphicsImageRenderer(size: CGSize(width: 2, height: 2))
            .image { context in
                UIColor.blue.setFill()
                context.fill(CGRect(x: 0, y: 0, width: 2, height: 2))
            }

        let path = try await makeRemoteRepository().upload(image)
        XCTAssertEqual(path, "/media/abc.jpg")

        let request = try XCTUnwrap(captured)
        XCTAssertEqual(request.httpMethod, "POST")
        XCTAssertEqual(request.url?.path, "/api/posts/media")

        let contentType = try XCTUnwrap(
            request.value(forHTTPHeaderField: "Content-Type")
        )
        XCTAssertTrue(contentType.hasPrefix("multipart/form-data; boundary="))
        let boundary = String(contentType.dropFirst("multipart/form-data; boundary=".count))
        XCTAssertFalse(boundary.isEmpty)

        // URLProtocol moves a set httpBody into a stream, so read it back.
        let body = try XCTUnwrap(request.httpBody ?? request.httpBodyStream.map(Self.drain))
        // Decoded leniently: 200 bytes in, the JPEG payload has already
        // started and would make a strict UTF-8 decode fail.
        let prefix = String(decoding: body.prefix(200), as: UTF8.self)
        XCTAssertTrue(prefix.hasPrefix("--\(boundary)\r\n"), prefix)
        XCTAssertTrue(prefix.contains("name=\"image\""))
        XCTAssertTrue(prefix.contains("Content-Type: image/jpeg\r\n\r\n"))

        // The payload has to survive as raw bytes, not as text.
        // Data.contains(Data) is iOS 16+; this project targets 15.
        XCTAssertNotNil(body.range(of: Data([0xff, 0xd8, 0xff])), "JPEG marker missing")

        let tail = String(decoding: body.suffix(boundary.count + 8), as: UTF8.self)
        XCTAssertEqual(tail, "\r\n--\(boundary)--\r\n")
    }

    func testComposeCarriesTheSessionToken() async throws {
        var authorization: String??
        URLProtocolStub.requestHandler = { request in
            authorization = request.value(forHTTPHeaderField: "Authorization")
            let response = HTTPURLResponse(
                url: try XCTUnwrap(request.url),
                statusCode: 201,
                httpVersion: nil,
                headerFields: ["Content-Type": "application/json"]
            )
            let body = """
            {
              "id": 7, "author": { "handle": "ling", "displayName": "\u{9748}", "avatar": "/media/avatar-02.jpg", "vip": false },
              "date": "2026-08-10T11:01:47.436Z", "isFollowed": false, "text": "hi",
              "images": [], "commentCount": 0, "likeCount": 0, "isLiked": false
            }
            """
            return (try XCTUnwrap(response), Data(body.utf8))
        }

        let post = try await makeRemoteRepository().compose(
            text: "hi",
            images: [],
            category: .recommend,
            token: "a.b.c"
        )

        XCTAssertEqual(authorization ?? nil, "Bearer a.b.c")
        // And the server's attribution is what the app shows, not a guess.
        XCTAssertEqual(post.author.handle, "ling")
    }

    func testComposeSendsServerRelativeImagePaths() async throws {
        var capturedBody: Data?
        URLProtocolStub.requestHandler = { request in
            capturedBody = request.httpBody
                ?? request.httpBodyStream.map(Self.drain)
            let response = HTTPURLResponse(
                url: try XCTUnwrap(request.url),
                statusCode: 201,
                httpVersion: nil,
                headerFields: ["Content-Type": "application/json"]
            )
            let body = """
            {
              "id": 2051,
              "author": { "handle": "me", "displayName": "我", "avatar": "/media/avatar-01.jpg", "vip": false }, "date": "2026-08-10T11:01:47.436Z",
              "isFollowed": true, "text": "hi",
              "images": ["/media/abc.jpg"],
              "commentCount": 0, "likeCount": 0, "isLiked": false
            }
            """
            return (try XCTUnwrap(response), Data(body.utf8))
        }

        let post = try await makeRemoteRepository().compose(
            text: "hi",
            images: ["https://example.test/media/abc.jpg"],
            category: .recommend,
            token: nil
        )

        // Absolute URLs are this client's own construction; the server only
        // knows its own paths.
        let sent = try XCTUnwrap(capturedBody)
        let json = try XCTUnwrap(
            JSONSerialization.jsonObject(with: sent) as? [String: Any]
        )
        XCTAssertEqual(json["images"] as? [String], ["/media/abc.jpg"])
        XCTAssertEqual(json["category"] as? String, "recommend")

        // And what comes back is resolved for display.
        XCTAssertEqual(post.images, ["https://example.test/media/abc.jpg"])
        XCTAssertEqual(post.author.avatar, "https://example.test/media/avatar-01.jpg")
    }

    private static func drain(_ stream: InputStream) -> Data {
        stream.open()
        defer { stream.close() }
        var data = Data()
        let size = 4096
        var buffer = [UInt8](repeating: 0, count: size)
        while stream.hasBytesAvailable {
            let read = stream.read(&buffer, maxLength: size)
            if read <= 0 { break }
            data.append(buffer, count: read)
        }
        return data
    }

    private func makeRemoteRepository(
        baseURL: String = "https://example.test"
    ) -> RemotePostRepository {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [URLProtocolStub.self]
        let session = URLSession(configuration: configuration)

        return RemotePostRepository(
            baseURL: URL(string: baseURL)!,
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
