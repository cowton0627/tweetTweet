//
//  KeychainStore.swift
//  tweetTweet
//
//  Stores the session token.
//

import Foundation
import Security

/// A single secret in the keychain.
///
/// Not UserDefaults: that is a plist in the app container, readable by anything
/// with access to a backup or a jailbroken device. A session token is a
/// bearer credential — whoever holds it is the account.
struct KeychainStore {
    let service: String
    let account: String

    init(service: String = "io.github.cowton0627.tweettweet", account: String = "session-token") {
        self.service = service
        self.account = account
    }

    private var baseQuery: [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
    }

    func save(_ value: String) {
        guard let data = value.data(using: .utf8) else { return }

        // Delete first: SecItemAdd fails on a duplicate, and an update path
        // would need its own query. One code path is easier to be sure about.
        SecItemDelete(baseQuery as CFDictionary)

        var query = baseQuery
        query[kSecValueData as String] = data
        // Readable only while the device is unlocked, and never restored onto a
        // different device from a backup.
        query[kSecAttrAccessible as String] = kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        SecItemAdd(query as CFDictionary, nil)
    }

    func read() -> String? {
        var query = baseQuery
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne

        var item: CFTypeRef?
        guard
            SecItemCopyMatching(query as CFDictionary, &item) == errSecSuccess,
            let data = item as? Data
        else {
            return nil
        }
        return String(data: data, encoding: .utf8)
    }

    func delete() {
        SecItemDelete(baseQuery as CFDictionary)
    }
}
