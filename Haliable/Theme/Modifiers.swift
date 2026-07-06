//
//  Modifiers.swift
//  Haliable
//
//  Reusable view modifiers that bundle the tokens into the app's signature
//  surfaces and treatments. Reach for `.cardStyle()` instead of re-deriving a
//  background + radius + border + shadow every time.
//

import SwiftUI

// MARK: - Card / surface

/// The app's standard container: padded content on a `surface`, rounded with a
/// continuous (squircle) corner, a hairline `outline`, and a soft shadow.
struct CardStyle: ViewModifier {
    var elevated: Bool = false
    var padding: CGFloat = DSSpacing.md

    func body(content: Content) -> some View {
        let shadow = DSElevation.shadow(elevated ? .high : .low)
        content
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(elevated ? DSColor.surfaceElevated : DSColor.surface)
            .clipShape(RoundedRectangle(cornerRadius: DSRadius.md, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: DSRadius.md, style: .continuous)
                    .strokeBorder(DSColor.outline, lineWidth: 1)
            )
            .shadow(color: shadow.color, radius: shadow.radius, x: 0, y: shadow.y)
    }
}

/// A lighter-weight surface: background + radius only, no border/shadow. Good
/// for inline tinted blocks (e.g. a status callout).
struct SurfaceStyle: ViewModifier {
    var fill: Color = DSColor.surface
    var cornerRadius: CGFloat = DSRadius.lg
    var padding: CGFloat = DSSpacing.md

    func body(content: Content) -> some View {
        content
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(fill)
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
    }
}

// MARK: - Glowing accent outline

/// The green "this is interactive / this is alive" treatment: an accent-colored
/// stroke plus an outward glow. Use sparingly on focal, tappable elements.
struct GlowingOutline: ViewModifier {
    var color: Color = DSColor.accent
    var cornerRadius: CGFloat = DSRadius.md
    var isActive: Bool = true
    var lineWidth: CGFloat = 1

    func body(content: Content) -> some View {
        content
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(color.opacity(isActive ? 0.85 : 0.25), lineWidth: lineWidth)
            )
            .shadow(color: color.opacity(isActive ? 0.45 : 0), radius: isActive ? 12 : 0)
            .animation(.easeInOut(duration: 0.25), value: isActive)
    }
}

// MARK: - Ergonomic entry points

extension View {
    /// Standard card container (surface + radius + outline + shadow).
    func cardStyle(elevated: Bool = false, padding: CGFloat = DSSpacing.md) -> some View {
        modifier(CardStyle(elevated: elevated, padding: padding))
    }

    /// Lightweight tinted surface (no border/shadow).
    func surfaceStyle(fill: Color = DSColor.surface,
                      cornerRadius: CGFloat = DSRadius.lg,
                      padding: CGFloat = DSSpacing.md) -> some View {
        modifier(SurfaceStyle(fill: fill, cornerRadius: cornerRadius, padding: padding))
    }

    /// Green accent stroke + glow for focal interactive elements.
    func glowingOutline(color: Color = DSColor.accent,
                        cornerRadius: CGFloat = DSRadius.md,
                        isActive: Bool = true,
                        lineWidth: CGFloat = 1) -> some View {
        modifier(GlowingOutline(color: color, cornerRadius: cornerRadius,
                                isActive: isActive, lineWidth: lineWidth))
    }
}
