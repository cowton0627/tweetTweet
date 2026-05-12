//
//  HomeView.swift
//  tweetTweet
//
//  Created by 鄭淳澧 on 2021/5/8.
//

import SwiftUI

struct HomeView: View {
    @State var leftPercent: CGFloat = 0
    @State private var composeDraft: ComposeDraft?
    @State private var showingMediaPicker: Bool = false
    @State private var showingSearch: Bool = false
    @State private var pendingComposeImages: [String]?
    @State private var selectedPost: Post?

    @EnvironmentObject private var userData: UserData

    var body: some View {
        ZStack {
            Color.white
                .ignoresSafeArea()

            HomeFeedPagerView(leftPercent: $leftPercent) { post in
                selectedPost = post
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .safeAreaInset(edge: .top, spacing: 0) {
            HomeTopChromeView(leftPercent: $leftPercent,
                              onCamera: { showingMediaPicker = true },
                              onCompose: { composeDraft = ComposeDraft(attachedImages: [], initialCategory: currentCategory) })
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            HomeBottomChromeView(leftPercent: $leftPercent,
                                 onRecommend: { withAnimation { leftPercent = 0 } },
                                 onHot: { withAnimation { leftPercent = 1 } },
                                 onSearch: { showingSearch = true },
                                 onCamera: { showingMediaPicker = true },
                                 onCompose: { composeDraft = ComposeDraft(attachedImages: [], initialCategory: currentCategory) })
        }
        .sheet(item: $composeDraft) { draft in
            ComposePostView(attachedImages: draft.attachedImages,
                            initialCategory: draft.initialCategory)
            .environmentObject(userData)
        }
        .sheet(item: $selectedPost) { post in
            PostDetailView(post: post)
                .environmentObject(userData)
        }
        .sheet(isPresented: $showingSearch) {
            HomeSearchView()
                .environmentObject(userData)
        }
        .sheet(isPresented: $showingMediaPicker, onDismiss: {
            guard let pendingComposeImages else { return }
            composeDraft = ComposeDraft(attachedImages: pendingComposeImages,
                                        initialCategory: currentCategory)
            self.pendingComposeImages = nil
        }) {
            MediaPickerView(imageNames: userData.imageLibrary()) { selectedImages in
                pendingComposeImages = selectedImages
            }
        }
    }

    private var currentCategory: PostListCategory {
        leftPercent < 0.5 ? .recommend : .hot
    }
}

private struct ComposeDraft: Identifiable {
    let id = UUID()
    let attachedImages: [String]
    let initialCategory: PostListCategory
}


struct HomeView_Previews: PreviewProvider {
    static var previews: some View {
        HomeView().environmentObject(UserData())
    }
}
