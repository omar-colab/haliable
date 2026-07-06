//
//  AppSettings.swift
//  Haliable
//
//  User preferences that aren't appearance (that's ThemeManager). One store,
//  persisted to UserDefaults, injected into the environment like the other
//  "brains". The Settings screen reads/writes these; feature code reads them.
//
//  NOTE: the spec asked for an `ObservableObject`, but the codebase standard is
//  `@Observable` (Observation framework) — used here for consistency with
//  ThemeManager / AuthManager / RulesEngine. Inject with `@State` + `.environment`.
//

import SwiftUI
import Observation
#if canImport(UIKit)
import UIKit
#endif

@Observable
final class AppSettings {
    /// Fire a light haptic on a successful scan.
    var hapticsEnabled: Bool      { didSet { store.set(hapticsEnabled, forKey: Key.haptics) } }
    /// Play a confirmation sound on a successful scan.
    var soundEnabled: Bool        { didSet { store.set(soundEnabled, forKey: Key.sound) } }
    /// Automatically write every scan to History.
    var autoSaveScans: Bool       { didSet { store.set(autoSaveScans, forKey: Key.autoSave) } }
    /// The user's active strictness position — the SINGLE source of truth shared
    /// by the Scanner pill and the Settings picker. The rules engine reads this.
    var halalStandard: HalalStandard {
        didSet { store.set(halalStandard.rawValue, forKey: Key.standard) }
    }
    /// Whether the user has been shown the first-run "how strict?" chooser yet.
    /// Set once the sheet has appeared (whether they pick or "decide later").
    var hasChosenStandard: Bool   { didSet { store.set(hasChosenStandard, forKey: Key.chosen) } }
    /// Default Atlas search radius, in kilometres.
    var searchRadiusKm: Double    { didSet { store.set(searchRadiusKm, forKey: Key.radius) } }

    private let store = UserDefaults.standard

    private enum Key {
        static let haptics  = "settings.haptics"
        static let sound    = "settings.sound"
        static let autoSave = "settings.autoSaveScans"
        static let standard = "settings.halalStandard"
        static let chosen   = "settings.hasChosenStandard"
        static let radius   = "settings.searchRadiusKm"
    }

    init() {
        // Registered defaults are returned until the user changes something.
        store.register(defaults: [
            Key.haptics:  true,
            Key.sound:    false,
            Key.autoSave: true,
            Key.chosen:   false,
            Key.radius:   5.0,
        ])
        hapticsEnabled    = store.bool(forKey: Key.haptics)
        soundEnabled      = store.bool(forKey: Key.sound)
        autoSaveScans     = store.bool(forKey: Key.autoSave)
        halalStandard     = HalalStandard(rawValue: store.string(forKey: Key.standard) ?? "") ?? .fallback
        hasChosenStandard = store.bool(forKey: Key.chosen)
        searchRadiusKm    = store.double(forKey: Key.radius)
    }
}

// MARK: - Haptics helper

/// Tiny wrapper so feature code can fire a tap that already respects the user's
/// haptics preference. TODO: call `Haptics.success(settings)` from the scanner's
/// success path (ScannerView.handleScan) so the toggle actually does something.
enum Haptics {
    static func success(_ settings: AppSettings) {
        #if canImport(UIKit)
        guard settings.hapticsEnabled else { return }
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        #endif
    }
}
