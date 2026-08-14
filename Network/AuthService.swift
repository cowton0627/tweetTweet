//
//  AuthService.swift
//  tweetTweet
//
//  Registering and signing in.
//

import Foundation

/// A signed-in account and the token that proves it.
struct Session: Equatable {
    let token: String
    let user: Author
}

protocol AuthService {
    func register(handle: String, displayName: String, password: String) async throws -> Session
    func logIn(handle: String, password: String) async throws -> Session
    /// Confirms a stored token still works, and returns who it belongs to.
    func currentUser(token: String) async throws -> Author
}

struct RemoteAuthService: AuthService {
    let baseURL: URL

    private let session: URLSession
    private let decoder: JSONDecoder

    init(
        baseURL: URL,
        session: URLSession = .shared,
        decoder: JSONDecoder = JSONDecoder()
    ) {
        self.baseURL = baseURL
        self.session = session
        self.decoder = decoder
    }

    private struct SessionResponse: Decodable {
        let token: String
        let user: Author
    }

    private struct UserResponse: Decodable {
        let user: Author
    }

    func register(
        handle: String,
        displayName: String,
        password: String
    ) async throws -> Session {
        let body = [
            "handle": handle,
            "displayName": displayName,
            "password": password,
        ]
        let data = try await post(path: "api/auth/register", body: body)
        let decoded = try decode(SessionResponse.self, from: data)
        return Session(token: decoded.token, user: decoded.user)
    }

    func logIn(handle: String, password: String) async throws -> Session {
        let body = ["handle": handle, "password": password]
        let data = try await post(path: "api/auth/login", body: body)
        let decoded = try decode(SessionResponse.self, from: data)
        return Session(token: decoded.token, user: decoded.user)
    }

    func currentUser(token: String) async throws -> Author {
        var request = URLRequest(url: baseURL.appendingPathComponent("api/auth/me"))
        request.timeoutInterval = 15
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        return try decode(UserResponse.self, from: try await send(request)).user
    }

    private func post(path: String, body: [String: String]) async throws -> Data {
        var request = URLRequest(url: baseURL.appendingPathComponent(path))
        request.httpMethod = "POST"
        request.timeoutInterval = 30
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.httpBody = try JSONEncoder().encode(body)
        return try await send(request)
    }

    private func send(_ request: URLRequest) async throws -> Data {
        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch let error as URLError {
            throw AuthError.transportFailed(error)
        }

        guard let http = response as? HTTPURLResponse else {
            throw AuthError.invalidResponse
        }
        guard 200..<300 ~= http.statusCode else {
            // The server explains refusals in a way worth showing — "that
            // handle is taken" is more useful than "400".
            throw AuthError.rejected(
                status: http.statusCode,
                message: Self.serverMessage(in: data)
            )
        }
        return data
    }

    private func decode<T: Decodable>(_ type: T.Type, from data: Data) throws -> T {
        do {
            return try decoder.decode(type, from: data)
        } catch {
            throw AuthError.decodingFailed(error)
        }
    }

    private static func serverMessage(in data: Data) -> String? {
        struct ErrorBody: Decodable { let error: String }
        return try? JSONDecoder().decode(ErrorBody.self, from: data).error
    }
}

enum AuthError: LocalizedError {
    case transportFailed(URLError)
    case invalidResponse
    case rejected(status: Int, message: String?)
    case decodingFailed(Error)

    var errorDescription: String? {
        switch self {
        case .transportFailed(let error):
            switch error.code {
            case .notConnectedToInternet: return "目前沒有網路連線。"
            case .timedOut: return "連線逾時，請稍後再試。"
            case .cannotFindHost, .cannotConnectToHost:
                return "無法連線到伺服器。"
            default: return "連線失敗，請稍後再試。"
            }
        case .invalidResponse:
            return "伺服器回應格式不正確。"
        case .rejected(let status, let message):
            // The server's own wording where there is one, since it knows which
            // rule was broken.
            if let message { return Self.localised(message) }
            switch status {
            case 401: return "帳號或密碼不正確。"
            case 409: return "這個帳號名稱已經有人使用。"
            case 429: return "嘗試次數太多，請稍後再試。"
            default: return "無法完成，請稍後再試。"
            }
        case .decodingFailed:
            return "無法解析伺服器回傳的資料。"
        }
    }

    /// The API answers in English; the interface is Chinese.
    private static func localised(_ message: String) -> String {
        switch message {
        case "handle or password is incorrect": return "帳號或密碼不正確。"
        case "that handle is taken": return "這個帳號名稱已經有人使用。"
        case "that handle is reserved": return "這個帳號名稱不開放使用。"
        case "sign in required": return "請先登入。"
        case "too many attempts, try again later": return "嘗試次數太多，請稍後再試。"
        case let m where m.hasPrefix("handle must be"):
            return "帳號名稱需為 3-20 個字元，只能使用英文小寫、數字或底線。"
        case let m where m.hasPrefix("password must be"):
            return "密碼至少需要 8 個字元。"
        case let m where m.hasPrefix("displayName must be"):
            return "顯示名稱需為 1-40 個字元。"
        default: return "無法完成，請稍後再試。"
        }
    }
}
