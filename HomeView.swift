//
//  HomeView.swift
//  tweetTweet
//
//  Created by 鄭淳澧 on 2021/5/8.
//

import SwiftUI

struct HomeView: View {
    @State var leftPercent: CGFloat = 0
    
    init() {
        UITableView.appearance().separatorStyle = .none
        UITableViewCell.appearance().selectionStyle = .none
    }   //由PostListView挪過來
    
    var body: some View {
        NavigationView {
                HScrollViewController(pageWidth: UIScreen.main.bounds.width,
                                      contentSize: CGSize(width: UIScreen.main.bounds.width * 2,height: UIScreen.main.bounds.height), leftPercent: self.$leftPercent)
                {
                    ScrollView(.horizontal, showsIndicators: false){
                        HStack(spacing: 0) {
                            PostListView(category: .recommend)
                                .frame(width: UIScreen.main.bounds.width)
                            PostListView(category: .hot)
                                .frame(width: UIScreen.main.bounds.width)
                        }
                    }
                }
            .edgesIgnoringSafeArea(.bottom) //邊界忽略“底部”的安全區域
            .navigationBarItems(leading: HomeNavigationBar(leftPercent: $leftPercent))
            .navigationBarTitle("回列表", displayMode: .inline)
        }
        .navigationViewStyle(StackNavigationViewStyle())    //使ipad樣式與iphone一樣
    }
}


struct HomeView_Previews: PreviewProvider {
    static var previews: some View {
        HomeView().environmentObject(UserData())
    }
}
