//
//  HomeChromeViews.swift
//  tweetTweet
//
//  The tab bar. One row, one job: which area you are in.
//

import SwiftUI

struct AppTabBar: View {
    @Binding var selection: AppTab
    let onCompose: () -> Void

    var body: some View {
        HStack(spacing: 0) {
            tabButton(.home)
            tabButton(.search)

            // Composing sits in the middle because it is the primary action,
            // but it is not a tab: it presents over the current area rather
            // than replacing it, so it never shows a selected state.
            Button(action: onCompose) {
                Image(systemName: "square.and.pencil")
                    .font(.title3.weight(.semibold))
                    .frame(width: 52, height: 36)
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(Color.orange)
                    )
                    .foregroundColor(.white)
                    .contentShape(Rectangle())
            }
            .frame(maxWidth: .infinity)
            .buttonStyle(PlainButtonStyle())
            .accessibilityLabel("發表新貼文")

            tabButton(.notifications)
            tabButton(.profile)
        }
        .padding(.horizontal, 8)
        .padding(.top, 6)
        .padding(.bottom, 8)
        .background(Color(.systemBackground))
        .overlay(Divider(), alignment: .top)
    }

    private func tabButton(_ tab: AppTab) -> some View {
        TabBarButton(
            title: tab.title,
            systemImage: tab.systemImage,
            isSelected: selection == tab,
            action: { selection = tab }
        )
        .frame(maxWidth: .infinity)
    }
}

struct TabBarButton: View {
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
