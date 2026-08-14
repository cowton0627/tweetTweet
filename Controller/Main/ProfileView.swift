//
//  ProfileView.swift
//  tweetTweet
//
//  The signed-in account, or an invitation to sign in.
//

import SwiftUI

struct ProfileView: View {
    @EnvironmentObject private var authStore: AuthStore
    @State private var showingSignIn = false

    var body: some View {
        Group {
            if let user = authStore.user {
                signedIn(as: user)
            } else {
                signedOut
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemBackground))
        .sheet(isPresented: $showingSignIn) {
            SignInView().environmentObject(authStore)
        }
    }

    private func signedIn(as user: Author) -> some View {
        VStack(spacing: 16) {
            PostImage(reference: user.avatar)
                .frame(width: 88, height: 88)
                .clipShape(Circle())
                .overlay(
                    PostVIPBadge(vip: user.vip).offset(x: 30, y: 30)
                )
                .accessibilityHidden(true)

            VStack(spacing: 4) {
                Text(user.displayName)
                    .font(.title3.weight(.semibold))
                Text("@\(user.handle)")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel("\(user.displayName)，帳號名稱 \(user.handle)")

            Text("你的貼文與追蹤之後會出現在這裡。")
                .font(.footnote)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

            Button(role: .destructive) {
                authStore.signOut()
            } label: {
                Text("登出")
            }
            .padding(.top, 8)
        }
        .padding()
    }

    private var signedOut: some View {
        VStack(spacing: 12) {
            Image(systemName: "person.crop.circle")
                .font(.largeTitle)
                .foregroundColor(.secondary)
            Text("還沒有登入")
                .font(.headline)
            Text(
                authStore.canSignIn
                    ? "登入之後，你的貼文與追蹤都會出現在這裡。"
                    : "目前沒有連線到後端，所以無法登入。"
            )
            .font(.subheadline)
            .foregroundColor(.secondary)
            .multilineTextAlignment(.center)
            .padding(.horizontal, 32)

            if authStore.canSignIn {
                Button(action: { showingSignIn = true }) {
                    Text("登入或註冊").bold()
                }
                .padding(.top, 4)
            }
        }
    }
}

struct ProfileView_Previews: PreviewProvider {
    static var previews: some View {
        ProfileView().environmentObject(AuthStore(service: nil))
    }
}
