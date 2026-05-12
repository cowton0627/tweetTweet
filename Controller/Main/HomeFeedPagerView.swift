//
//  HomeFeedPagerView.swift
//  tweetTweet
//
//  Created by Codex on 2026/5/11.
//

import SwiftUI

struct HomeFeedPagerView: View {
    @Binding var leftPercent: CGFloat
    let onSelectPost: (Post) -> Void

    var body: some View {
        GeometryReader { proxy in
            HScrollView(pageWidth: proxy.size.width,
                        contentSize: CGSize(width: proxy.size.width * 2,
                                            height: proxy.size.height),
                        leftPercent: $leftPercent) {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 0) {
                        PostListView(category: .recommend, onSelectPost: onSelectPost)
                            .frame(width: proxy.size.width)
                        PostListView(category: .hot, onSelectPost: onSelectPost)
                            .frame(width: proxy.size.width)
                    }
                }
            }
        }
    }
}
