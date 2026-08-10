//
//  RemoteImageLoader.swift
//  tweetTweet
//
//  Downloads and caches post images.
//

import UIKit

enum RemoteImageError: LocalizedError {
    case invalidResponse
    case httpStatus(Int)
    case notAnImage

    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return "伺服器回應格式不正確。"
        case .httpStatus(let statusCode):
            return "無法載入圖片（\(statusCode)）。"
        case .notAnImage:
            return "下載到的檔案不是圖片。"
        }
    }
}

/// Fetches images once and keeps the decoded result in memory.
///
/// URLSession's own cache already avoids re-downloading, but it stores bytes:
/// every scroll past a cell would decode the same JPEG again, which is the
/// expensive half. This holds decoded `UIImage`s instead, and collapses
/// concurrent requests for the same URL into a single download — a feed screen
/// asks for the same avatar from several cells at once.
actor RemoteImageLoader {
    static let shared = RemoteImageLoader()

    private let session: URLSession
    private let cache = NSCache<NSURL, UIImage>()
    private var inFlight: [URL: Task<UIImage, Error>] = [:]

    init(session: URLSession = .shared, memoryLimitInBytes: Int = 64 * 1024 * 1024) {
        self.session = session
        cache.totalCostLimit = memoryLimitInBytes
    }

    func image(for url: URL) async throws -> UIImage {
        if let cached = cache.object(forKey: url as NSURL) {
            return cached
        }

        // Joining an existing download rather than starting a second one.
        if let running = inFlight[url] {
            return try await running.value
        }

        let task = Task<UIImage, Error> { [session] in
            let (data, response) = try await session.data(from: url)
            guard let http = response as? HTTPURLResponse else {
                throw RemoteImageError.invalidResponse
            }
            guard 200..<300 ~= http.statusCode else {
                throw RemoteImageError.httpStatus(http.statusCode)
            }
            guard let image = UIImage(data: data) else {
                throw RemoteImageError.notAnImage
            }
            return image
        }
        inFlight[url] = task

        defer { inFlight[url] = nil }

        // Deliberately awaiting the detached task rather than inlining the
        // work: if this caller is cancelled, everyone else waiting on the same
        // URL still gets their image.
        let image = try await task.value
        cache.setObject(image, forKey: url as NSURL, cost: image.approximateBytes)
        return image
    }

    /// Exposed for tests; the cache is otherwise process-lifetime.
    func removeAll() {
        cache.removeAllObjects()
    }
}

private extension UIImage {
    /// Rough decoded size, so the cache evicts by memory rather than by count.
    var approximateBytes: Int {
        guard let cgImage else { return 1 }
        return cgImage.bytesPerRow * cgImage.height
    }
}
