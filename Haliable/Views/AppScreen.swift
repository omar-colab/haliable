//
//  AppScreen.swift
//  Haliable
//
//  The holistic chrome shared by every screen, so the whole app reads as one
//  piece — the "Editorial Refined" (v4) language: a warm paper canvas (near-black
//  in dark), an editorial header (small tracked eyebrow + a large SERIF title with
//  an italic green accent), tracked section labels, and one calm card style.
//  Build a screen as:
//
//      AppScreen(eyebrow: "PREFERENCES", title: "Settings") { ...content... }
//
//  and the background, spacing, and type hierarchy match every other screen.
//  Everything is DesignTokens-only.
//

import SwiftUI

// MARK: - Ambient brand glow

/// A whisper of green at the top of the canvas — alive but never loud, so it sits
/// under the editorial paper without muddying it. Strongest in dark, faint on paper.
struct AppAmbientGlow: View {
    var body: some View {
        RadialGradient(
            colors: [DSColor.accent.opacity(0.12), DSColor.accent.opacity(0)],
            center: UnitPoint(x: 0.5, y: 0.0),
            startRadius: 4,
            endRadius: 320
        )
        .ignoresSafeArea()
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

// MARK: - Consistent editorial header

struct AppScreenHeader<Trailing: View>: View {
    let eyebrow: String
    let title: String
    /// Optional accent tail rendered in editorial italic green (e.g. "Halal").
    var titleAccent: String? = nil
    /// If true, the title renders as the two-voice brand wordmark instead of the
    /// screen display serif — used for the "Haliable" home title.
    var brand: Bool = false
    @ViewBuilder var trailing: () -> Trailing

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 6) {
                Text(eyebrow.uppercased())
                    .font(DSFont.label)
                    .tracking(2.2)
                    .foregroundStyle(DSColor.accentDeep)
                titleView
            }
            Spacer(minLength: DSSpacing.sm)
            trailing()
        }
    }

    @ViewBuilder private var titleView: some View {
        if brand {
            ObliqueText(runs: [
                .serif(title, size: 30, color: "TextPrimary"),
                .italic(titleAccent ?? "", size: 30, color: "AccentDeep"),
            ])
        } else if let titleAccent {
            let accent = titleAccent.hasPrefix(" ") ? titleAccent : " " + titleAccent
            ObliqueText(runs: [
                .serif(title, size: 36, color: "TextPrimary"),
                .italic(accent, size: 36, color: "AccentDeep"),
            ])
        } else {
            Text(title)
                .font(DSFont.display)
                .foregroundStyle(DSColor.textPrimary)
        }
    }
}

// MARK: - Screen scaffold

struct AppScreen<Trailing: View, Content: View>: View {
    let eyebrow: String
    let title: String
    var titleAccent: String? = nil
    @ViewBuilder var trailing: () -> Trailing
    @ViewBuilder var content: () -> Content

    var body: some View {
        ZStack {
            DSColor.background.ignoresSafeArea()
            GeometryBackdrop()
            AppAmbientGlow()
            VStack(spacing: 0) {
                AppScreenHeader(eyebrow: eyebrow, title: title, titleAccent: titleAccent, trailing: trailing)
                    .padding(.horizontal, DSSpacing.lg)
                    .padding(.top, DSSpacing.sm)
                    .padding(.bottom, DSSpacing.md)
                content()
            }
        }
        .toolbar(.hidden, for: .navigationBar)
    }
}

// Convenience init when there's no trailing control.
extension AppScreen where Trailing == EmptyView {
    init(eyebrow: String, title: String, titleAccent: String? = nil,
         @ViewBuilder content: @escaping () -> Content) {
        self.init(eyebrow: eyebrow, title: title, titleAccent: titleAccent,
                  trailing: { EmptyView() }, content: content)
    }
}

// MARK: - Shared card + control styling

extension View {
    /// The app's card surface: a token surface (paper) with a hairline outline and
    /// a soft, warm low shadow — the editorial "lifted paper" look.
    func glassCard(padding: CGFloat = DSSpacing.md) -> some View {
        self
            .padding(padding)
            .background(DSColor.surface, in: RoundedRectangle(cornerRadius: DSRadius.md, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: DSRadius.md, style: .continuous)
                    .strokeBorder(DSColor.outline, lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(0.06), radius: 18, y: 10)
    }

    /// A circular icon button on a surface chip — header actions (Settings gear).
    func headerChip() -> some View {
        self
            .frame(width: 42, height: 42)
            .background(DSColor.surface, in: Circle())
            .overlay(Circle().strokeBorder(DSColor.outlineStrong, lineWidth: 1))
            .shadow(color: Color.black.opacity(0.05), radius: 10, y: 4)
    }
}

// MARK: - Brand marks

/// The brand crescent — a token-colored green crescent (a full disk masked by an
/// offset disk) with a soft glow. Used inside `AppBrandMark` and decoratively.
struct CrescentMoon: View {
    var size: CGFloat = 22
    var color: Color = DSColor.accent

    var body: some View {
        Circle()
            .fill(color)
            .frame(width: size, height: size)
            .mask(
                Circle()
                    .frame(width: size, height: size)
                    .overlay(
                        Circle()
                            .frame(width: size * 0.82, height: size * 0.82)
                            .offset(x: size * 0.28, y: -size * 0.16)
                            .blendMode(.destinationOut)
                    )
                    .compositingGroup()
            )
            .accessibilityHidden(true)
    }
}

/// The rounded brand tile from the scan header: a green-wash square with a hairline
/// and the green crescent centered in it.
struct AppBrandMark: View {
    var size: CGFloat = 42
    var body: some View {
        RoundedRectangle(cornerRadius: size * 0.31, style: .continuous)
            .fill(DSColor.accentMuted)
            .overlay(
                RoundedRectangle(cornerRadius: size * 0.31, style: .continuous)
                    .strokeBorder(DSColor.accent.opacity(0.25), lineWidth: 1)
            )
            .overlay(CrescentMoon(size: size * 0.5))
            .frame(width: size, height: size)
            .accessibilityHidden(true)
    }
}

// MARK: - Section label

/// A tracked, uppercase section label with an optional accent trailing action
/// (the v4 "Recently checked · All" / "12 places · Sort" pattern).
struct SectionLabel<Trailing: View>: View {
    let text: String
    @ViewBuilder var trailing: () -> Trailing

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(text.uppercased())
                .font(DSFont.label)
                .tracking(1.5)
                .foregroundStyle(DSColor.textTertiary)
            Spacer(minLength: DSSpacing.xs)
            trailing()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

extension SectionLabel where Trailing == EmptyView {
    init(_ text: String) {
        self.init(text: text, trailing: { EmptyView() })
    }
}

extension SectionLabel {
    /// Positional label with a trailing accent action (e.g. "Recently checked · All").
    init(_ text: String, @ViewBuilder trailing: @escaping () -> Trailing) {
        self.init(text: text, trailing: trailing)
    }
}

/// An accent "more" action for a `SectionLabel` trailing slot.
struct SectionMore: View {
    let text: String
    var action: () -> Void = {}
    init(_ text: String, action: @escaping () -> Void = {}) {
        self.text = text; self.action = action
    }
    var body: some View {
        Button(action: action) {
            Text(text)
                .font(DSFont.caption)
                .foregroundStyle(DSColor.accentDeep)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Editorial product monogram

/// The monogram tile that replaces emoji product art across the app — initials in
/// editorial serif on a sunken paper square, with a faint top-left sheen.
struct ProductMonogram: View {
    let text: String
    var size: CGFloat = 46
    var corner: CGFloat = DSRadius.sm

    var body: some View {
        RoundedRectangle(cornerRadius: corner, style: .continuous)
            .fill(DSColor.surfaceElevated)
            .overlay(
                RoundedRectangle(cornerRadius: corner, style: .continuous)
                    .strokeBorder(DSColor.outline, lineWidth: 1)
            )
            .overlay(
                LinearGradient(colors: [Color.white.opacity(0.22), .clear],
                               startPoint: .topLeading, endPoint: .center)
                    .clipShape(RoundedRectangle(cornerRadius: corner, style: .continuous))
                    .blendMode(.plusLighter)
            )
            .overlay(
                Text(monogram)
                    .font(DSFont.serif(size * 0.42, weight: .medium))
                    .foregroundStyle(DSColor.textSecondary)
            )
            .frame(width: size, height: size)
            .accessibilityHidden(true)
    }

    private var monogram: String {
        let words = text.split(separator: " ").prefix(2)
        let initials = words.compactMap { $0.first }.map(String.init).joined()
        return initials.isEmpty ? String(text.prefix(1)).uppercased() : initials.uppercased()
    }
}
