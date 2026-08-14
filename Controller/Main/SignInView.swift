//
//  SignInView.swift
//  tweetTweet
//
//  Signing in and registering, in one screen.
//

import SwiftUI

/// One screen with a mode switch rather than two screens.
///
/// The fields overlap almost entirely, and people routinely arrive at "sign in"
/// when they meant "register". Switching is a segmented control rather than a
/// navigation step.
struct SignInView: View {
    enum Mode: String, CaseIterable {
        case logIn
        case register

        var title: String {
            switch self {
            case .logIn: return "登入"
            case .register: return "註冊"
            }
        }
    }

    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var authStore: AuthStore

    @State private var mode: Mode = .logIn
    @State private var handle: String = ""
    @State private var displayName: String = ""
    @State private var password: String = ""
    @State private var failureMessage: String?
    @FocusState private var focused: Field?

    private enum Field { case handle, displayName, password }

    var body: some View {
        NavigationView {
            Form {
                Section {
                    Picker("動作", selection: $mode) {
                        ForEach(Mode.allCases, id: \.self) { value in
                            Text(value.title).tag(value)
                        }
                    }
                    .pickerStyle(SegmentedPickerStyle())
                }

                Section {
                    TextField("帳號名稱", text: $handle)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .focused($focused, equals: .handle)
                        .submitLabel(.next)

                    if mode == .register {
                        TextField("顯示名稱", text: $displayName)
                            .focused($focused, equals: .displayName)
                            .submitLabel(.next)
                    }

                    SecureField("密碼", text: $password)
                        .textInputAutocapitalization(.never)
                        .focused($focused, equals: .password)
                        .submitLabel(.go)
                        .onSubmit { Task { await submit() } }
                } footer: {
                    if mode == .register {
                        Text("帳號名稱會出現在你的個人頁網址，之後無法更改。3-20 個字元，只能使用英文小寫、數字或底線。")
                    }
                }

                Section {
                    Button(action: { Task { await submit() } }) {
                        HStack {
                            Spacer()
                            if authStore.isWorking {
                                ProgressView()
                            } else {
                                Text(mode.title).bold()
                            }
                            Spacer()
                        }
                    }
                    .disabled(!canSubmit || authStore.isWorking)
                }
            }
            .navigationTitle(mode.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
            }
            .alert(
                "無法完成",
                isPresented: Binding(
                    get: { failureMessage != nil },
                    set: { if !$0 { failureMessage = nil } }
                ),
                presenting: failureMessage
            ) { _ in
                Button("好", role: .cancel) {}
            } message: { message in
                Text(message)
            }
        }
    }

    private var canSubmit: Bool {
        guard !handle.trimmingCharacters(in: .whitespaces).isEmpty,
              !password.isEmpty else { return false }
        if mode == .register {
            return !displayName.trimmingCharacters(in: .whitespaces).isEmpty
        }
        return true
    }

    private func submit() async {
        guard canSubmit, !authStore.isWorking else { return }
        focused = nil

        let handle = self.handle.trimmingCharacters(in: .whitespaces).lowercased()
        do {
            switch mode {
            case .logIn:
                try await authStore.logIn(handle: handle, password: password)
            case .register:
                try await authStore.register(
                    handle: handle,
                    displayName: displayName.trimmingCharacters(in: .whitespaces),
                    password: password
                )
            }
            dismiss()
        } catch {
            // Leaves what was typed in place; only the password is worth
            // clearing, and even that is a debatable courtesy.
            failureMessage = error.localizedDescription
        }
    }
}

struct SignInView_Previews: PreviewProvider {
    static var previews: some View {
        SignInView().environmentObject(AuthStore(service: nil))
    }
}
