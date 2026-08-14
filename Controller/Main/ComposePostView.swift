//
//  ComposePostView.swift
//  tweetTweet
//
//  Created by Codex on 2026/5/11.
//

import SwiftUI

struct ComposePostView: View {
    let initialCategory: PostListCategory

    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var userData: UserData

    @State private var text: String = ""
    @State private var category: PostListCategory
    @State private var attachedImages: [String] = []
    @State private var showEmptyTextHUD: Bool = false
    @State private var isSending: Bool = false
    @State private var failureMessage: String?

    // Picking an image belongs to composing, not to navigation: it is a step
    // within writing a post, not somewhere a reader goes. Keeping it here is
    // what collapses four entry points into one.
    @State private var showingSourceSheet: Bool = false
    @State private var showingMediaPicker: Bool = false
    @State private var cameraSource: CameraPicker.Source?

    init(initialCategory: PostListCategory = .recommend) {
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
                        PostImageCell(
                            images: attachedImages,
                            width: UIScreen.main.bounds.width - 40
                        )
                    }

                    Button(action: { showingSourceSheet = true }) {
                        Label(
                            attachedImages.isEmpty ? "加入圖片" : "更換圖片",
                            systemImage: "photo.on.rectangle"
                        )
                        .font(.subheadline)
                    }
                    .buttonStyle(PlainButtonStyle())
                    .foregroundColor(.orange)
                    .accessibilityHint("選擇相機、相簿或內建素材")

                    if !attachedImages.isEmpty {
                        Button(role: .destructive, action: { attachedImages = [] }) {
                            Label("移除圖片", systemImage: "trash")
                                .font(.subheadline)
                        }
                        .buttonStyle(PlainButtonStyle())
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
            .confirmationDialog(
                "加入圖片",
                isPresented: $showingSourceSheet,
                titleVisibility: .visible
            ) {
                if UIImagePickerController.isSourceTypeAvailable(.camera) {
                    Button("拍照") { cameraSource = .camera }
                }
                Button("從相簿選取") { cameraSource = .photoLibrary }
                Button("內建素材庫") { showingMediaPicker = true }
                Button("取消", role: .cancel) {}
            }
            .sheet(isPresented: $showingMediaPicker) {
                MediaPickerView(imageNames: userData.imageLibrary()) { selected in
                    attachedImages = selected
                }
            }
            .sheet(item: $cameraSource) { source in
                CameraPicker(source: source) { image in
                    attachedImages = [RuntimeImageStore.store(image)]
                }
                .ignoresSafeArea()
            }
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
        ComposePostView()
            .environmentObject(UserData())
    }
}
