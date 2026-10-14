//
//  GeometryBackdrop.swift
//  Haliable
//
//  The landing page's backdrop, brought into the app so the two read as one
//  product: a faint square grid with an Islamic geometric lattice tiled over it.
//
//  Ported 1:1 from `site/index.html` so the proportions match the web:
//    • grid    — 64pt squares, hairline, accent at ~2.5% (`.hero-grid`)
//    • lattice — a 110pt tile of a diamond, a square, a centre circle and four
//                edge ticks, gold stroke at ~13% (`.pattern`)
//
//  It is drawn in a single `Canvas` rather than as stacked tiled images: one
//  pass, no view-per-tile explosion, and it costs nothing when offscreen.
//
//  Decoration only — never hit-testable, always hidden from VoiceOver.
//

import SwiftUI

// MARK: - The tile

/// One 110×110 cell of the lattice, in the tile's own coordinate space.
/// Kept separate from the drawing code so it can be unit-tested.
enum IslamicLatticeTile {
    static let side: CGFloat = 110

    /// The tile's strokes, as paths in a `side`×`side` box at `origin`.
    static func paths(at origin: CGPoint) -> [Path] {
        func p(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
            CGPoint(x: origin.x + x, y: origin.y + y)
        }

        // Diamond: M55 6 L104 55 L55 104 L6 55 Z
        var diamond = Path()
        diamond.move(to: p(55, 6))
        diamond.addLine(to: p(104, 55))
        diamond.addLine(to: p(55, 104))
        diamond.addLine(to: p(6, 55))
        diamond.closeSubpath()

        // Square: M22 22 L88 22 L88 88 L22 88 Z
        let square = Path(CGRect(x: origin.x + 22, y: origin.y + 22, width: 66, height: 66))

        // Centre circle, r = 15
        let circle = Path(ellipseIn: CGRect(x: origin.x + 40, y: origin.y + 40, width: 30, height: 30))

        // Four edge ticks, which make neighbouring tiles read as one lattice.
        var ticks = Path()
        for (from, to) in [((55.0, 0.0), (55.0, 14.0)), ((55.0, 96.0), (55.0, 110.0)),
                           ((0.0, 55.0), (14.0, 55.0)), ((96.0, 55.0), (110.0, 55.0))] {
            ticks.move(to: p(from.0, from.1))
            ticks.addLine(to: p(to.0, to.1))
        }

        return [diamond, square, circle, ticks]
    }
}

// MARK: - The backdrop

/// Grid + lattice. Sits above the background colour and below everything else.
struct GeometryBackdrop: View {
    /// Dialled down over busy content (a camera viewfinder, a map).
    var intensity: Double = 1

    var body: some View {
        Canvas { context, size in
            let grid = DSColor.accent.opacity(0.025 * intensity)
            var lines = Path()
            for x in stride(from: 0, through: size.width, by: 64) {
                lines.move(to: CGPoint(x: x, y: 0))
                lines.addLine(to: CGPoint(x: x, y: size.height))
            }
            for y in stride(from: 0, through: size.height, by: 64) {
                lines.move(to: CGPoint(x: 0, y: y))
                lines.addLine(to: CGPoint(x: size.width, y: y))
            }
            context.stroke(lines, with: .color(grid), lineWidth: 1)

            let gold = DSColor.gold.opacity(0.10 * intensity)
            let side = IslamicLatticeTile.side
            var tiles = Path()
            for row in stride(from: 0, to: size.height + side, by: side) {
                for col in stride(from: 0, to: size.width + side, by: side) {
                    for path in IslamicLatticeTile.paths(at: CGPoint(x: col, y: row)) {
                        tiles.addPath(path)
                    }
                }
            }
            context.stroke(tiles, with: .color(gold), lineWidth: 1.1)
        }
        // Strongest at the top and gone by the bottom, the way the hero's radial
        // gradients fade the web pattern out. Without this the lattice competes
        // with the tab bar and with every card it sits behind.
        .mask(
            LinearGradient(
                stops: [.init(color: .white, location: 0.0),
                        .init(color: .white.opacity(0.75), location: 0.35),
                        .init(color: .white.opacity(0.18), location: 0.72),
                        .init(color: .clear, location: 1.0)],
                startPoint: .top, endPoint: .bottom
            )
        )
        .ignoresSafeArea()
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

// MARK: - A single floating mark

/// One slowly-turning lattice mark, drifting behind the content. The landing
/// page spins its divider mark at 26s; this matches it.
///
/// Honours Reduce Motion by standing still rather than disappearing — the shape
/// is part of the composition, only the movement is the accessibility problem.
struct FloatingLatticeMark: View {
    var size: CGFloat = 220
    var opacity: Double = 0.07

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var turning = false

    var body: some View {
        Canvas { context, canvasSize in
            let scale = canvasSize.width / IslamicLatticeTile.side
            context.scaleBy(x: scale, y: scale)
            var path = Path()
            for sub in IslamicLatticeTile.paths(at: .zero) { path.addPath(sub) }
            context.stroke(path, with: .color(DSColor.gold.opacity(opacity)), lineWidth: 1.6)
        }
        .frame(width: size, height: size)
        .rotationEffect(.degrees(turning ? 360 : 0))
        .animation(reduceMotion ? nil : .linear(duration: 26).repeatForever(autoreverses: false),
                   value: turning)
        .onAppear { if !reduceMotion { turning = true } }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}
