//
//  PostVIPBadge.swift
//  tweetTweet
//  Created by 鄭淳澧 on 2021/5/6.
//

import SwiftUI

struct PostVIPBadge: View {
    let vip: Bool
    
    var body: some View {
        Group {     //Group可以用來表示當if不成立的時候什麼都沒有也是一個結果
            if vip {
                Text("✓")
                    .bold()
                    .font(.system(size: 12))
                    .frame(width: 16, height: 16)
                    .foregroundColor(.yellow)
                    .background(Color.green)
                    .clipShape(Circle())
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.black, lineWidth: 1)
                    )
            }
        }
    }
}


struct PostVIPBadge_Previews: PreviewProvider {
    static var previews: some View {
        PostVIPBadge(vip: true)     //以true或false的情況預覽
    }
}

//
//
//struct PostVIPBadge2: View {
//    let vip: Bool
//
//    var body: some View {
//        Group {     //Group可以用來表示當if不成立的時候什麼都沒有也是一個結果
//            if vip {
//                Text("✓")
//                    .bold()
//                    .font(.system(size: 12))
//                    .frame(width: 16, height: 16)
//                    .foregroundColor(.yellow)
//                    .background(Color.green)
//                    .clipShape(Circle())
//                    .overlay(
//                        RoundedRectangle(cornerRadius: 8)
//                            .stroke(Color.black, lineWidth: 1)
//                    )
//            }
//        }
//    }
//}
//
//struct PostVIPBadge2_Previews: PreviewProvider {
//    static var previews: some View {
//        PostVIPBadge2(vip: false)     //以true或false的情況預覽
//    }
//}
