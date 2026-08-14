//
//  NotificationsView.swift
//  tweetTweet
//
//  Placeholder until there are accounts to notify.
//

import SwiftUI

/// Deliberately empty.
///
/// Notifications need accounts before they can mean anything — there is nobody
/// to be notified about yet. The tab exists now so the information architecture
/// is settled before the features arrive, rather than being rearranged again
/// later.
struct NotificationsView: View {
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "bell")
                .font(.largeTitle)
                .foregroundColor(.secondary)
            Text("還沒有通知")
                .font(.headline)
            Text("有人回應或追蹤你的時候，會出現在這裡。")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemBackground))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("通知。還沒有通知。有人回應或追蹤你的時候，會出現在這裡。")
    }
}

struct NotificationsView_Previews: PreviewProvider {
    static var previews: some View {
        NotificationsView()
    }
}
