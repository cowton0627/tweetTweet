//
//  PostListView.swift
//  tweetTweet
//  Created by 鄭淳澧 on 2021/5/7.
//

import SwiftUI

struct PostListView: View { //顯示推特列表
    let category: PostListCategory
    
//    var postList: PostList {
//        switch category {
//        case .recommend:
//            return loadPostListData("PostListData_recommend_1.json")
//        case .hot:
//            return loadPostListData("PostListData_hot_1.json")
//        }
//    }
    
    @EnvironmentObject var userData: UserData
    
    /*
         init() {
            UITableView.appearance().separatorStyle = .none
            UITableViewCell.appearance().selectionStyle = .none
         }
         將創建時原生的分隔線去除
         叫出PostListView時採用取消預設分隔線的動作
         
         但此處不能再用init, 於是挪到HomeView裡
    */
    
    var body: some View {
        List {
            ForEach(userData.postList(for: category).list) { post in    //每次去取出一個list生成一個postcell
                //原為postList.list
                ZStack {
                    PostCell(post: post)
                    NavigationLink(destination: PostDetailView(post: post)) {
                        //原des: Text("Detail")
                       EmptyView()
                    }
                    .hidden()   //隱藏預設右邊中間小箭頭
                }
                    .listRowInsets(EdgeInsets())    //Insets 即上下左右的間距
            }
        }
    }
}


struct PostListView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView{
            PostListView(category: .recommend)
                .navigationBarTitle("回列表")
                .navigationBarHidden(true)
        }
        .environmentObject(UserData())
    }
}
