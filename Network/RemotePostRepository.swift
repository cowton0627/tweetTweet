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

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch let error as URLError {
            // Without this the raw URLError reaches the UI, and its
            // localizedDescription is written for developers — English
            // sentences like "A server with the specified hostname could not
            // be found." in an otherwise Chinese interface.
            throw RemotePostRepositoryError.transportFailed(error)
        }

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
    case transportFailed(URLError)
    case invalidResponse
    case httpStatus(Int)
    case decodingFailed(Error)

    /// Surfaced directly to the reader, so each case says what happened and
    /// whether retrying is worth it — never what the framework called it.
    var errorDescription: String? {
        switch self {
        case .transportFailed(let error):
            switch error.code {
            case .notConnectedToInternet:
                return "目前沒有網路連線。"
            case .networkConnectionLost:
                return "網路連線中斷，請再試一次。"
            case .timedOut:
                return "連線逾時，請稍後再試。"
            case .cannotFindHost:
                return "找不到伺服器，請確認後端位址是否正確。"
            case .cannotConnectToHost:
                return "無法連線到伺服器，請確認後端是否已啟動。"
            default:
                return "連線失敗，請稍後再試。"
            }
        case .invalidResponse:
            return "伺服器回應格式不正確。"
        case .httpStatus(let statusCode):
            switch statusCode {
            case 401, 403:
                return "沒有存取這些動態的權限。"
            case 404:
                return "找不到動態資料。"
            case 429:
                return "請求太頻繁，請稍後再試。"
            case 500...599:
                return "伺服器暫時無法回應，請稍後再試。"
            default:
                // Keeps the code for anything unanticipated: a status nobody
                // planned for is worth being able to name out loud.
                return "伺服器回應異常（\(statusCode)）。"
            }
        case .decodingFailed:
            return "無法解析伺服器回傳的貼文資料。"
        }
    }
}
