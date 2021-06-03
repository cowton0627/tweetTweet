//
//  Post.swift
//  tweetTweet
//  Created by 鄭淳澧 on 2021/5/6.
//

import SwiftUI

struct PostList: Codable {
    var list: [Post]        //再定義一個結構體是為了與JSON文件相對應
}


struct Post: Codable, Identifiable {    //Data Model(資料模型)是不可見的, 或說不可預覽的; 相對視圖來說
    let id: Int
    let avatar: String  //頭貼, 圖片名; 實例變量, 有定義Post才有
    let vip: Bool       //是否為VIP; 實例變量, 有定義Post才有
    let name: String
    let date: String
    
    var isFollowed: Bool
    
    let text: String
    let images: [String]    //圖片是陣列, 陣列的元素是string類型
    
    var commentCount: Int
    var likeCount: Int
    var isLiked: Bool
}
    
    extension Post {    //因為Post裡面是不可視的資料, 所以, 欲將可視的物件加進Post裡用extension
        var avatarImage: Image {
            return loadImage(name: avatar)
        }
        
        var commentCountText: String {  //只讀屬性(Calculate Property), 即不能賦值
            if commentCount <= 0 { return "回應" }
            if commentCount < 1000 { return "\(commentCount)" }
            return String(format: "%.1fK", Double(commentCount) / 1000)
        }
        
        var likeCountText: String {
            if likeCount <= 0 { return "喜歡" }
            if likeCount <= 1000 { return "\(likeCount)" }
            return String(format: "%.1fK", Double(likeCount) / 1000)
        }
    }


//let postList = loadPostListData("PostListData_recommend_1.json")    //解析名為 PostListData_recommend_1.json的 PostList, 回傳List; 屬全域變量

func loadPostListData(_ fileName: String) -> PostList {               //解析PostList回傳List
    guard let url = Bundle.main.url(forResource: fileName, withExtension: nil) else {       //guard 保證取得
        fatalError("Can not find \(fileName) in main bundle")
    }
    guard let data = try? Data(contentsOf: url) else {                //try? 表嘗試解析, data可能為空, 所以用 guard來保證取得
        fatalError("Can not load \(url)")
    }
    guard let list = try? JSONDecoder().decode(PostList.self, from: data) else {    //PostList.self 把類型作為參數要加.self
        fatalError("Can not parse post list json data")
    }
    return list
}


func loadImage(name: String) -> Image {
    return Image(uiImage: UIImage(named: name)!)
}
