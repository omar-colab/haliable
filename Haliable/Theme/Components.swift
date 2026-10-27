//
//  Components.swift
//  Haliable
//
//  The reusable building blocks every screen composes from: two buttons, a card
//  container, and a status chip. Built entirely on the tokens so they restyle
//  with the theme and adapt to light/dark automatically.
//

import SwiftUI

// MARK: - Buttons

/// Filled, accent-colored primary action. Use for the single most important
/// action on a screen ("Scan barcode", "Submit").
///
/// `makeBody` delegates to an inner `View` so `@Environment(\.isEnabled)` is
/// actually tracked — environment values don't update on the ButtonStyle struct
/// itself (it isn't a View), which would silently break disabled dimming.
struct PrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        StyleBody(configuration: configuration)
    }

    private struct StyleBody: View {
        let configuration: Configuration
        @Environment(\.isEnabled) private var isEnabled

        var body: some View {
            configuration.label
                .font(DSFont.button)
                .foregroundStyle(DSColor.onAccent)              // white on light, deep-green on dark
                .frame(maxWidth: .infinity)
                .padding(.vertical, 17)
                .padding(.horizontal, DSSpacing.md)
                .background(DSColor.accent, in: RoundedRectangle(cornerRadius: DSRadius.md, style: .continuous))
                .opacity(isEnabled ? 1 : 0.4)
                .shadow(color: DSColor.accent.opacity(isEnabled ? 0.42 : 0),
                        radius: configuration.isPressed ? 6 : 16, y: 8)
                .scaleEffect(configuration.isPressed ? 0.975 : 1)
                .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
        }
    }
}

/// Outlined, lower-emphasis action. Use for secondary choices next to a primary.
struct SecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        StyleBody(configuration: configuration)
    }

    private struct StyleBody: View {
        let configuration: Configuration
        @Environment(\.isEnabled) private var isEnabled

        var body: some View {
            configuration.label
                .font(DSFont.button)
                .foregroundStyle(DSColor.textPrimary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 15)
                .padding(.horizontal, DSSpacing.md)
                .background(DSColor.surface,
                            in: RoundedRectangle(cornerRadius: DSRadius.md, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: DSRadius.md, style: .continuous)
                        .strokeBorder(DSColor.outlineStrong, lineWidth: 1)
                )
                .shadow(color: Color.black.opacity(0.05), radius: 10, y: 4)
                .opacity(isEnabled ? 1 : 0.4)
                .scaleEffect(configuration.isPressed ? 0.975 : 1)
                .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
        }
    }
}

// Sugar: `.buttonStyle(.primaryAction)` / `.secondaryAction`.
extension ButtonStyle where Self == PrimaryButtonStyle {
    static var primaryAction: PrimaryButtonStyle { PrimaryButtonStyle() }
}
extension ButtonStyle where Self == SecondaryButtonStyle {
    static var secondaryAction: SecondaryButtonStyle { SecondaryButtonStyle() }
}

/// Convenience view for the common "label + action" primary button.
struct PrimaryButton: View {
    let title: String
    var systemImage: String? = nil
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            if let systemImage {
                Label(title, systemImage: systemImage)
            } else {
                Text(title)
            }
        }
        .buttonStyle(.primaryAction)
    }
}

/// Convenience view for a secondary button.
struct SecondaryButton: View {
    let title: String
    var systemImage: String? = nil
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            if let systemImage {
                Label(title, systemImage: systemImage)
            } else {
                Text(title)
            }
        }
        .buttonStyle(.secondaryAction)
    }
}

// MARK: - Card

/// A titled-or-untitled content container in the app's surface style.
struct Card<Content: View>: View {
    var elevated: Bool = false
    @ViewBuilder var content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: DSSpacing.sm) {
            content()
        }
        .cardStyle(elevated: elevated)
    }
}

// MARK: - Status badge / chip

/// A small colored pill. The generic chip behind every status indicator —
/// verdicts, review states, store scopes. Pass a tint and it renders a faint
/// fill + bold text/icon in that color.
struct StatusBadge: View {
    let text: String
    var systemImage: String? = nil
    var tint: Color = DSColor.accent

    var body: some View {
        Group {
            if let systemImage {
                Label(text, systemImage: systemImage)
            } else {
                Text(text)
            }
        }
        .font(DSFont.label)
        .tracking(0.3)
        // One line at every text size: shrink before "Question-able" breaks mid-word,
        // and win space from the row's title rather than wrap.
        .lineLimit(1)
        .minimumScaleFactor(0.6)
        .layoutPriority(1)
        // Pills stop growing at the largest standard size: at accessibility sizes a
        // one-word grade otherwise clips to "Question…". Still large, never cut.
        .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
        .padding(.horizontal, DSSpacing.sm - 1)
        .padding(.vertical, DSSpacing.xxs + 1)
        .background(tint.opacity(0.18))
        .foregroundStyle(tint)
        .clipShape(Capsule())
    }
}

#Preview("Components") {
    ScrollView {
        VStack(spacing: DSSpacing.lg) {
            PrimaryButton(title: "Scan barcode", systemImage: "camera.fill") {}
            SecondaryButton(title: "Request manual review", systemImage: "camera.viewfinder") {}

            Card {
                Text("Card title").font(DSFont.headline).foregroundStyle(DSColor.textPrimary)
                Text("Supporting copy on a surface.")
                    .font(DSFont.body).foregroundStyle(DSColor.textSecondary)
            }

            HStack(spacing: DSSpacing.xs) {
                StatusBadge(text: "Halal", systemImage: Verdict.halal.symbolName, tint: Verdict.halal.tint)
                StatusBadge(text: "Questionable", systemImage: Verdict.doubtful.symbolName, tint: Verdict.doubtful.tint)
                StatusBadge(text: "Haram", systemImage: Verdict.haram.symbolName, tint: Verdict.haram.tint)
            }

            Text("Glowing focal element")
                .font(DSFont.headline).foregroundStyle(DSColor.textPrimary)
                .padding(DSSpacing.md)
                .glowingOutline()
        }
        .padding()
    }
    .background(DSColor.background)
}
