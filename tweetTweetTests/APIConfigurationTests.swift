//
//  APIConfigurationTests.swift
//  tweetTweetTests
//

import XCTest
@testable import tweetTweet

final class APIConfigurationTests: XCTestCase {

    func testBuildsBaseURLFromSchemeAndHost() {
        let url = APIConfiguration.baseURL(scheme: "http", host: "localhost:3000")
        XCTAssertEqual(url?.absoluteString, "http://localhost:3000")
    }

    func testBuildsHTTPSBaseURLWithoutPort() {
        let url = APIConfiguration.baseURL(scheme: "https", host: "example.invalid")
        XCTAssertEqual(url?.absoluteString, "https://example.invalid")
    }

    // An unconfigured build leaves the Info.plist substitutions as empty
    // strings rather than removing the keys, so blank has to count as absent.
    func testReturnsNilWhenPartsAreMissingOrBlank() {
        XCTAssertNil(APIConfiguration.baseURL(scheme: nil, host: "localhost"))
        XCTAssertNil(APIConfiguration.baseURL(scheme: "http", host: nil))
        XCTAssertNil(APIConfiguration.baseURL(scheme: "", host: "localhost"))
        XCTAssertNil(APIConfiguration.baseURL(scheme: "http", host: ""))
        XCTAssertNil(APIConfiguration.baseURL(scheme: "http", host: "   "))
    }

    func testAppendsFeedPathsToConfiguredHost() throws {
        let baseURL = try XCTUnwrap(
            APIConfiguration.baseURL(scheme: "http", host: "localhost:3000")
        )
        XCTAssertEqual(
            baseURL.appendingPathComponent("api/feeds/recommend").absoluteString,
            "http://localhost:3000/api/feeds/recommend"
        )
        XCTAssertEqual(
            baseURL.appendingPathComponent("api/feeds/hot").absoluteString,
            "http://localhost:3000/api/feeds/hot"
        )
    }

    // The test bundle carries no APIScheme/APIHost, so this exercises the
    // fallback that keeps the app usable with no backend configured.
    func testFactoryFallsBackToBundledDataWithoutConfiguration() {
        let backend = PostRepositoryFactory.makeDefault(bundle: Bundle(for: Self.self))
        XCTAssertTrue(backend.repository is LocalPostRepository)
    }

    // Offline there is nowhere to publish to, and that is expressed by having
    // no composer at all rather than by one that always fails.
    func testNoComposerWithoutABackend() {
        let backend = PostRepositoryFactory.makeDefault(bundle: Bundle(for: Self.self))
        XCTAssertNil(backend.composer)
    }
}
