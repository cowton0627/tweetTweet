//
//  APIConfiguration.swift
//  tweetTweet
//
//  Resolves which backend, if any, this build was configured against.
//

import Foundation

enum APIConfiguration {
    static let schemeKey = "APIScheme"
    static let hostKey = "APIHost"

    /// Assembles a base URL from a separate scheme and host.
    ///
    /// They arrive separately because the values come from an xcconfig, where
    /// `//` begins a comment — a full URL written there would silently lose
    /// everything from the slashes onwards.
    ///
    /// Returns `nil` when either part is missing or blank. That is how a build
    /// with no backend configured — including CI — says "use bundled data".
    static func baseURL(scheme: String?, host: String?) -> URL? {
        guard
            let scheme = scheme?.trimmingCharacters(in: .whitespaces),
            !scheme.isEmpty,
            let host = host?.trimmingCharacters(in: .whitespaces),
            !host.isEmpty
        else {
            return nil
        }
        return URL(string: "\(scheme)://\(host)")
    }

    static func baseURL(from bundle: Bundle = .main) -> URL? {
        baseURL(
            scheme: bundle.object(forInfoDictionaryKey: schemeKey) as? String,
            host: bundle.object(forInfoDictionaryKey: hostKey) as? String
        )
    }
}

enum PostRepositoryFactory {
    /// The remote repository when a backend is configured, bundled JSON when
    /// it is not, so the app stays usable with no server running.
    static func makeDefault(bundle: Bundle = .main) -> PostRepository {
        guard let baseURL = APIConfiguration.baseURL(from: bundle) else {
            return LocalPostRepository()
        }
        return RemotePostRepository(baseURL: baseURL)
    }
}
