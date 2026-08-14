//
//  HomeView.swift
//  tweetTweet
//  Created by 鄭淳澧 on 2021/5/8.
//

import SwiftUI

/// The feed. Owns the recommend/hot split and nothing else.
///
/// Composing, searching and picking images used to live here too, which is how
/// the same action ended up with an entry point at the top and another at the
/// bottom. Those belong to the tab bar and to the composer respectively.
struct HomeView: View {
    @State var leftPercent: CGFloat = 0
    @State private var selectedPost: Post?

    @EnvironmentObject private var userData: UserData
    @EnvironmentObject private var authStore: AuthStore

    var body: some View {
        ZStack {
            Color(.systemBackground)
                .ignoresSafeArea()

            HomeFeedPagerView(leftPercent: $leftPercent) { post in
                selectedPost = post
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .safeAreaInset(edge: .top, spacing: 0) {
            HomeTopChromeView(leftPercent: $leftPercent)
        }
        .sheet(item: $selectedPost) { post in
            // A sheet does not inherit environment objects, so both have to be
            // handed across explicitly — the cells inside need the account to
            // know whose posts these are.
            PostDetailView(post: post)
                .environmentObject(userData)
                .environmentObject(authStore)
        }
    }
}

/// The feed's own header: which of its two pages you are on.
struct HomeTopChromeView: View {
    @Binding var leftPercent: CGFloat

    var body: some View {
        HomeNavigationBar(leftPercent: $leftPercent)
            .frame(maxWidth: .infinity)
            .padding(.top, 8)
            .padding(.bottom, 10)
            .background(Color(.systemBackground))
            .overlay(Divider(), alignment: .bottom)
            .dynamicTypeSize(...DynamicTypeSize.accessibility1)
    }
}

struct HomeView_Previews: PreviewProvider {
    static var previews: some View {
        HomeView().environmentObject(UserData())
    }
}
