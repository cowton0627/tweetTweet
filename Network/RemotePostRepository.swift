//
//  RemotePostRepository.swift
//  tweetTweet
//
//  Loads the two feed categories from a backend.
//

import UIKit

struct RemotePostRepository: PostRepository {
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

    func loadRecommendPosts() async throws -> PostList {
        try await load(path: "api/feeds/recommend")
    }

    func loadHotPosts() async throws -> PostList {
        try await load(path: "api/feeds/hot")
    }

    private func load(path: String) async throws -> PostList {
        var request = URLRequest(url: baseURL.appendingPathComponent(path))
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
            return resolvingMedia(in: try decoder.decode(PostList.self, from: data))
        } catch let error as RemotePostRepositoryError {
            throw error
        } catch {
            throw RemotePostRepositoryError.decodingFailed(error)
        }
    }

    /// Turns the server's relative media paths into absolute URLs.
    ///
    /// The server sends `/media/post-01.jpg` rather than a full URL, because it
    /// cannot know which hostname it was reached by — behind a tunnel that
    /// changes on every restart. Resolving here, at the edge of the network
    /// layer, keeps every view downstream from needing to know a base URL, and
    /// leaves the bundled repository's plain filenames untouched.
    private func resolvingMedia(in list: PostList) -> PostList {
        PostList(list: list.list.map { post in
            var post = post
            post.author.avatar = absoluteMediaReference(post.author.avatar)
            post.images = post.images.map(absoluteMediaReference)
            return post
        })
    }

    private func absoluteMediaReference(_ reference: String) -> String {
        guard reference.hasPrefix("/") else { return reference }
        return URL(string: reference, relativeTo: baseURL)?.absoluteString ?? reference
    }
}

extension RemotePostRepository: PostComposer {
    func upload(_ image: UIImage) async throws -> String {
        guard let jpeg = image.jpegData(compressionQuality: 0.85) else {
            throw RemotePostRepositoryError.imageEncodingFailed
        }

        let boundary = "Boundary-\(UUID().uuidString)"
        var request = URLRequest(url: baseURL.appendingPathComponent("api/posts/media"))
        request.httpMethod = "POST"
        request.timeoutInterval = 60
        request.setValue(
            "multipart/form-data; boundary=\(boundary)",
            forHTTPHeaderField: "Content-Type"
        )
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        var body = Data()
        body.appendASCII("--\(boundary)\r\n")
        // The server names the file after a hash of its contents, so what is
        // claimed here is only a formality.
        body.appendASCII(
            "Content-Disposition: form-data; name=\"image\"; filename=\"upload.jpg\"\r\n"
        )
        body.appendASCII("Content-Type: image/jpeg\r\n\r\n")
        body.append(jpeg)
        body.appendASCII("\r\n--\(boundary)--\r\n")
        request.httpBody = body

        let data = try await send(request)
        struct UploadResponse: Decodable { let path: String }
        do {
            return try decoder.decode(UploadResponse.self, from: data).path
        } catch {
            throw RemotePostRepositoryError.decodingFailed(error)
        }
    }

    func compose(
        text: String,
        images: [String],
        category: PostListCategory,
        token: String?
    ) async throws -> Post {
        struct Payload: Encodable {
            let text: String
            let images: [String]
            let category: String
        }

        var request = URLRequest(url: baseURL.appendingPathComponent("api/posts"))
        request.httpMethod = "POST"
        request.timeoutInterval = 30
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        if let token {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        request.httpBody = try JSONEncoder().encode(
            Payload(
                text: text,
                // Sent back as server-relative paths: the absolute URLs this
                // client holds were built from a base URL the server does not
                // know about.
                images: images.map(relativeMediaReference),
                category: category.rawValue
            )
        )

        let data = try await send(request)
        do {
            var post = try decoder.decode(Post.self, from: data)
            post.author.avatar = absoluteMediaReference(post.author.avatar)
            post.images = post.images.map(absoluteMediaReference)
            return post
        } catch {
            throw RemotePostRepositoryError.decodingFailed(error)
        }
    }

    /// Performs a request and returns its body, mapping failures the same way
    /// the read path does.
    private func send(_ request: URLRequest) async throws -> Data {
        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch let error as URLError {
            throw RemotePostRepositoryError.transportFailed(error)
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            throw RemotePostRepositoryError.invalidResponse
        }
        guard 200..<300 ~= httpResponse.statusCode else {
            throw RemotePostRepositoryError.httpStatus(httpResponse.statusCode)
        }
        return data
    }

    private func relativeMediaReference(_ reference: String) -> String {
        guard
            let url = URL(string: reference),
            url.scheme != nil,
            url.host != nil
        else {
            return reference
        }
        return url.path
    }
}

private extension Data {
    /// Multipart framing is ASCII by definition; the payload itself is
    /// appended as raw bytes.
    mutating func appendASCII(_ string: String) {
        append(Data(string.utf8))
    }
}

enum RemotePostRepositoryError: LocalizedError {
    case transportFailed(URLError)
    case invalidResponse
    case httpStatus(Int)
    case decodingFailed(Error)
    case imageEncodingFailed

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
        case .imageEncodingFailed:
            return "無法處理選取的圖片。"
        }
    }
}
