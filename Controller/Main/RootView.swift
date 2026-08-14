//
//  RootView.swift
//  tweetTweet
//
//  Owns the tab bar and decides which area is on screen.
//

import SwiftUI

/// The areas a reader can be in.
///
/// Composing is deliberately not a case: it is an action that presents over
/// whatever you were looking at, not a place you navigate to. Modelling it as a
/// tab is what let it grow four separate entry points.
enum AppTab: CaseIterable {
    case home
    case search
    case notifications
    case profile

    var title: String {
        switch self {
        case .home: return "首頁"
        case .search: return "搜尋"
        case .notifications: return "通知"
        case .profile: return "個人"
        }
    }

    var systemImage: String {
        switch self {
        case .home: return "house.fill"
        case .search: return "magnifyingglass"
        case .notifications: return "bell.fill"
        case .profile: return "person.fill"
        }
    }
}

struct RootView: View {
    @State private var tab: AppTab = .home
    @State private var composeDraft: ComposeDraft?

    @EnvironmentObject private var userData: UserData
    @EnvironmentObject private var authStore: AuthStore

    var body: some View {
        ZStack {
            Color(.systemBackground).ignoresSafeArea()

            switch tab {
            case .home:
                HomeView()
            case .search:
                HomeSearchView()
            case .notifications:
                NotificationsView()
            case .profile:
                ProfileView()
            }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            AppTabBar(
                selection: $tab,
                onCompose: { composeDraft = ComposeDraft() }
            )
        }
        .sheet(item: $composeDraft) { _ in
            ComposePostView()
                .environmentObject(userData)
                .environmentObject(authStore)
        }
        .task {
            // Restoring the session first, so the feed request can carry it —
            // without a token the server has no reader to compute `isLiked`
            // and `isFollowed` against, and everything comes back untouched.
            await authStore.restore()
            await userData.loadAll(token: authStore.token)
        }
        // Signing in or out changes what the feed says about the reader, not
        // just who the profile tab shows.
        .onChange(of: authStore.token) { token in
            Task { await userData.loadAll(token: token) }
        }
    }
}

/// Identifies one presentation of the composer. Carries nothing: the composer
/// gathers its own text and images now.
struct ComposeDraft: Identifiable {
    let id = UUID()
}

struct RootView_Previews: PreviewProvider {
    static var previews: some View {
        RootView()
            .environmentObject(UserData())
            .environmentObject(AuthStore(service: nil))
    }
}
