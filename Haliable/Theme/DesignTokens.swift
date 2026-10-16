//
//  DesignTokens.swift
//  Haliable
//
//  The single source of truth for the app's visual language. NOTHING in a view
//  should reference a raw hex value, a system color, or a magic number for
//  spacing/radius — it should reach for a token here. That keeps the whole app
//  re-themeable from one place and makes dark mode automatic.
//
//  Colors resolve through the Asset Catalog (Assets.xcassets/<Name>.colorset),
//  each of which carries a light AND a dark variant, so `DSColor.background`
//  is correct in both appearances with zero branching in view code.
//

import SwiftUI

// MARK: - Semantic color tokens

/// Semantic colors. Name things by ROLE ("surface", "danger"), never by hue,
/// so the palette can shift underneath without touching call sites.
enum DSColor {
    /// App canvas. Near-black, faintly green-tinted in dark mode (#0B0F0D).
    static let background      = Color("Background")
    /// Cards, sheets, list rows sitting on the background.
    static let surface         = Color("Surface")
    /// A surface that needs to read as lifted above another surface.
    static let surfaceElevated = Color("SurfaceElevated")

    /// Primary text / icons (editorial "ink").
    static let textPrimary     = Color("TextPrimary")
    /// Supporting text, captions, secondary labels ("ink-soft").
    static let textSecondary   = Color("TextSecondary")
    /// The faintest text tier — eyebrow metadata, timestamps ("ink-faint").
    static let textTertiary    = Color("TextTertiary")

    /// The brand green. Bright on dark, deeper on light. Use for emphasis,
    /// primary actions, and the glow treatment.
    static let accent          = Color("Accent")
    /// The deeper "ink" green used for accent TEXT on light surfaces (the
    /// editorial italic accent, eyebrows). Reads as the green-on-paper voice.
    static let accentDeep      = Color("AccentDeep")
    /// A quieter accent for backgrounds, fills, and resting states (green-wash).
    static let accentMuted     = Color("AccentMuted")
    /// The deep end of the brand gradient (#0A7A4C in both modes). Never text —
    /// `accentDeep` is the text green and turns LIGHT in dark mode, which made
    /// every accent gradient fade the wrong way.
    static let accentGradientEnd = Color("AccentGradientEnd")
    /// Text/icon color that sits ON the accent fill (white on light, deep green
    /// on the brighter dark-mode green) so primary buttons stay high-contrast.
    static let onAccent        = Color("OnAccent")

    /// Status colors — map to verdicts via `Verdict.tint`.
    static let success         = Color("Success")   // Halal
    static let warning         = Color("Warning")   // Questionable
    static let danger          = Color("Danger")    // Haram

    /// Soft tinted washes behind the verdict reveal + status pills.
    static let successWash     = Color("SuccessWash")
    static let warningWash     = Color("WarningWash")
    static let dangerWash      = Color("DangerWash")

    /// Hairline borders and dividers ("line").
    static let outline         = Color("Outline")
    /// A stronger hairline for selected/raised controls ("line-strong").
    static let outlineStrong   = Color("OutlineStrong")

    /// Warm gold — review-star ratings and the brand crescent.
    static let gold            = Color("Gold")
}

// MARK: - Spacing (4-pt grid)

/// Every gap, pad, and inset comes from this scale so rhythm stays consistent.
enum DSSpacing {
    static let xxs: CGFloat = 4
    static let xs:  CGFloat = 8
    static let sm:  CGFloat = 12
    static let md:  CGFloat = 16
    static let lg:  CGFloat = 24
    static let xl:  CGFloat = 32
    static let xxl: CGFloat = 48
}

// MARK: - Corner radius

enum DSRadius {
    static let sm:   CGFloat = 14   // v4 r-sm (15)
    static let md:   CGFloat = 20   // v4 r-md (21) — standard card
    static let lg:   CGFloat = 28   // v4 r-lg (30) — viewport, sheets, big surfaces
    static let xl:   CGFloat = 34   // result sheet top
    static let pill: CGFloat = 999  // fully rounded capsules
}

// MARK: - Elevation

/// Named shadow presets so cards don't each invent their own.
enum DSElevation {
    static func shadow(_ level: Level) -> (color: Color, radius: CGFloat, y: CGFloat) {
        switch level {
        case .none: return (.clear, 0, 0)
        case .low:  return (.black.opacity(0.08), 8, 3)
        case .high: return (.black.opacity(0.14), 16, 8)
        }
    }
    enum Level { case none, low, high }
}

// MARK: - Verdict → status color

extension Verdict {
    /// The one place verdict colors are decided. Halal = success, Questionable
    /// = warning, Haram = danger. Every badge/row/pin should read from here.
    var tint: Color {
        switch self {
        case .halal:    return DSColor.success
        case .doubtful: return DSColor.warning
        case .haram:    return DSColor.danger
        }
    }

    /// The SF Symbol that pairs with each verdict.
    var symbolName: String {
        switch self {
        case .halal:    return "checkmark.seal.fill"
        case .doubtful: return "questionmark.diamond.fill"
        case .haram:    return "xmark.seal.fill"
        }
    }
}

// MARK: - GradeLevel → status color (5-level)

extension GradeLevel {
    /// Color per grade. Reuses the three status tokens; the five tiers are told
    /// apart by symbol + label, with severity climbing success → warning → danger.
    var tint: Color {
        switch self {
        case .halal:               return DSColor.success
        case .mashboohSafe:        return DSColor.warning
        case .mashboohContested:   return DSColor.warning
        case .mashboohDisapproved: return DSColor.danger
        case .haram:               return DSColor.danger
        }
    }

    /// The SF Symbol paired with each grade — gives the five tiers a visible ramp.
    var symbolName: String {
        switch self {
        case .halal:               return "checkmark.seal.fill"
        case .mashboohSafe:        return "checkmark.circle"
        case .mashboohContested:   return "questionmark.diamond.fill"
        case .mashboohDisapproved: return "exclamationmark.triangle.fill"
        case .haram:               return "xmark.seal.fill"
        }
    }
}
