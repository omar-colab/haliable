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

    var body: some Scene {
        WindowGroup {
            RootTabView()
                .environment(rulesEngine)
                .environment(auth)
                .environment(reviewStore)
        }
        // SwiftData persistence for scan history.
        .modelContainer(for: ScanRecord.self)
    }
}
