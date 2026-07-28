//
//  RemotePostRepository.swift
//  tweetTweet
//
//  Loads the two feed categories from configurable HTTP endpoints.
//

import Foundation

struct RemotePostRepository: PostRepository {
    let recommendURL: URL
    let hotURL: URL

    private let session: URLSession
    private let decoder: JSONDecoder

    init(
        recommendURL: URL,
        hotURL: URL,
        session: URLSession = .shared,
        decoder: JSONDecoder = JSONDecoder()
    ) {
        self.recommendURL = recommendURL
        self.hotURL = hotURL
        self.session = session
        self.decoder = decoder
    }

    func loadRecommendPosts() async throws -> PostList {
        try await load(from: recommendURL)
    }

    func loadHotPosts() async throws -> PostList {
        try await load(from: hotURL)
    }

    private func load(from url: URL) async throws -> PostList {
        var request = URLRequest(url: url)
        request.timeoutInterval = 15
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw RemotePostRepositoryError.invalidResponse
        }
        guard 200..<300 ~= httpResponse.statusCode else {
            throw RemotePostRepositoryError.httpStatus(httpResponse.statusCode)
        }

        do {
            return try decoder.decode(PostList.self, from: data)
        } catch {
            throw RemotePostRepositoryError.decodingFailed(error)
        }
    }
}

enum RemotePostRepositoryError: LocalizedError {
    case invalidResponse
    case httpStatus(Int)
    case decodingFailed(Error)

    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return "伺服器回應格式不正確。"
        case .httpStatus(let statusCode):
            return "伺服器回傳錯誤狀態碼 \(statusCode)。"
        case .decodingFailed:
            return "無法解析伺服器回傳的貼文資料。"
        }
    }
}
