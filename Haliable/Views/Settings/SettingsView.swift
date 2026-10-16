//
//  SettingsView.swift
//  Haliable
//
//  App Store-ready Settings. A grouped List styled with the design tokens.
//  Sections: Appearance · Scanning · Location & Map · Data & Privacy · Account ·
//  About & Support. Every row is functional or explicitly stubbed; see the
//  TODO list at the bottom of this file for what still needs a backend.
//

import SwiftUI
import SwiftData
import CoreLocation
import StoreKit
import UIKit

struct SettingsView: View {
    // Injected "brains".
    @Environment(ThemeManager.self) private var theme
    @Environment(AppSettings.self) private var settings
    @Environment(AuthManager.self) private var auth
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @Environment(\.requestReview) private var requestReview

    // Scan history (for clear / export).
    @Query private var scans: [ScanRecord]

    // Live location-permission status.
    @State private var locationStatus = CLLocationManager().authorizationStatus

    // Sheet / dialog state.
    @State private var webPage: WebPage?
    @State private var showClearConfirm = false
    @State private var showDeleteConfirm = false
    @State private var accountMessage: String?
    @State private var signInError: String?

    // MARK: - Placeholders to replace before launch (see TODO list).
    private let privacyURL = URL(string: "https://haliable.netlify.app/privacy")!
    private let termsURL   = URL(string: "https://haliable.netlify.app/terms")!
    private let supportEmail = "omarmontasir876@gmail.com"
    // TODO: replace 0000000000 with the real App Store app id once provisioned.
    private let appStoreReviewURL = URL(string: "https://apps.apple.com/app/id0000000000?action=write-review")!

    var body: some View {
        @Bindable var settings = settings
        @Bindable var theme = theme

        NavigationStack {
            List {
                appearanceSection(theme: $theme.theme)
                scanningSection(settings: settings)
                locationSection(settings: settings)
                dataPrivacySection
                accountSection
                aboutSection
            }
            .scrollContentBackground(.hidden)
            .background(DSColor.background)
            .listStyle(.insetGrouped)
            .tint(DSColor.accent)
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } }
            }
            .sheet(item: $webPage) { SafariView(url: $0.url) }
            .confirmationDialog("Clear all scan history?",
                                isPresented: $showClearConfirm, titleVisibility: .visible) {
                Button("Clear \(scans.count) scans", role: .destructive) { clearHistory() }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This permanently removes your saved scans from this device. It can't be undone.")
            }
            .confirmationDialog("Delete your account?",
                                isPresented: $showDeleteConfirm, titleVisibility: .visible) {
                Button("Delete account", role: .destructive) { deleteAccount() }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This requests permanent deletion of your account and any server-side review data. This can't be undone.")
            }
            .alert("Account", isPresented: Binding(
                get: { accountMessage != nil },
                set: { if !$0 { accountMessage = nil } }
            )) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(accountMessage ?? "")
            }
        }
    }

    // MARK: - 1. Appearance

    private func appearanceSection(theme: Binding<AppTheme>) -> some View {
        Section {
            Picker(selection: theme) {
                ForEach(AppTheme.allCases) { option in
                    Label(option.label, systemImage: option.symbol).tag(option)
                }
            } label: {
                rowLabel("Theme", "paintbrush.fill")
            }

            // App icon alternates: none bundled yet. Disabled + flagged.
            HStack {
                rowLabel("App Icon", "app.badge.fill")
                Spacer()
                Text("Default").foregroundStyle(DSColor.textSecondary)
            }
            .opacity(0.5)
        } header: {
            sectionHeader("Appearance")
        } footer: {
            Text("System follows your device's light/dark setting automatically.")
                .settingsFooter()
        }
        .listRowBackground(DSColor.surface)
    }

    // MARK: - 2. Scanning

    private func scanningSection(settings: AppSettings) -> some View {
        @Bindable var settings = settings
        return Section {
            Toggle(isOn: $settings.hapticsEnabled) { rowLabel("Haptics", "hand.tap.fill") }
            Toggle(isOn: $settings.soundEnabled)   { rowLabel("Scan Sound", "speaker.wave.2.fill") }
            Toggle(isOn: $settings.autoSaveScans)  { rowLabel("Auto-save to History", "tray.and.arrow.down.fill") }

            Picker(selection: $settings.halalStandard) {
                ForEach(HalalStandard.allCases) { std in
                    Text(std.displayName).tag(std)
                }
            } label: {
                rowLabel("Halal Standard", "checkmark.shield.fill")
            }
        } header: {
            sectionHeader("Scanning")
        } footer: {
            Text("\(settings.halalStandard.displayName) — \(settings.halalStandard.shortDescription) You can also change this from the pill on the Scan screen.")
                .settingsFooter()
        }
        .listRowBackground(DSColor.surface)
    }

    // MARK: - 3. Location & Map

    private func locationSection(settings: AppSettings) -> some View {
        @Bindable var settings = settings
        return Section {
            HStack {
                rowLabel("Location Access", "location.fill")
                Spacer()
                Text(locationStatusText)
                    .font(DSFont.body)
                    .foregroundStyle(locationStatusColor)
            }
            Button {
                if let url = URL(string: UIApplication.openSettingsURLString) { openURL(url) }
            } label: {
                rowLabel("Open System Settings", "arrow.up.forward.app.fill")
            }

            Picker(selection: $settings.searchRadiusKm) {
                ForEach([1.0, 3.0, 5.0, 10.0, 25.0], id: \.self) { km in
                    Text("\(Int(km)) km").tag(km)
                }
            } label: {
                rowLabel("Search Radius", "scope")
            }
        } header: {
            sectionHeader("Location & Map")
        } footer: {
            Text("Used only to center the Find Halal map and search nearby. Never stored or shared.")
                .settingsFooter()
        }
        .listRowBackground(DSColor.surface)
        .onAppear { locationStatus = CLLocationManager().authorizationStatus }
    }

    // MARK: - 4. Data & Privacy

    private var dataPrivacySection: some View {
        Section {
            Button(role: .destructive) {
                showClearConfirm = true
            } label: {
                rowLabel("Clear Scan History", "trash.fill", tint: DSColor.danger, destructive: true)
            }
            .disabled(scans.isEmpty)

            ShareLink(item: exportJSON,
                      preview: SharePreview("Haliable data export")) {
                rowLabel("Export My Data", "square.and.arrow.up.fill")
            }

            Button { webPage = WebPage(url: privacyURL) } label: {
                rowLabel("Privacy Policy", "hand.raised.fill")
            }
            Button { webPage = WebPage(url: termsURL) } label: {
                rowLabel("Terms of Use", "doc.text.fill")
            }
        } header: {
            sectionHeader("Data & Privacy")
        } footer: {
            Text("Scanning runs fully on-device. Barcodes go only to the anonymous Open Food Facts / USDA lookups — never tied to your identity.")
                .settingsFooter()
        }
        .listRowBackground(DSColor.surface)
    }

    // MARK: - 5. Account

    private var accountSection: some View {
        Section {
            if auth.isSignedIn {
                HStack {
                    rowLabel("Signed in", "person.crop.circle.fill.badge.checkmark")
                    Spacer()
                    Text(auth.email ?? "Apple ID")
                        .font(DSFont.body)
                        .foregroundStyle(DSColor.textSecondary)
                        .lineLimit(1)
                }
                Button { auth.signOut() } label: {
                    rowLabel("Sign Out", "rectangle.portrait.and.arrow.right")
                }
                Button(role: .destructive) {
                    showDeleteConfirm = true
                } label: {
                    rowLabel("Delete Account", "person.crop.circle.badge.xmark", tint: DSColor.danger, destructive: true)
                }
            } else {
                Text("Sign in with Apple to submit manual reviews and add stores. Browsing and scanning never require an account.")
                    .font(DSFont.body)
                    .foregroundStyle(DSColor.textSecondary)
                AppleSignInButton { signInError = $0 }
                if let signInError {
                    Text(signInError).font(DSFont.caption).foregroundStyle(DSColor.danger)
                }
            }
        } header: {
            sectionHeader("Account")
        } footer: {
            Text("Account deletion is required by App Store guideline 5.1.1(v).")
                .settingsFooter()
        }
        .listRowBackground(DSColor.surface)
    }

    // MARK: - 6. About & Support

    private var aboutSection: some View {
        Section {
            HStack {
                rowLabel("Version", "info.circle.fill")
                Spacer()
                Text(versionString).foregroundStyle(DSColor.textSecondary)
            }
            Button {
                let subject = "Haliable Support (v\(versionString))"
                let mailto = "mailto:\(supportEmail)?subject=\(subject.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")"
                if let url = URL(string: mailto) { openURL(url) }
            } label: {
                rowLabel("Contact Support", "envelope.fill")
            }
            Button {
                requestReview()
            } label: {
                rowLabel("Rate Haliable", "star.fill")
            }
            Button { openURL(appStoreReviewURL) } label: {
                rowLabel("Review on the App Store", "arrow.up.forward.app.fill")
            }
            NavigationLink {
                AcknowledgementsView()
            } label: {
                rowLabel("Acknowledgements", "text.justify.left")
            }
        } header: {
            sectionHeader("About & Support")
        } footer: {
            Text("Made for the Ummah. Verdicts cite IFANCA, ISNA, and AMJA — always verify before relying on them.")
                .settingsFooter()
        }
        .listRowBackground(DSColor.surface)
    }

    // MARK: - Row helpers

    private func rowLabel(_ title: String, _ symbol: String,
                          tint: Color = DSColor.accent, destructive: Bool = false) -> some View {
        Label {
            Text(title)
                .font(DSFont.body)
                .foregroundStyle(destructive ? DSColor.danger : DSColor.textPrimary)
        } icon: {
            Image(systemName: symbol).foregroundStyle(tint)
        }
    }

    private func sectionHeader(_ text: String) -> some View {
        Text(text).font(DSFont.caption).foregroundStyle(DSColor.textSecondary)
    }

    // MARK: - Derived values

    private var versionString: String {
        let info = Bundle.main.infoDictionary
        let v = info?["CFBundleShortVersionString"] as? String ?? "1.0"
        let b = info?["CFBundleVersion"] as? String ?? "1"
        return "\(v) (\(b))"
    }

    private var locationStatusText: String {
        switch locationStatus {
        case .authorizedAlways, .authorizedWhenInUse: return "Allowed"
        case .denied:        return "Denied"
        case .restricted:    return "Restricted"
        case .notDetermined: return "Not set"
        @unknown default:    return "Unknown"
        }
    }

    private var locationStatusColor: Color {
        switch locationStatus {
        case .authorizedAlways, .authorizedWhenInUse: return DSColor.success
        case .denied, .restricted: return DSColor.danger
        default: return DSColor.textSecondary
        }
    }

    /// A human-readable JSON snapshot of everything stored on-device.
    private var exportJSON: String {
        struct Export: Codable {
            let app = "Haliable"
            let exportedAt: Date
            let scanCount: Int
            let scans: [Row]
            let preferences: Prefs
        }
        struct Row: Codable {
            let barcode: String
            let productName: String
            let verdict: String
            let scannedAt: Date
        }
        struct Prefs: Codable {
            let theme: String
            let halalStandard: String
            let searchRadiusKm: Double
            let haptics: Bool
            let sound: Bool
            let autoSaveScans: Bool
        }

        let rows = scans.map {
            Row(barcode: $0.barcode, productName: $0.productName,
                verdict: $0.overallVerdict.rawValue, scannedAt: $0.scannedAt)
        }
        let export = Export(
            exportedAt: Date(),
            scanCount: rows.count,
            scans: rows,
            preferences: Prefs(
                theme: theme.theme.rawValue,
                halalStandard: settings.halalStandard.rawValue,
                searchRadiusKm: settings.searchRadiusKm,
                haptics: settings.hapticsEnabled,
                sound: settings.soundEnabled,
                autoSaveScans: settings.autoSaveScans
            )
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return (try? encoder.encode(export)).flatMap { String(data: $0, encoding: .utf8) } ?? "{}"
    }

    // MARK: - Actions

    private func clearHistory() {
        for record in scans { modelContext.delete(record) }
        try? modelContext.save()
    }

    private func deleteAccount() {
        // TODO: wire to a real backend endpoint that deletes the user's row(s)
        // and storage (Supabase: auth.admin.deleteUser + cascade on review_requests).
        // For now we sign out locally and confirm, so the App-Store-required path
        // exists end-to-end in the UI.
        auth.signOut()
        accountMessage = "Your account deletion request has been recorded. (Backend deletion is pending — see TODO.)"
    }
}

// MARK: - Footer styling sugar

private extension View {
    func settingsFooter() -> some View {
        self.font(DSFont.caption).foregroundStyle(DSColor.textSecondary)
    }
}

// ─────────────────────────────────────────────────────────────────────────────
//  OUTSTANDING TODOs (flagged for review — not yet wired):
//
//  1. ACCOUNT DELETION (5.1.1(v)): `deleteAccount()` only signs out locally and
//     shows a confirmation. Wire it to a real server endpoint that deletes the
//     user + their review_requests (Supabase admin delete) before App Store
//     submission. This is a HARD requirement for approval.
//
//  2. PRIVACY / TERMS URLs: privacyURL & termsURL point at haliable.app/privacy
//     and /terms — stubs. Host the real documents (a starter Privacy Policy can
//     be drafted next) and confirm the URLs resolve.
//
//  3. APP STORE id: appStoreReviewURL contains id0000000000. Replace with the
//     real app id after the app record is created in App Store Connect.
//
//  4. HALAL STANDARD: DONE — `settings.halalStandard` is now threaded into
//     `RulesEngine.evaluate(product:standard:)` and the Scanner pill. REMAINING:
//     ingredient categorization is heuristic (keyword sniffing in
//     IngredientCategory) — add explicit `category` tags to rules-v1.json and have
//     a scholar review the per-standard transforms + certifier mappings in
//     HalalStandard.swift (all marked `TODO(fiqh)`).
//
//  5. SEARCH RADIUS: persisted, but AtlasView still calls `loadNearby(center:)`
//     with the default 5 km. Pass `radiusKm: settings.searchRadiusKm` there.
//
//  6. AUTO-SAVE / HAPTICS / SOUND: ScannerView still always inserts a ScanRecord
//     and plays nothing. Gate the insert on `settings.autoSaveScans`, and call
//     `Haptics.success(settings)` (+ a sound if `settings.soundEnabled`) on a
//     successful scan.
//
//  7. APP ICON ALTERNATES: none are bundled, so the row is disabled. Add
//     CFBundleAlternateIcons + a picker if/when alternate icons ship.
// ─────────────────────────────────────────────────────────────────────────────
