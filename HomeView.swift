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
    @State private var pendingComposeImages: [String]?

    @EnvironmentObject private var userData: UserData

    init() {
        // UIKit-style: 讓 nav bar 自己鋪 status bar 區的背景，避免黑邊
        let appearance = UINavigationBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = .systemBackground
        appearance.shadowColor = .clear     //去除底部 hairline
        UINavigationBar.appearance().standardAppearance = appearance
        UINavigationBar.appearance().scrollEdgeAppearance = appearance
        UINavigationBar.appearance().compactAppearance = appearance
    }

    var body: some View {
        NavigationView {
            ZStack {
                Color(.systemBackground)
                    .ignoresSafeArea()

                HScrollViewController(pageWidth: UIScreen.main.bounds.width,
                                      contentSize: CGSize(width: UIScreen.main.bounds.width * 2,
                                                          height: UIScreen.main.bounds.height),
                                      leftPercent: self.$leftPercent)
                {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 0) {
                            PostListView(category: .recommend)
                                .frame(width: UIScreen.main.bounds.width)
                            PostListView(category: .hot)
                                .frame(width: UIScreen.main.bounds.width)
                        }
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: { showingMediaPicker = true }) {
                        Image(systemName: "camera")
                            .font(.system(size: 17, weight: .regular))
                            .foregroundColor(.blue)
                    }
                }
                ToolbarItem(placement: .principal) {
                    HomeNavigationBar(leftPercent: $leftPercent)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        composeDraft = ComposeDraft(attachedImages: [], initialCategory: currentCategory)
                    }) {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 20))
                            .foregroundColor(.orange)
                    }
                }
            }
            .sheet(item: $composeDraft) { draft in
                ComposePostView(attachedImages: draft.attachedImages,
                                initialCategory: draft.initialCategory)
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
        .navigationViewStyle(StackNavigationViewStyle())    //使ipad樣式與iphone一樣
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
