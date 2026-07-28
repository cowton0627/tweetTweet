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
                    .font(.body)
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .foregroundColor(.blue)
            .buttonStyle(PlainButtonStyle())
            .accessibilityLabel("加入圖片")
            .accessibilityHint("選擇相機、相簿或內建素材")

            Spacer(minLength: 0)

            HomeNavigationBar(leftPercent: $leftPercent)

            Spacer(minLength: 0)

            Button(action: onCompose) {
                Image(systemName: "plus.circle.fill")
                    .font(.title3)
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .foregroundColor(.orange)
            .buttonStyle(PlainButtonStyle())
            .accessibilityLabel("發表新貼文")
        }
        .padding(.horizontal, 12)
        .padding(.top, 8)
        .padding(.bottom, 10)
        .background(Color(.systemBackground))
        .overlay(Divider(), alignment: .bottom)
        .dynamicTypeSize(...DynamicTypeSize.accessibility1)
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
                    .font(.body.weight(.semibold))
                Text(title)
                    .font(.caption2.weight(.medium))
            }
            .frame(minWidth: 56, minHeight: 56)
            .contentShape(Rectangle())
        }
        .foregroundColor(isSelected ? .orange : .secondary)
        .buttonStyle(PlainButtonStyle())
        .accessibilityLabel(title)
        .accessibilityValue(isSelected ? "已選取" : "")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .dynamicTypeSize(...DynamicTypeSize.accessibility1)
    }
}
