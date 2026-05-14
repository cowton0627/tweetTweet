//
//  RuntimeImageStore.swift
//  tweetTweet
//

import UIKit

enum RuntimeImageStore {
    private static var cache: [String: UIImage] = [:]

    static func store(_ image: UIImage) -> String {
        let key = "runtime_\(UUID().uuidString).jpg"
        cache[key] = image
        return key
    }

    static func image(forKey key: String) -> UIImage? {
        cache[key]
    }
}
