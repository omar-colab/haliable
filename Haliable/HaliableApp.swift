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
                    .tint(DSColor.accent)                   // global accent (tab bar, controls)

                if showLaunchIntro {
                    LaunchIntroView { showLaunchIntro = false }
                        .zIndex(1)                          // always above the app
                }
            }
            .preferredColorScheme(theme.colorScheme)        // honor manual Light/Dark override
        }
        // SwiftData persistence for scan history + the offline product cache.
        .modelContainer(for: [ScanRecord.self, CachedProduct.self])
    }
}
