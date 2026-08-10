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
    // Either a bundled filename, a RuntimeImageStore key, or an absolute URL:
    // the repository resolves server-relative paths before the view sees them.
    var avatar: String
    let vip: Bool       //是否為VIP; 實例變量, 有定義Post才有
    let name: String
    let date: String

    var isFollowed: Bool

    let text: String
    var images: [String]    //圖片是陣列, 陣列的元素是string類型
    
    var commentCount: Int
    var likeCount: Int
    var isLiked: Bool
}
    
    extension Post {    //因為Post裡面是不可視的資料, 所以, 欲將可視的物件加進Post裡用extension
        // The API sends an instant (2020-01-05T14:51:00.000Z), never a display
        // string: a server cannot know which clock a reader is looking at.
        // Turning it into local wall-clock time is this side's job.
        private static let instantParser: ISO8601DateFormatter = {
            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            return formatter
        }()

        private static let displayFormatter: DateFormatter = {
            let formatter = DateFormatter()
            formatter.locale = Locale(identifier: "en_US_POSIX")
            formatter.dateFormat = "yyyy-MM-dd HH:mm"
            return formatter
        }()

        /// Local wall-clock time. Falls back to the raw value so a post is
        /// never rendered blank just because its timestamp was unexpected.
        var displayDate: String {
            guard let instant = Post.instantParser.date(from: date) else {
                return date
            }
            return Post.displayFormatter.string(from: instant)
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

func loadPostListData(_ fileName: String) throws -> PostList {               //解析PostList回傳List
    guard let url = Bundle.main.url(forResource: fileName, withExtension: nil)
            ?? Bundle.main.url(forResource: fileName, withExtension: nil, subdirectory: "AppResources") else {       //guard 保證取得
        throw PostDataError.fileNotFound(fileName)
    }
    let data: Data
    do {
        data = try Data(contentsOf: url)
    } catch {
        throw PostDataError.unreadableFile(url, underlyingError: error)
    }
    do {
        return try JSONDecoder().decode(PostList.self, from: data)
    } catch {
        throw PostDataError.decodingFailed(fileName, underlyingError: error)
    }
}

enum PostDataError: LocalizedError {
    case fileNotFound(String)
    case unreadableFile(URL, underlyingError: Error)
    case decodingFailed(String, underlyingError: Error)

    var errorDescription: String? {
        switch self {
        case .fileNotFound(let fileName):
            return "找不到貼文資料 \(fileName)。"
        case .unreadableFile:
            return "無法讀取本地貼文資料。"
        case .decodingFailed:
            return "無法解析本地貼文資料。"
        }
    }
}


func loadImage(name: String) -> Image {
    if let image = UIImage(named: name) {
        return Image(uiImage: image)
    }
    if let url = Bundle.main.url(forResource: name, withExtension: nil, subdirectory: "AppResources"),
       let image = UIImage(contentsOfFile: url.path) {
        return Image(uiImage: image)
    }
    if let image = RuntimeImageStore.image(forKey: name) {
        return Image(uiImage: image)
    }
    return Image(systemName: "photo")
}

#if DEBUG
extension Post {
    static let preview = Post(
        id: 1,
        avatar: "avatar-01.jpg",
        vip: true,
        name: "預覽使用者",
        date: "2026-07-28 12:00",
        isFollowed: false,
        text: "這是一則用於 Xcode Preview 的貼文。",
        images: ["post-01.jpg", "post-02.jpg", "post-03.jpg"],
        commentCount: 12,
        likeCount: 88,
        isLiked: true
    )
}
#endif
