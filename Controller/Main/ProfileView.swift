//
//  ProfileView.swift
//  tweetTweet
//
//  The signed-in account, or an invitation to sign in.
//

import SwiftUI

struct ProfileView: View {
    @EnvironmentObject private var authStore: AuthStore
    @EnvironmentObject private var userData: UserData
    @State private var showingSignIn = false

    var body: some View {
        Group {
            if let user = authStore.user {
                // The same screen anyone else's account gets. Two screens
                // would drift apart, and the difference is one button.
                AccountView(
                    handle: user.handle,
                    profileService: userData.profileService,
                    interactions: userData.interactionService,
                    onSignOut: { authStore.signOut() }
                )
                .id(user.handle)
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
        ProfileView()
            .environmentObject(AuthStore(service: nil))
            .environmentObject(UserData())
    }
}
