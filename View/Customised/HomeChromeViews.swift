//
//  HomeChromeViews.swift
//  tweetTweet
//
//  Created by Codex on 2026/5/11.
//

import SwiftUI

struct HomeTopChromeView: View {
    @Binding var leftPercent: CGFloat
    let onCamera: () -> Void
    let onCompose: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Button(action: onCamera) {
                Image(systemName: "camera")
                    .font(.system(size: 17, weight: .regular))
                    .frame(width: 40, height: 40)
            }
            .foregroundColor(.blue)
            .buttonStyle(PlainButtonStyle())

            Spacer(minLength: 0)

            HomeNavigationBar(leftPercent: $leftPercent)

            Spacer(minLength: 0)

            Button(action: onCompose) {
                Image(systemName: "plus.circle.fill")
                    .font(.system(size: 20))
                    .frame(width: 40, height: 40)
            }
            .foregroundColor(.orange)
            .buttonStyle(PlainButtonStyle())
        }
        .padding(.horizontal, 12)
        .padding(.top, 8)
        .padding(.bottom, 10)
        .background(Color(.systemBackground))
        .overlay(Divider(), alignment: .bottom)
    }
}

struct HomeBottomChromeView: View {
    @Binding var leftPercent: CGFloat
    let onRecommend: () -> Void
    let onHot: () -> Void
    let onSearch: () -> Void
    let onCamera: () -> Void
    let onCompose: () -> Void

    var body: some View {
        HStack(spacing: 0) {
            BottomChromeButton(title: "推薦", systemImage: "house.fill", isSelected: leftPercent < 0.5, action: onRecommend)
            Spacer(minLength: 0)
            BottomChromeButton(title: "熱門", systemImage: "flame.fill", isSelected: leftPercent >= 0.5, action: onHot)
            Spacer(minLength: 0)
            BottomChromeButton(title: "搜尋", systemImage: "magnifyingglass", isSelected: false, action: onSearch)
            Spacer(minLength: 0)
            BottomChromeButton(title: "圖片", systemImage: "camera", isSelected: false, action: onCamera)
            Spacer(minLength: 0)
            BottomChromeButton(title: "發文", systemImage: "square.and.pencil", isSelected: false, action: onCompose)
        }
        .padding(.horizontal, 10)
        .padding(.top, 6)
        .padding(.bottom, 8)
        .background(Color(.systemBackground))
        .overlay(Divider(), alignment: .top)
    }
}

struct BottomChromeButton: View {
    let title: String
    let systemImage: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: systemImage)
                    .font(.system(size: 16, weight: .semibold))
                Text(title)
                    .font(.system(size: 11, weight: .medium))
            }
            .frame(width: 52, height: 44)
        }
        .foregroundColor(isSelected ? .orange : .secondary)
        .buttonStyle(PlainButtonStyle())
    }
}
