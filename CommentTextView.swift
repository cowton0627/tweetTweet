//
//  CommentTextView.swift
//  tweetTweet
//  Created by 鄭淳澧 on 2021/5/24.
//

import SwiftUI

struct CommentTextView: UIViewRepresentable {
    @Binding var text: String
    
    let beginEdittingOnAppear: Bool
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    func makeUIView(context: Context) -> UITextView {
        let view = UITextView()
        view.backgroundColor = .systemGray6
        view.font = .systemFont(ofSize: 18)
        view.textContainerInset = UIEdgeInsets(top: 15, left: 15, bottom: 15, right: 15)
        view.delegate = context.coordinator
        view.text = text
        return view
    }
    
    func updateUIView(_ uiView: UITextView, context: Context) {
        if beginEdittingOnAppear,
           !context.coordinator.didBecomeFirstResponder,
           uiView.window != nil,
           !uiView.isFirstResponder {
            uiView.becomeFirstResponder()
            context.coordinator.didBecomeFirstResponder = true
        }
    }
    
    class Coordinator: NSObject, UITextViewDelegate {
        let parent: CommentTextView
        var didBecomeFirstResponder: Bool = false
        
        init(_ view: CommentTextView) { parent = view }
        
        func textViewDidChange(_ textView: UITextView) {
            parent.text = textView.text
        }
    }
}

struct CommentTextView_Previews: PreviewProvider {
    static var previews: some View {
        CommentTextView(text: .constant(""), beginEdittingOnAppear: true)
    }
}
