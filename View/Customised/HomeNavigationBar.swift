//
//  HomeNavigationBar.swift
//  tweetTweet
//  Created by 鄭淳澧 on 2021/5/7.
//

import SwiftUI

private let kLabelWidth: CGFloat = 60
private let kLabelSpacing: CGFloat = 30
private let kIndicatorWidth: CGFloat = 30

struct HomeNavigationBar: View {    //中央的「推薦/熱門」切換 (toolbar .principal 用)
    @Binding var leftPercent: CGFloat   // 0 for left, 1 for right

    var body: some View {
        VStack(spacing: 3) {
            HStack(spacing: kLabelSpacing) {
                Button(action: {
                    withAnimation { self.leftPercent = 0 }
                }) {
                    Text("推薦")
                        .bold()
                        .frame(width: kLabelWidth, height: 34)
                        .contentShape(Rectangle())
                }
                .buttonStyle(PlainButtonStyle())
                .opacity(Double(1 - leftPercent * 0.5))

                Button(action: {
                    withAnimation { self.leftPercent = 1 }
                }) {
                    Text("熱門")
                        .bold()
                        .frame(width: kLabelWidth, height: 34)
                        .contentShape(Rectangle())
                }
                .buttonStyle(PlainButtonStyle())
                .opacity(Double(0.5 + leftPercent * 0.5))
            }
            .font(.system(size: 17))

            RoundedRectangle(cornerRadius: 2)
                .foregroundColor(.red)
                .frame(width: kIndicatorWidth, height: 3)
                .offset(x: (kLabelWidth + kLabelSpacing) * 0.5 * (leftPercent * 2 - 1))
        }
    }
}


struct HomeNavigationBar_Previews: PreviewProvider {
    static var previews: some View {
        HomeNavigationBar(leftPercent: .constant(0))
    }
}
