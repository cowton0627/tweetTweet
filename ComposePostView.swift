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
                    Button("送出") {
                        sendPost()
                    }
                }
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

    private func sendPost() {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            showEmptyTextHUD = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                showEmptyTextHUD = false
            }
            return
        }

        let post = Post(
            id: userData.nextPostID(),
            avatar: "head001001.jpg",
            vip: false,
            name: "我",
            date: composeDateString(),
            isFollowed: true,
            text: trimmed,
            images: attachedImages,
            commentCount: 0,
            likeCount: 0,
            isLiked: false
        )

        userData.insert(post, into: category)
        dismiss()
    }

    private func composeDateString() -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd HH:mm"
        return formatter.string(from: Date())
    }
}

struct ComposePostView_Previews: PreviewProvider {
    static var previews: some View {
        ComposePostView(attachedImages: ["head001001.jpg"], initialCategory: .recommend)
            .environmentObject(UserData())
    }
}
