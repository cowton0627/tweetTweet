//
//  MediaPickerView.swift
//  tweetTweet
//
//  Created by Codex on 2026/5/11.
//

import SwiftUI

struct MediaPickerView: View {
    let imageNames: [String]
    let onPick: ([String]) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var selectedImage: String?

    private let columns = [
        GridItem(.adaptive(minimum: 96), spacing: 12)
    ]

    var body: some View {
        NavigationView {
            ScrollView {
                LazyVGrid(columns: columns, spacing: 12) {
                    ForEach(imageNames, id: \.self) { name in
                        Button(action: {
                            selectedImage = name
                        }) {
                            loadImage(name: name)
                                .resizable()
                                .scaledToFill()
                                .frame(width: 96, height: 96)
                                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                                        .stroke(selectedImage == name ? Color.orange : Color.clear, lineWidth: 3)
                                )
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
                .padding(16)
            }
            .navigationTitle("選擇圖片")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("下一步") {
                        guard let selectedImage else { return }
                        onPick([selectedImage])
                        dismiss()
                    }
                    .disabled(selectedImage == nil)
                }
            }
        }
    }
}

struct MediaPickerView_Previews: PreviewProvider {
    static var previews: some View {
        MediaPickerView(imageNames: UserData().imageLibrary(), onPick: { _ in })
    }
}
