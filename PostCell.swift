//
//  PostCell.swift
//  tweetTweet
//  Created by 鄭淳澧 on 2021/5/5.
//

import SwiftUI

struct PostCell: View {
    let post: Post
    
    var bindingPost: Post {
        userData.post(forId: post.id)!
    }
    
    @State var presentComment: Bool = false
    
    @EnvironmentObject var userData: UserData
    
    var body: some View {
        var post = bindingPost
        return VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 5) {
                post.avatarImage    //前用 Image(uiImage: UIImage(named: "圖片名"))
                                    //圖片名又引用了post.avatar
                    .resizable()
                    .scaledToFill()
                    .frame(width: 56, height: 56)
                    .clipShape(Circle())    //圖片切成圓形
                    .overlay(
                        PostVIPBadge(vip: post.vip)     //以VIPBadge編寫後引用
                            .offset(x: 16, y: 16)       //覆蓋在用戶頭貼上, 偏移位置
                    )
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(post.name)     //以Post編寫後引用
                        .font(Font.system(size: 21))
                        .foregroundColor(Color(red: 242 / 255, green: 99 / 255, blue: 4 / 255))
                        .lineLimit(1)   //限制用戶名的行數為一行, 超出的會用"..."表示
                    Text(post.date)     //以Post編寫後引用
                        .font(.system(size: 17))
                        .foregroundColor(.gray)
                }
                .padding(.leading, 10)
                
                    Spacer()
                
                if !post.isFollowed {
                    Button(action:{
//                        print("Click follow button")    //以Debug模式執行, 下方會print此段文字
                        post.isFollowed =  true
                        self.userData.update(post)
                    }) {
                    Text("追蹤")
                        .font(.system(size: 17))    //原為Font.system, 在.font裡, Font可省略
                        .foregroundColor(.orange)   //同上, forgroundColor裡, Color.顏色, Color可省略
                        .frame(width: 50, height: 26)
                        .overlay(                                   //覆蓋Text("追蹤")
                            RoundedRectangle(cornerRadius: 13)      //加圓角矩形邊框, 半徑為Text高度的一半
                                .stroke(Color.orange, lineWidth: 2) //畫圓角矩形邊框的顏色, 線寬
                        )
                        
                    }
                    .buttonStyle(BorderlessButtonStyle())   //此段為只有按鈕可以響應點擊事件 (點擊按鈕變成淺灰色效果)
                }
            }
            Text(post.text)
                .font(.system(size:18))
            
            
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
