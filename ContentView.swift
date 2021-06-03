//
//  ContentView.swift
//  tweetTweet
//  Created by 鄭淳澧 on 2021/5/5.
//

import SwiftUI //導入框架

struct ContentView: View {  //自定義頁面 ContentView是一個View(視圖) ":"表示屬性為

    var body: some View {
        Text("Hello, Swift!")
            .padding()
    }
}


struct ContentView_Previews: PreviewProvider { //預覽視圖ContentView
    static var previews: some View {
        ContentView()
    }
}

//---------------------------------------------------

//struct ContentView2: View { //自定義頁面 ContentView是一個View(視圖)
//
//    var body: some View {
//        Text("Hello, World!")
//            .padding()
//    }
//}
//
//
//struct ContentView2_Previews: PreviewProvider { //預覽視圖ContentView2
//    static var previews: some View {
//        ContentView2()
//    }
//}
