//
//  AuthStore.swift
//  tweetTweet
//
//  Who is signed in.
//

import Foundation

@MainActor
final class AuthStore: ObservableObject {
    @Published private(set) var user: Author?
    @Published private(set) var isWorking: Bool = false

    private let service: AuthService?
    private let keychain: KeychainStore

    var isSignedIn: Bool { user != nil }

    /// False offline, where there is no server to hold an account.
    var canSignIn: Bool { service != nil }

    /// The token to send with writes, if there is one.
    private(set) var token: String?

    init(service: AuthService?, keychain: KeychainStore = KeychainStore()) {
        self.service = service
        self.keychain = keychain
    }

    /// Restores a previous session, if the stored token is still good.
    ///
    /// A token that the server rejects is discarded rather than kept around:
    /// holding a credential that does not work only produces confusing 401s
    /// later.
    func restore() async {
        guard let service, let stored = keychain.read() else { return }
        isWorking = true
        defer { isWorking = false }

        do {
            user = try await service.currentUser(token: stored)
            token = stored
        } catch AuthError.rejected(let status, _) where status == 401 {
            keychain.delete()
            token = nil
            user = nil
        } catch {
            // A network failure is not evidence the token is bad, so it stays.
            // The reader simply is not signed in for now.
        }
    }

    func register(handle: String, displayName: String, password: String) async throws {
        guard let service else { throw AuthError.invalidResponse }
        isWorking = true
        defer { isWorking = false }
        adopt(try await service.register(
            handle: handle,
            displayName: displayName,
            password: password
        ))
    }

    func logIn(handle: String, password: String) async throws {
        guard let service else { throw AuthError.invalidResponse }
        isWorking = true
        defer { isWorking = false }
        adopt(try await service.logIn(handle: handle, password: password))
    }

    func signOut() {
        keychain.delete()
        token = nil
        user = nil
    }

    private func adopt(_ session: Session) {
        keychain.save(session.token)
        token = session.token
        user = session.user
    }
}
