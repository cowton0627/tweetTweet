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
        let userData = UserData()
//        PostCell(post: postList.list[7])
        return PostCell(post: userData.recommendPostList.list[7]).environmentObject(userData)
    }
}

//Post(avatar: "head001.jpg",
//                vip: true,
//                name: "用戶暱稱",
//                date: "2020-01-01 00:00",
//                isFollowed: false) )
