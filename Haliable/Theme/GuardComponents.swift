//
//  GuardComponents.swift
//  Haliable
//
//  The v5 surface: a gradient action card, rows that end in a circular arrow,
//  a ring that counts what CLEARED rather than only what failed, and the
//  squircle emblem. Shared so Scan, Verdict, Atlas, Reviews and History all
//  speak the same language instead of each inventing its own row.
//
//  Motion values are Apple's own, not invented here: critically damped for
//  anything that merely moves, bounce reserved for gestures carrying momentum.
//  Overshoot on something that only faded in reads as a bug.
//

import SwiftUI

// MARK: - Motion

enum DSMotion {
    /// Things that move or resize. Critically damped — no overshoot.
    static let move   = Animation.spring(response: 0.4, dampingFraction: 1.0)
    /// Rotation and badge arrivals. A little bounce, because they carry momentum.
    static let arrive = Animation.spring(response: 0.4, dampingFraction: 0.8)
    /// Drawers and sheets.
    static let sheet  = Animation.spring(response: 0.3, dampingFraction: 0.8)
}

/// Responds on press-DOWN, not on release. Waiting for touch-up is the single
/// thing that makes an interface feel dead.
struct PressableStyle: ButtonStyle {
    var scale: CGFloat = 0.97
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? scale : 1)
            .animation(.easeOut(duration: 0.1), value: configuration.isPressed)
    }
}

extension View {
    func pressable(_ scale: CGFloat = 0.97) -> some View {
        buttonStyle(PressableStyle(scale: scale))
    }
}

// MARK: - Gradient action card

/// The one loud control on a screen: icon tile, title, supporting line, and a
/// circular arrow. Deliberately singular — two of these on one screen and
/// neither reads as the primary thing to do.
struct GuardAction: View {
    let symbol: String
    let title: String
    let subtitle: String
    /// nil renders a static summary card: no arrow, not a button.
    var action: (() -> Void)? = {}

    var body: some View {
        if let action {
            Button(action: action) { card(arrow: true) }
                .pressable()
                .accessibilityLabel("\(title). \(subtitle)")
        } else {
            card(arrow: false).accessibilityElement(children: .combine)
        }
    }

    private func card(arrow: Bool) -> some View {
        HStack(spacing: DSSpacing.sm) {
            Image(systemName: symbol)
                .font(.system(size: 19, weight: .medium))
                .foregroundStyle(.white)
                .frame(width: 44, height: 44)
                .background(.white.opacity(0.18), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .strokeBorder(.white.opacity(0.3), lineWidth: 1)
                )

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(.white)
                Text(subtitle)
                    .font(.system(size: 11))
                    .foregroundStyle(.white.opacity(0.9))
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            if arrow {
                Image(systemName: "arrow.up.right")
                    .font(.system(size: 19, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 52, height: 52)
                    .background(
                        Circle().fill(
                            LinearGradient(colors: [.white.opacity(0.42), .white.opacity(0.12)],
                                           startPoint: .topLeading, endPoint: .bottomTrailing))
                    )
                    .overlay(Circle().strokeBorder(.white.opacity(0.5), lineWidth: 1.5))
            }
        }
        .padding(14)
        .frame(minHeight: arrow ? 0 : 72)
        .background(
            LinearGradient(colors: [DSColor.accent, DSColor.accentGradientEnd],
                           startPoint: .topLeading, endPoint: .bottomTrailing),
            in: RoundedRectangle(cornerRadius: 28, style: .continuous)
        )
        .overlay {
            // The board's halftone — a faint dot grid over the gradient.
            Canvas { ctx, size in
                let step: CGFloat = 7
                var y: CGFloat = 0
                while y < size.height {
                    var x: CGFloat = 0
                    while x < size.width {
                        ctx.fill(Path(ellipseIn: CGRect(x: x, y: y, width: 1.5, height: 1.5)), with: .color(.white))
                        x += step
                    }
                    y += step
                }
            }
            .opacity(0.22)
            .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
            .allowsHitTesting(false)
            .accessibilityHidden(true)
        }
        .shadow(color: DSColor.accent.opacity(0.35), radius: 18, y: 8)
    }
}

// MARK: - Row

/// A list row across the whole app: tinted circular chip, two lines, and a
/// large outline arrow. The arrow is bigger than the chip on purpose — it is
/// the tap target, and it should look like one.
struct GuardRow: View {
    let symbol: String
    let tint: Color
    let title: String
    let subtitle: String
    var trailing: String? = nil
    var showsArrow: Bool = true
    var action: (() -> Void)? = nil

    var body: some View {
        let content = HStack(spacing: DSSpacing.sm) {
            Image(systemName: symbol)
                .font(.system(size: 17, weight: .medium))
                .foregroundStyle(tint)
                .frame(width: 42, height: 42)
                .background(tint.opacity(0.14), in: Circle())
                .overlay(Circle().strokeBorder(DSColor.outline, lineWidth: 1))

            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(DSColor.textPrimary)
                    .lineLimit(1)
                Text(subtitle)
                    .font(.system(size: 11.5))
                    .foregroundStyle(DSColor.textSecondary)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            if let trailing {
                Text(trailing)
                    .font(.system(size: 11, weight: .medium))
                    .monospacedDigit()
                    .foregroundStyle(DSColor.textTertiary)
            }
            if showsArrow {
                Image(systemName: "arrow.up.right")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(DSColor.textPrimary)
                    .frame(width: 48, height: 48)
                    .overlay(Circle().strokeBorder(DSColor.outlineStrong, lineWidth: 1))
            }
        }
        .padding(DSSpacing.sm)
        .background(DSColor.surface, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .strokeBorder(DSColor.outline, lineWidth: 1)
        )

        if let action {
            Button(action: action) { content }
                .pressable(0.985)
                .accessibilityLabel("\(title). \(subtitle)")
        } else {
            content.accessibilityElement(children: .combine)
        }
    }
}

// MARK: - Section header

struct GuardSection: View {
    let title: String
    var trailing: String? = nil
    var action: (() -> Void)? = nil

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title)
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(DSColor.textPrimary)
            Spacer(minLength: DSSpacing.sm)
            if let trailing {
                if let action {
                    Button(trailing, action: action)
                        .font(.system(size: 13))
                        .foregroundStyle(DSColor.textSecondary)
                        .pressable()
                } else {
                    Text(trailing)
                        .font(.system(size: 13))
                        .foregroundStyle(DSColor.textSecondary)
                }
            }
        }
    }
}

// MARK: - Flagged ring

/// Flagged out of CHECKED — not out of everything on the label.
///
/// `ProductVerdict.matched` is only the ingredients the engine holds a rule
/// for, so a Nutella with a dozen ingredients can report `matched.count == 2`.
/// An earlier version of this showed "0 of 2 cleared", which reads as "nothing
/// about this product is fine" and is simply not something we know. The ring
/// now states the one fact available: how many of the ingredients we checked
/// are a concern.
struct FlaggedRing: View {
    let flagged: Int
    let checked: Int
    let tint: Color
    var diameter: CGFloat = 64

    private var fraction: Double {
        guard checked > 0 else { return 0 }
        return Double(flagged) / Double(checked)
    }

    var body: some View {
        ZStack {
            Circle()
                .strokeBorder(DSColor.outline, lineWidth: 5)
            Circle()
                .trim(from: 0, to: fraction)
                .stroke(tint, style: StrokeStyle(lineWidth: 5, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(DSMotion.arrive, value: fraction)
            VStack(spacing: 0) {
                Text("\(flagged)")
                    .font(DSFont.title)
                    .foregroundStyle(DSColor.textPrimary)
                Text("FLAGGED")
                    .font(.system(size: 6.5, weight: .semibold))
                    .tracking(0.8)
                    .foregroundStyle(DSColor.textTertiary)
            }
        }
        .frame(width: diameter, height: diameter)
        .accessibilityElement()
        .accessibilityLabel(flagged == 0
                            ? "Nothing flagged out of \(checked) ingredients checked"
                            : "\(flagged) of \(checked) checked ingredients flagged")
    }
}

// MARK: - Ambient orbs

/// Soft drifting glows behind the content. Decorative only — never hit-tested,
/// hidden from VoiceOver, and still under Reduce Motion.
struct GuardOrbs: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var drift = false

    var body: some View {
        GeometryReader { geo in
            ZStack {
                orb(DSColor.accent.opacity(0.26), 220)
                    .offset(x: geo.size.width * 0.34, y: -geo.size.height * 0.30)
                    .offset(x: drift ? -14 : 10, y: drift ? 18 : -8)
                orb(DSColor.gold.opacity(0.18), 180)
                    .offset(x: -geo.size.width * 0.36, y: geo.size.height * 0.24)
                    .offset(x: drift ? 16 : -10, y: drift ? -14 : 10)
                orb(DSColor.accent.opacity(0.16), 150)
                    .offset(x: geo.size.width * 0.40, y: geo.size.height * 0.04)
                    .offset(x: drift ? 10 : -12, y: drift ? -16 : 12)
            }
            .animation(reduceMotion ? nil
                       : .easeInOut(duration: 19).repeatForever(autoreverses: true),
                       value: drift)
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
        .onAppear { if !reduceMotion { drift = true } }
    }

    private func orb(_ color: Color, _ size: CGFloat) -> some View {
        Circle()
            .fill(color)
            .frame(width: size, height: size)
            .blur(radius: 58)
    }
}

// MARK: - Emblem

/// Nested squircles radiating from a capsule. Reads as a signal going out,
/// which is what a scanner does.
struct RingEmblem: View {
    var rings: Int = 9
    var body: some View {
        ZStack {
            ForEach(0..<rings, id: \.self) { i in
                let step = CGFloat(i + 1)
                RoundedRectangle(cornerRadius: (46 + step * 10) / 2, style: .continuous)
                    .strokeBorder(DSColor.outlineStrong.opacity(0.85 - Double(i) / Double(rings + 1)),
                                  lineWidth: 1)
                    .frame(width: 92 + step * 32, height: 46 + step * 10)
            }
            Image("HMark")
                .resizable().scaledToFit()
                .frame(width: 19, height: 19)
                .frame(width: 86, height: 42)
                .background(DSColor.surface, in: Capsule())
                .overlay(Capsule().strokeBorder(DSColor.outlineStrong, lineWidth: 1))
        }
        .frame(height: 86)
        .clipped()
        .accessibilityHidden(true)
    }
}

// MARK: - Ring button

/// The thin-ring circular button from the board's top rows (back, settings, torch).
struct RingButton: View {
    let symbol: String
    let label: String
    var active: Bool = false
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(active ? DSColor.accent : DSColor.textPrimary)
                .frame(width: 38, height: 38)
                .background(DSColor.surface.opacity(0.92), in: Circle())
                .overlay(Circle().strokeBorder(active ? DSColor.accent : DSColor.outlineStrong, lineWidth: 1))
                .frame(width: 44, height: 44)
                .contentShape(Circle())
        }
        .pressable(0.92)
        .accessibilityLabel(label)
    }
}

// MARK: - Live chip

/// A floating capsule used over the camera and the map. `live` adds the pulsing dot.
struct GuardChip: View {
    let text: String
    var live: Bool = false

    var body: some View {
        HStack(spacing: 7) {
            if live {
                Circle().fill(DSColor.accent)
                    .frame(width: 7, height: 7)
                    .background(Circle().fill(DSColor.accent.opacity(0.22)).frame(width: 15, height: 15))
            }
            Text(text)
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(DSColor.textPrimary)
                .lineLimit(1)
        }
        .padding(.horizontal, 13)
        .padding(.vertical, 8)
        .background(.ultraThinMaterial, in: Capsule())
        .background(DSColor.surface.opacity(0.6), in: Capsule())
        .overlay(Capsule().strokeBorder(DSColor.outlineStrong, lineWidth: 1))
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Crescent pill

/// The headline pill, in the app icon's colours: a gold crescent on black with
/// the mint-green glow ring. Replaces the board's "AI" pill — the verdicts come
/// from rules and citations, not a model, so "AI" would be an overclaim.
struct CrescentPill: View {
    var body: some View {
        Image(systemName: "moon.fill")
            .font(.system(size: 17, weight: .bold))
            .rotationEffect(.degrees(-25))
            .foregroundStyle(LinearGradient(colors: [Color(red: 0.93, green: 0.78, blue: 0.36), DSColor.gold],
                                            startPoint: .top, endPoint: .bottom))
            .padding(.horizontal, 15)
            .padding(.vertical, 5)
            .background(Capsule().fill(.black))
            .overlay(Capsule().strokeBorder(DSColor.accent, lineWidth: 2))
            .shadow(color: DSColor.accent.opacity(0.55), radius: 13)
            .accessibilityHidden(true)
    }
}

// MARK: - Scan reticle

/// Glowing corner brackets with a sweeping beam. Decorative; respects Reduce Motion.
struct ScanReticle: View {
    var active: Bool = true
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var beamDown = false

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width * 0.72, h = min(geo.size.height * 0.36, w * 1.05)
            ZStack {
                ReticleCorners()
                    .stroke(DSColor.accent, style: StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round))
                    .shadow(color: DSColor.accent.opacity(0.6), radius: 8)
                if active {
                    LinearGradient(colors: [DSColor.accent.opacity(0), DSColor.accent, DSColor.accent.opacity(0)],
                                   startPoint: .leading, endPoint: .trailing)
                        .frame(height: 2)
                        .shadow(color: DSColor.accent, radius: 8)
                        .opacity(beamDown ? 1 : 0.35)
                        .offset(y: (beamDown ? 0.47 : -0.47) * h)
                }
            }
            .frame(width: w, height: h)
            .position(x: geo.size.width / 2, y: geo.size.height * 0.45)
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
        .onAppear {
            guard active, !reduceMotion else { return }
            withAnimation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true)) { beamDown = true }
        }
    }

    private struct ReticleCorners: Shape {
        func path(in r: CGRect) -> Path {
            var p = Path(); let l: CGFloat = 28, c: CGFloat = 8
            for (x, y, dx, dy) in [(r.minX, r.minY, 1.0, 1.0), (r.maxX, r.minY, -1.0, 1.0),
                                   (r.minX, r.maxY, 1.0, -1.0), (r.maxX, r.maxY, -1.0, -1.0)] {
                p.move(to: CGPoint(x: x, y: y + dy * l))
                p.addLine(to: CGPoint(x: x, y: y + dy * c))
                p.addQuadCurve(to: CGPoint(x: x + dx * c, y: y), control: CGPoint(x: x, y: y))
                p.addLine(to: CGPoint(x: x + dx * l, y: y))
            }
            return p
        }
    }
}

// MARK: - Dock bubbles

/// One overlapping circle in a floating dock.
struct DockBubble: View {
    let symbol: String
    let label: String
    var selected: Bool = false
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 19, weight: selected ? .semibold : .regular))
                .foregroundStyle(selected ? DSColor.accent : DSColor.textPrimary)
                .frame(width: 56, height: 56)
                .background(.ultraThinMaterial, in: Circle())
                .background(DSColor.surface.opacity(0.7), in: Circle())
                .overlay(Circle().strokeBorder(selected ? DSColor.accent.opacity(0.7) : DSColor.outline, lineWidth: 1))
                .shadow(color: .black.opacity(0.18), radius: 8, y: 3)
        }
        .pressable(0.92)
        .accessibilityLabel(label)
        .accessibilityAddTraits(selected ? [.isSelected] : [])
    }
}

/// The big gradient centre circle of a dock.
struct DockMainBubble: View {
    let symbol: String
    let label: String
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 24, weight: .medium))
                .foregroundStyle(.white)
                .frame(width: 66, height: 66)
                .background(LinearGradient(colors: [DSColor.accent, DSColor.accentGradientEnd],
                                           startPoint: .topLeading, endPoint: .bottomTrailing),
                            in: Circle())
                .overlay(Circle().strokeBorder(.white.opacity(0.22), lineWidth: 2))
                .background(Circle().fill(DSColor.accent.opacity(0.12)).frame(width: 80, height: 80))
                .shadow(color: DSColor.accent.opacity(0.5), radius: 17)
        }
        .pressable(0.92)
        .accessibilityLabel(label)
        .zIndex(1)
    }
}

// MARK: - Identity row

/// The board's top row: crescent avatar, a two-line title, and a trailing control.
struct GuardIDRow<Trailing: View>: View {
    let title: String
    let subtitle: String
    @ViewBuilder var trailing: () -> Trailing

    var body: some View {
        HStack(spacing: 9) {
            Image(systemName: "moon.fill")
                .font(.system(size: 14, weight: .semibold))
                .rotationEffect(.degrees(-25))
                .foregroundStyle(.white)
                .frame(width: 34, height: 34)
                .background(LinearGradient(colors: [DSColor.accent, DSColor.accentGradientEnd],
                                           startPoint: .topLeading, endPoint: .bottomTrailing), in: Circle())
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 0) {
                Text(title)
                    .font(.system(size: 14, weight: .semibold))
                    .italic()
                    .foregroundStyle(DSColor.textPrimary)
                Text(subtitle)
                    .font(.system(size: 10.5))
                    .foregroundStyle(DSColor.textTertiary)
            }
            .accessibilityElement(children: .combine)
            .accessibilityAddTraits(.isHeader)
            Spacer(minLength: 0)
            trailing()
        }
    }
}

// MARK: - Segments

/// The board's row of pill filters. The selected one takes the brand gradient.
struct GuardSegments<Value: Hashable>: View {
    let options: [(Value, String)]
    @Binding var selection: Value

    var body: some View {
        HStack(spacing: 5) {
            ForEach(options, id: \.0) { value, label in
                let on = value == selection
                Button {
                    withAnimation(DSMotion.move) { selection = value }
                } label: {
                    Text(label)
                        .font(.system(size: 11, weight: .semibold))
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 9)
                        .padding(.horizontal, 2)
                        .background(
                            on ? AnyShapeStyle(LinearGradient(colors: [DSColor.accent, DSColor.accentGradientEnd],
                                                              startPoint: .topLeading, endPoint: .bottomTrailing))
                               : AnyShapeStyle(DSColor.surfaceElevated),
                            in: Capsule())
                        .overlay(Capsule().strokeBorder(on ? .clear : DSColor.outline, lineWidth: 1))
                        .foregroundStyle(on ? .white : DSColor.textSecondary)
                        .shadow(color: on ? DSColor.accent.opacity(0.35) : .clear, radius: 8, y: 4)
                }
                .pressable()
                .accessibilityLabel(label)
                .accessibilityAddTraits(on ? [.isSelected] : [])
            }
        }
    }
}

/// Shared backdrop for the Guard screens: canvas, lattice, and slow orbs.
struct GuardBackground: View {
    var body: some View {
        ZStack {
            DSColor.background
            GeometryBackdrop(intensity: 0.8)
            GuardOrbs()
        }
        .ignoresSafeArea()
        .accessibilityHidden(true)
    }
}
