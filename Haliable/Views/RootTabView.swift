//
//  RootTabView.swift
//  Haliable
//
//  Created by Omar O on 6/4/26.
//

import SwiftUI

struct RootTabView: View {
    var body: some View {
        TabView {
            ScannerViewV2()
                .tabItem { Label("Scan", systemImage: "barcode.viewfinder") }
            AtlasV2()
                .tabItem { Label("Find", systemImage: "map.fill") }
            MyReviewsV2()
                .tabItem { Label("Reviews", systemImage: "doc.text.magnifyingglass") }
            HistoryV2()
                .tabItem { Label("History", systemImage: "clock") }
            AboutV2()
                .tabItem { Label("About", systemImage: "info.circle") }
        }
        .tint(DSColor.accent)
    }
}
