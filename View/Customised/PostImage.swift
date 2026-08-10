//
//  PostImage.swift
//  tweetTweet
//
//  Displays a post image regardless of where it lives.
//

import SwiftUI

/// Renders an image reference that may be a bundled filename, a key into
/// `RuntimeImageStore`, or a URL on the backend.
///
/// Every call site wants the same treatment — fill the space it is given and
/// let the caller clip it — so `resizable()` and `scaledToFill()` live here
/// rather than being repeated at each one.
struct PostImage: View {
    let reference: String

    @State private var image: UIImage?
    @State private var didFail = false

    private var remoteURL: URL? {
        guard
            let url = URL(string: reference),
            url.scheme != nil,
            url.host != nil
        else {
            return nil
        }
        return url
    }

    var body: some View {
        Group {
            if let remoteURL {
                remoteBody(for: remoteURL)
            } else {
                loadImage(name: reference)
                    .resizable()
                    .scaledToFill()
            }
        }
    }

    @ViewBuilder
    private func remoteBody(for url: URL) -> some View {
        if let image {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
        } else {
            placeholder
                // Keyed on the URL so a recycled cell showing a different post
                // starts the right download instead of keeping the old one.
                .task(id: url) {
                    await load(url)
                }
        }
    }

    private var placeholder: some View {
        ZStack {
            Rectangle()
                .fill(Color(.secondarySystemBackground))
            if didFail {
                Image(systemName: "photo")
                    .foregroundColor(.secondary)
            }
        }
        .accessibilityHidden(true)
    }

    private func load(_ url: URL) async {
        didFail = false
        do {
            let loaded = try await RemoteImageLoader.shared.image(for: url)
            guard !Task.isCancelled else { return }
            image = loaded
        } catch is CancellationError {
            // Scrolled away before it arrived; not a failure worth showing.
        } catch {
            guard !Task.isCancelled else { return }
            didFail = true
        }
    }
}
