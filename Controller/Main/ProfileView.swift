//
//  ProfileView.swift
//  tweetTweet
//
//  Placeholder until there are accounts.
//

import SwiftUI

/// Deliberately empty.
///
/// Every post currently belongs to the same stand-in author, so there is no
/// "you" to show. The tab is here so the shape of the app stops changing once
/// accounts land.
struct ProfileView: View {
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "person.crop.circle")
                .font(.largeTitle)
                .foregroundColor(.secondary)
            Text("還沒有帳號")
                .font(.headline)
            Text("登入之後，你的貼文與追蹤都會出現在這裡。")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemBackground))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("個人。還沒有帳號。登入之後，你的貼文與追蹤都會出現在這裡。")
    }
}

struct ProfileView_Previews: PreviewProvider {
    static var previews: some View {
        ProfileView()
    }
}
