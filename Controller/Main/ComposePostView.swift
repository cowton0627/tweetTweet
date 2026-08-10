//
//  ComposePostView.swift
//  tweetTweet
//
//  Created by Codex on 2026/5/11.
//

import SwiftUI

struct ComposePostView: View {
    let attachedImages: [String]
    let initialCategory: PostListCategory

    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var userData: UserData

    @State private var text: String = ""
    @State private var category: PostListCategory
    @State private var showEmptyTextHUD: Bool = false
    @State private var isSending: Bool = false
    @State private var failureMessage: String?

    init(attachedImages: [String] = [], initialCategory: PostListCategory = .recommend) {
        self.attachedImages = attachedImages
        self.initialCategory = initialCategory
        self._category = State(initialValue: initialCategory)
    }

    var body: some View {
        NavigationView {
            VStack(spacing: 16) {
                Picker("發文至", selection: $category) {
                    ForEach(PostListCategory.allCases, id: \.self) { value in
                        Text(value.title).tag(value)
                    }
                }
                .pickerStyle(SegmentedPickerStyle())

                VStack(alignment: .leading, spacing: 12) {
                    TextEditor(text: $text)
                        .frame(minHeight: 180)
                        .padding(4)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .stroke(Color.secondary.opacity(0.2), lineWidth: 1)
                        )

                    if !attachedImages.isEmpty {
                        PostImageCell(images: attachedImages, width: UIScreen.main.bounds.width - 40)
                    }
                }
                .padding(.top, 4)

                Spacer()
            }
            .padding(16)
            .navigationTitle("發表新貼文")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    if isSending {
                        ProgressView()
                    } else {
                        Button("送出") {
                            Task { await sendPost() }
                        }
                    }
                }
            }
            .disabled(isSending)
            .alert(
                "無法發表",
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
            .overlay(
                Text("內容不能空白")
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(Color.black.opacity(0.8))
                    .foregroundColor(.white)
                    .clipShape(Capsule())
                    .scaleEffect(showEmptyTextHUD ? 1 : 0.8)
                    .opacity(showEmptyTextHUD ? 1 : 0)
            )
        }
    }

    private func sendPost() async {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            showEmptyTextHUD = true
            try? await Task.sleep(nanoseconds: 1_200_000_000)
            showEmptyTextHUD = false
            return
        }

        isSending = true
        defer { isSending = false }

        do {
            try await userData.compose(
                text: trimmed,
                images: attachedImages,
                into: category
            )
            dismiss()
        } catch {
            // Stays on screen with the text intact, so a failed send does not
            // cost the reader what they wrote.
            failureMessage = error.localizedDescription
        }
    }
}

struct ComposePostView_Previews: PreviewProvider {
    static var previews: some View {
        ComposePostView(attachedImages: ["post-01.jpg"], initialCategory: .recommend)
            .environmentObject(UserData())
    }
}
