//
//  ThemeManager.swift
//  Haliable
//
//  Owns the user's appearance preference. By default the app follows the
//  system (light/dark) automatically — because every color is an Asset Catalog
//  token with both variants. This manager lets the user OVERRIDE that to a
//  forced Light or Dark, persisted across launches. The Settings screen (later)
//  binds to `theme`; the app root applies `colorScheme`.
//
//  NOTE: uses `@Observable` (Observation framework) to match the codebase's
//  locked standard, rather than the older `ObservableObject`. Inject it the
//  same way as the other stores: `@State` in the App + `.environment(...)`.
//

import SwiftUI

/// The three appearance choices a user can pick in Settings.
enum AppTheme: String, CaseIterable, Identifiable {
    case system
    case light
    case dark

    var id: String { rawValue }

    /// Label for the Settings picker.
    var label: String {
        switch self {
        case .system: return "System"
        case .light:  return "Light"
        case .dark:   return "Dark"
        }
    }

    /// SF Symbol for the Settings picker.
    var symbol: String {
        switch self {
        case .system: return "circle.lefthalf.filled"
        case .light:  return "sun.max.fill"
        case .dark:   return "moon.fill"
        }
    }

    /// What to hand SwiftUI's `.preferredColorScheme`. `nil` = follow system.
    var colorScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .light:  return .light
        case .dark:   return .dark
        }
    }
}

@Observable
final class ThemeManager {
    /// The current preference. Writing it persists to UserDefaults immediately.
    var theme: AppTheme {
        didSet { UserDefaults.standard.set(theme.rawValue, forKey: Self.storageKey) }
    }

    /// Pass-through for the app root's `.preferredColorScheme(...)`.
    var colorScheme: ColorScheme? { theme.colorScheme }

    private static let storageKey = "app_theme_preference"

    init() {
        let saved = UserDefaults.standard.string(forKey: Self.storageKey)
        // Default follows the phone (Omar, Oct 16). The launch background is
        // adaptive too, so there's no light/dark flip on first open.
        self.theme = AppTheme(rawValue: saved ?? "") ?? .system
    }
}
