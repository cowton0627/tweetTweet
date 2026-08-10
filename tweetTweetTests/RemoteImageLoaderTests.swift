//
//  RemoteImageLoaderTests.swift
//  tweetTweetTests
//

import XCTest
@testable import tweetTweet

final class RemoteImageLoaderTests: XCTestCase {
    private let url = URL(string: "https://example.test/media/post-01.jpg")!

    override func setUp() {
        super.setUp()
        ImageProtocolStub.reset()
    }

    override func tearDown() {
        ImageProtocolStub.reset()
        super.tearDown()
    }

    func testDownloadsAndDecodesAnImage() async throws {
        ImageProtocolStub.respond(with: Self.pngData())

        let image = try await makeLoader().image(for: url)

        XCTAssertEqual(image.size.width, 4)
        XCTAssertEqual(ImageProtocolStub.requestCount, 1)
    }

    // The expensive half of showing a feed is decoding, not downloading:
    // URLSession would already avoid the second fetch, but not the second
    // decode. A second ask must not reach the network at all.
    func testServesTheSecondRequestFromMemory() async throws {
        ImageProtocolStub.respond(with: Self.pngData())
        let loader = makeLoader()

        _ = try await loader.image(for: url)
        _ = try await loader.image(for: url)

        XCTAssertEqual(ImageProtocolStub.requestCount, 1)
    }

    // Several cells on one screen ask for the same avatar at the same moment,
    // before any of them has finished.
    func testCollapsesConcurrentRequestsIntoOneDownload() async throws {
        ImageProtocolStub.respond(with: Self.pngData(), afterDelay: 0.2)
        let loader = makeLoader()

        try await withThrowingTaskGroup(of: Void.self) { group in
            for _ in 0..<8 {
                group.addTask { _ = try await loader.image(for: self.url) }
            }
            try await group.waitForAll()
        }

        XCTAssertEqual(ImageProtocolStub.requestCount, 1)
    }

    func testDifferentURLsAreFetchedSeparately() async throws {
        ImageProtocolStub.respond(with: Self.pngData())
        let loader = makeLoader()

        _ = try await loader.image(for: url)
        _ = try await loader.image(for: URL(string: "https://example.test/media/post-02.jpg")!)

        XCTAssertEqual(ImageProtocolStub.requestCount, 2)
    }

    func testRejectsNonSuccessStatus() async {
        ImageProtocolStub.respond(with: Data(), statusCode: 404)

        do {
            _ = try await makeLoader().image(for: url)
            XCTFail("Expected an error")
        } catch let error as RemoteImageError {
            XCTAssertEqual(error.errorDescription, "無法載入圖片（404）。")
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testRejectsAResponseThatIsNotAnImage() async {
        ImageProtocolStub.respond(with: Data("not a picture".utf8))

        do {
            _ = try await makeLoader().image(for: url)
            XCTFail("Expected an error")
        } catch let error as RemoteImageError {
            XCTAssertEqual(error.errorDescription, "下載到的檔案不是圖片。")
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    // A failure must not be remembered as if it were a result.
    func testRetriesAfterAFailure() async throws {
        ImageProtocolStub.respond(with: Data(), statusCode: 500)
        let loader = makeLoader()

        _ = try? await loader.image(for: url)

        ImageProtocolStub.respond(with: Self.pngData())
        let image = try await loader.image(for: url)

        XCTAssertEqual(image.size.width, 4)
        XCTAssertEqual(ImageProtocolStub.requestCount, 2)
    }

    private func makeLoader() -> RemoteImageLoader {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [ImageProtocolStub.self]
        // Otherwise URLSession's own cache would answer the second request and
        // hide whether the loader's memory cache did its job.
        configuration.urlCache = nil
        configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
        return RemoteImageLoader(session: URLSession(configuration: configuration))
    }

    private static func pngData() -> Data {
        // scale 1, so the fixture is 4x4 pixels regardless of the device the
        // tests happen to run on.
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        let renderer = UIGraphicsImageRenderer(
            size: CGSize(width: 4, height: 4),
            format: format
        )
        return renderer.pngData { context in
            UIColor.red.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 4, height: 4))
        }
    }
}

private final class ImageProtocolStub: URLProtocol {
    private static let lock = NSLock()
    private static var body = Data()
    private static var status = 200
    private static var delay: TimeInterval = 0
    private static var count = 0

    static func reset() {
        lock.withLock {
            body = Data()
            status = 200
            delay = 0
            count = 0
        }
    }

    static func respond(
        with data: Data,
        statusCode: Int = 200,
        afterDelay seconds: TimeInterval = 0
    ) {
        // Deliberately leaves `count` alone: a test that changes the response
        // mid-way is usually counting requests across both.
        lock.withLock {
            body = data
            status = statusCode
            delay = seconds
        }
    }

    static var requestCount: Int {
        lock.withLock { count }
    }

    override class func canInit(with request: URLRequest) -> Bool { true }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        let (data, statusCode, delay) = Self.lock.withLock { () -> (Data, Int, TimeInterval) in
            Self.count += 1
            return (Self.body, Self.status, Self.delay)
        }

        let deliver = { [weak self] in
            guard let self else { return }
            let response = HTTPURLResponse(
                url: self.request.url!,
                statusCode: statusCode,
                httpVersion: nil,
                headerFields: ["Content-Type": "image/png"]
            )!
            self.client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            self.client?.urlProtocol(self, didLoad: data)
            self.client?.urlProtocolDidFinishLoading(self)
        }

        if delay > 0 {
            DispatchQueue.global().asyncAfter(deadline: .now() + delay, execute: deliver)
        } else {
            deliver()
        }
    }

    override func stopLoading() {}
}
