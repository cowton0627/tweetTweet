//
//  PostCell.swift
//  tweetTweet
//  Created by 鄭淳澧 on 2021/5/5.
//

import SwiftUI

struct PostCell: View {
    let post: Post
    
    var bindingPost: Post {
        userData.post(forId: post.id) ?? post
    }
    
    @State var presentComment: Bool = false
    
    @EnvironmentObject var userData: UserData
    
    var body: some View {
        var post = bindingPost
        return VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                post.avatarImage
                    .resizable()
                    .scaledToFill()
                    .frame(width: 48, height: 48)
                    .clipShape(Circle())
                    .overlay(
                        PostVIPBadge(vip: post.vip)
                            .offset(x: 14, y: 14)
                    )
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 2) {
                    Text(post.name)
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(Color(red: 242 / 255, green: 99 / 255, blue: 4 / 255))
                        .lineLimit(1)
                    Text(post.date)
                        .font(.system(size: 13))
                        .foregroundColor(.gray)
                        .lineLimit(1)
                }

                Spacer()

                if !post.isFollowed {
                    Button(action:{
                        post.isFollowed =  true
                        self.userData.update(post)
                    }) {
                    Text("追蹤")
                        .font(.system(size: 14))
                        .foregroundColor(.orange)
                        .frame(width: 56, height: 28)
                        .overlay(
                            RoundedRectangle(cornerRadius: 14)
                                .stroke(Color.orange, lineWidth: 1.5)
                        )
                    }
                    .buttonStyle(BorderlessButtonStyle())
                    .accessibilityHint("追蹤 \(post.name)")
                }
            }
            Text(post.text)
                .font(.system(size: 16))
                .lineSpacing(4)
                .fixedSize(horizontal: false, vertical: true)
            
            
            if !post.images.isEmpty {
                PostImageCell(images: post.images, width: UIScreen.main.bounds.width - 30)
            }
            
            Divider()
            
            HStack(spacing: 0) {
                Spacer()
                
                PostCellToolbarButton(image: "message",
                                      text: post.commentCountText,
                                      color: .black)
                {
//                    print("Click comment button")
                    self.presentComment =  true //點擊取消讓頁面消失
                }
                .sheet(isPresented: $presentComment) {
                    CommentInputView(post: post).environmentObject(self.userData)
                }
                .accessibilityLabel("回應，\(post.commentCount) 則")
                
                Spacer()
                
                PostCellToolbarButton(image: post.isLiked ? "heart.fill" : "heart",
                                      text: post.likeCountText,
                                      color: post.isLiked ? .red : .black)
                {
//                    print("Click like button")
                    if post.isLiked {
                        post.isLiked = false
                        post.likeCount -=  1
                    }else {
                        post.isLiked = true
                        post.likeCount += 1
                    }
                    self.userData.update(post)
                }
                .accessibilityLabel(
                    post.isLiked
                        ? "取消喜歡，目前 \(post.likeCount) 個喜歡"
                        : "喜歡，目前 \(post.likeCount) 個喜歡"
                )
                
                Spacer()
            }
            
            Rectangle()
                .padding(.horizontal, -15)
                .frame(height: 10)
                .foregroundColor(Color(red: 238 / 255, green: 238 / 255, blue: 238 / 255))
        }
        .padding(.horizontal, 15)
        .padding(.top, 15)
        
    }
}


struct PostCell_Previews: PreviewProvider {
    static var previews: some View {
        let post = Post.preview
        let userData = UserData(initialRecommendPosts: PostList(list: [post]))
        return PostCell(post: post).environmentObject(userData)
    }
}
