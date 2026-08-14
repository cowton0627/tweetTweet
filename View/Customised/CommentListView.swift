//
//  CommentListView.swift
//  tweetTweet
//
//  A post's replies, and the bar for adding one.
//

import SwiftUI

/// The thread itself.
///
/// Reading and writing sit on the same screen rather than a sheet appearing
/// over the post. That is what Facebook, Threads and Instagram all do, and the
/// reason is that a reply is a response to what is on screen — hiding the post
/// behind a modal to write one throws away the thing being replied to.
struct CommentListView: View {
    @ObservedObject var thread: CommentThread
    let onLoadEarlier: () -> Void
    let onDelete: (Comment) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            if thread.hasEarlier {
                Button(action: onLoadEarlier) {
                    HStack(spacing: 6) {
                        if thread.isLoading {
                            ProgressView()
                        }
                        Text("查看先前的回應")
                            .font(.subheadline.weight(.medium))
                    }
                }
                .buttonStyle(PlainButtonStyle())
                .foregroundColor(.orange)
                .accessibilityHint("載入更早的回應")
            }

            if thread.comments.isEmpty {
                if thread.isLoading {
                    ProgressView()
                        .frame(maxWidth: .infinity, alignment: .center)
                } else {
                    Text("還沒有人回應，成為第一個。")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            } else {
                ForEach(thread.comments) { comment in
                    CommentRow(comment: comment, onDelete: { onDelete(comment) })
                }
            }
        }
    }
}

private struct CommentRow: View {
    let comment: Comment
    let onDelete: () -> Void

    @State private var showingActions = false

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            PostImage(reference: comment.author.avatar)
                .frame(width: 32, height: 32)
                .clipShape(Circle())
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(comment.author.displayName)
                        .font(.subheadline.weight(.semibold))
                    Text(comment.displayDate)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                Text(comment.text)
                    .font(.subheadline)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)
        }
        .contentShape(Rectangle())
        // Secondary actions hide behind a long press rather than sitting on
        // screen: deleting is rare, and a button beside every reply would be
        // the loudest thing in the thread.
        .onLongPressGesture {
            guard comment.isMine else { return }
            showingActions = true
        }
        .confirmationDialog(
            "這則回應",
            isPresented: $showingActions,
            titleVisibility: .visible
        ) {
            Button("刪除", role: .destructive, action: onDelete)
            Button("取消", role: .cancel) {}
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(comment.author.displayName)：\(comment.text)")
        // accessibilityAction(named:) rather than accessibilityActions, which
        // needs iOS 16; this project still supports 15.
        .accessibilityAction(named: Text("刪除回應")) {
            if comment.isMine { onDelete() }
        }
    }
}

/// The fixed bar at the bottom of the detail screen.
struct CommentComposer: View {
    @Binding var text: String
    let isSending: Bool
    let onSend: () -> Void

    @FocusState private var focused: Bool

    var body: some View {
        HStack(spacing: 10) {
            // A single line rather than a growing field: the vertical-axis
            // TextField arrived in iOS 16 and this project supports 15. A long
            // reply still scrolls within the field.
            TextField("寫下回應…", text: $text)
                .textFieldStyle(PlainTextFieldStyle())
                .padding(.horizontal, 14)
                .padding(.vertical, 9)
                .background(
                    Capsule().fill(Color(.secondarySystemBackground))
                )
                .focused($focused)

            if isSending {
                ProgressView().padding(.trailing, 4)
            } else {
                Button(action: onSend) {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.title2)
                }
                .buttonStyle(PlainButtonStyle())
                .foregroundColor(canSend ? .orange : .secondary)
                .disabled(!canSend)
                .accessibilityLabel("送出回應")
            }
        }
        .padding(.horizontal, 15)
        .padding(.vertical, 10)
        .background(.bar)
    }

    private var canSend: Bool {
        !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}

struct CommentListView_Previews: PreviewProvider {
    static var previews: some View {
        CommentListView(
            thread: CommentThread(postID: 1, service: nil, seeded: [.preview]),
            onLoadEarlier: {},
            onDelete: { _ in }
        )
        .padding()
    }
}
