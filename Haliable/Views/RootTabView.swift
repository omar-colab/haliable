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
            ScannerView()
                .tabItem { Label("Scan", systemImage: "barcode.viewfinder") }
            AtlasView()
                .tabItem { Label("Find", systemImage: "map.fill") }
            MyReviewsView()
                .tabItem { Label("Reviews", systemImage: "doc.text.magnifyingglass") }
            HistoryView()
                .tabItem { Label("History", systemImage: "clock") }
            MethodologyView()
                .tabItem { Label("About", systemImage: "info.circle") }
        }
    }
}
