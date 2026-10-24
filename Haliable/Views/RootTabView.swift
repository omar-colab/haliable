//
//  RootTabView.swift
//  Haliable
//
//  Created by Omar O on 6/4/26.
//
//  The system tab bar is hidden and the board's floating bubble dock sits on
//  top. A real TabView is kept underneath so every tab keeps its own state and
//  navigation stack. The centre bubble is Home; tapping it again while on Home
//  opens the scanner.
//

import SwiftUI
import SwiftData

enum AppTab: Hashable {
    case home, find, about, reviews, history
}

struct RootTabView: View {
    @Environment(AppSettings.self) private var settings
    @Environment(RulesEngine.self) private var engine
    @Environment(\.modelContext) private var modelContext
    @Environment(AuthManager.self) private var auth
    @Environment(ReviewStore.self) private var reviews
    @Environment(\.scenePhase) private var scenePhase
    @State private var tab: AppTab = .home
    @State private var scan: ScanRequest?

    struct ScanRequest: Identifiable {
        let id = UUID()
        let barcode: String?
    }

    var body: some View {
        TabView(selection: $tab) {
            page(.home) {
                HomeView(onScan: { scan = ScanRequest(barcode: $0) },
                         onSeeHistory: { tab = .history },
                         onSeeReviews: { tab = .reviews })
            }
            page(.find) { AtlasV2() }
            page(.about) { AboutV2() }
            page(.reviews) { MyReviewsV2() }
            page(.history) { HistoryV2(onOpen: { scan = ScanRequest(barcode: $0) }) }
        }
        .overlay(alignment: .bottom) {
            GuardDock(tab: $tab, haptics: settings.hapticsEnabled) { scan = ScanRequest(barcode: nil) }
                .padding(.bottom, 4)
                .ignoresSafeArea(.keyboard)
        }
        .fullScreenCover(item: $scan) { ScanSessionView(initialBarcode: $0.barcode) }
        // Old History rows pick up rule improvements (once per launch).
        .task { await HistoryRegrade.run(context: modelContext, engine: engine) }
        // Home's "awaiting an answer" count: load on sign-in and on every return
        // to the app, not only when the Reviews tab is opened.
        .task(id: auth.userID) { try? await reviews.refresh(auth: auth) }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { Task { try? await reviews.refresh(auth: auth) } }
        }
    }

    /// Hides the system bar and reserves room so scroll content clears the dock.
    private func page<Content: View>(_ tag: AppTab, @ViewBuilder _ content: () -> Content) -> some View {
        content()
            .safeAreaInset(edge: .bottom, spacing: 0) { Color.clear.frame(height: 74) }
            .toolbar(.hidden, for: .tabBar)
            .tag(tag)
    }
}

/// Find · About · [Home / Scan] · Reviews · History — the board's overlapping
/// bubble dock. About takes the board's heart slot (the app has no favorites).
struct GuardDock: View {
    @Binding var tab: AppTab
    var haptics: Bool
    var onScan: () -> Void

    var body: some View {
        HStack(spacing: -9) {
            bubble(.find, "mappin.and.ellipse", "Find halal places")
            bubble(.about, "info", "About")
            DockMainBubble(symbol: tab == .home ? "barcode.viewfinder" : "house.fill",
                           label: tab == .home ? "Start a halal scan" : "Home") {
                tick()
                if tab == .home { onScan() } else { tab = .home }
            }
            .padding(.horizontal, 4)
            .accessibilityIdentifier("dock.main")
            bubble(.reviews, "pencil.line", "Reviews")
            bubble(.history, "clock", "History")
        }
    }

    private func bubble(_ target: AppTab, _ symbol: String, _ label: String) -> some View {
        DockBubble(symbol: symbol, label: label, selected: tab == target) {
            tick(); tab = target
        }
        .accessibilityIdentifier("dock.\(target)")
    }

    private func tick() {
        guard haptics else { return }
        UISelectionFeedbackGenerator().selectionChanged()
    }
}
