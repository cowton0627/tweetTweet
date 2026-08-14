//
//  ProfileStore.swift
//  tweetTweet
//
//  One account's page, while it is open.
//

import Foundation

/// Owned by the screen showing it, for the same reason `CommentThread` is: a
/// profile is only interesting while you are looking at it, and keeping every
/// account anyone has tapped in the shared store would mean deciding when to
/// let them go.
@MainActor
final class ProfileStore: ObservableObject {
    enum State: Equatable {
        case loading
        case loaded
        case failed(message: String)
    }

    @Published private(set) var profile: Profile?
    @Published private(set) var posts: [Post] = []
    @Published private(set) var state: State = .loading
    @Published var failureMessage: String?

    let handle: String
    private let service: ProfileService?
    private let interactions: PostInteractions?

    init(
        handle: String,
        service: ProfileService?,
        interactions: PostInteractions? = nil
    ) {
        self.handle = handle
        self.service = service
        self.interactions = interactions
    }

    func load(token: String?) async {
        guard let service else {
            state = .failed(message: "目前沒有連線到後端。")
            return
        }
        state = .loading

        do {
            // Both at once: neither needs the other, and a profile that draws
            // its header a beat before its posts looks like two screens.
            async let profileRequest = service.profile(forHandle: handle, token: token)
            async let postsRequest = service.posts(byHandle: handle, token: token)
            profile = try await profileRequest
            posts = try await postsRequest
            state = .loaded
        } catch {
            state = .failed(message: error.localizedDescription)
        }
    }

    /// Follows or unfollows this account, optimistically.
    func setFollow(_ followed: Bool, token: String?) async {
        guard let interactions, let token, var current = profile else { return }
        let previous = current

        current.isFollowed = followed
        current.followerCount = max(0, current.followerCount + (followed ? 1 : -1))
        profile = current

        do {
            try await interactions.setFollow(followed, handle: handle, token: token)
        } catch {
            profile = previous
            failureMessage = error.localizedDescription
        }
    }
}
