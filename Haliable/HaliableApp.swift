//
//  HaliableApp.swift
//  Haliable
//
//  Created by Omar O on 5/20/26.
//

import SwiftUI
import SwiftData

@main
struct HaliableApp: App {
    // Shared "brains", created once and injected into the environment.
    @State private var rulesEngine = RulesEngine()   // bundled rules
    @State private var auth = AuthManager()           // Sign in with Apple → Supabase
    @State private var reviewStore = ReviewStore()    // manual-review requests
    @State private var theme = ThemeManager()         // appearance preference
    @State private var settings = AppSettings()       // scanning/location/data prefs
    @State private var scout = SourceScout()          // in-app research bot

    /// Drives the brief warm intro overlay. The real UI lives behind it from the
    /// first frame, so dismissing this never gates any work — it only reveals.
    @State private var showLaunchIntro = true

    init() {
        // Loud (DEBUG-only) report of which backend secrets are wired.
        ConfigAudit.preflight()
    }

    var body: some Scene {
        WindowGroup {
            ZStack {
                RootTabView()
                    .environment(rulesEngine)
                    .environment(auth)
                    .environment(reviewStore)
                    .environment(theme)
                    .environment(settings)
                    .environment(scout)
                    .tint(DSColor.accent)                   // global accent (tab bar, controls)

                if showLaunchIntro {
                    LaunchIntroView { showLaunchIntro = false }
                        .zIndex(1)                          // always above the app
                }
            }
            // Set on the UIKit windows, not via .preferredColorScheme: SwiftUI doesn't
            // push that into an already-open sheet (Settings), and going back to
            // System left the sheet stuck on the old appearance.
            .onChange(of: theme.theme, initial: true) { _, new in applyAppearance(new) }
        }
        // SwiftData persistence for scan history + the offline product cache.
        .modelContainer(for: [ScanRecord.self, CachedProduct.self])
    }

    private func applyAppearance(_ theme: AppTheme) {
        let style: UIUserInterfaceStyle = switch theme {
        case .system: .unspecified
        case .light:  .light
        case .dark:   .dark
        }
        for case let scene as UIWindowScene in UIApplication.shared.connectedScenes {
            scene.windows.forEach { $0.overrideUserInterfaceStyle = style }
        }
    }
}
