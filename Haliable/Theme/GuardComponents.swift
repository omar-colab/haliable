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

/// Fades and lifts a block into place the first time it appears, `delay` after
/// its siblings, so a screen assembles top to bottom instead of popping in.
/// Reduce Motion: shows at once.
struct RevealOnAppear: ViewModifier {
    var delay: Double
    @State private var shown = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        content
            .opacity(shown || reduceMotion ? 1 : 0)
            .offset(y: shown || reduceMotion ? 0 : 14)
            .onAppear {
                guard !shown else { return }
                withAnimation(DSMotion.arrive.delay(delay)) { shown = true }
            }
    }
}

extension View {
    func reveal(_ delay: Double = 0) -> some View { modifier(RevealOnAppear(delay: delay)) }
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
    /// 0–100 score; when set, a ring replaces the symbol (History rows).
    var score: Int? = nil
    /// Something is still working on this row (a scholar review): the thinking orb replaces the symbol.
    var thinking = false
    var action: (() -> Void)? = nil

    var body: some View {
        let content = HStack(spacing: DSSpacing.sm) {
            if let score {
                ScoreRing(score: score, tint: tint)
            } else if thinking {
                ThinkingOrb(diameter: 42)
            } else {
                Image(systemName: symbol)
                    .font(.system(size: 17, weight: .medium))
                    .foregroundStyle(tint)
                    .frame(width: 42, height: 42)
                    .background(tint.opacity(0.14), in: Circle())
                    .overlay(Circle().strokeBorder(DSColor.outline, lineWidth: 1))
            }

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

/// Small 0–100 ring for list rows — same stroke language as FlaggedRing.
struct ScoreRing: View {
    let score: Int
    let tint: Color
    var diameter: CGFloat = 42
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    /// Starts at 0 and springs to `score` on appear: the ring draws in, the number counts up.
    @State private var shown = 0

    var body: some View {
        ZStack {
            Circle().fill(tint.opacity(0.14))
            Circle().strokeBorder(DSColor.outline, lineWidth: 3.5)
            Circle()
                .trim(from: 0, to: Double(min(max(shown, 0), 100)) / 100)
                .stroke(tint, style: StrokeStyle(lineWidth: 3.5, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .padding(1.75)
            Text("\(shown)")
                .font(.system(size: 13, weight: .semibold))
                .monospacedDigit()
                .contentTransition(.numericText(value: Double(shown)))
                .foregroundStyle(DSColor.textPrimary)
        }
        .frame(width: diameter, height: diameter)
        .onAppear {
            guard !reduceMotion else { shown = score; return }
            withAnimation(.spring(response: 0.9, dampingFraction: 0.9).delay(0.1)) { shown = score }
        }
        .onChange(of: score) { shown = score }
        .accessibilityElement()
        .accessibilityLabel("Score \(score) out of 100")
    }
}

// MARK: - Ambient orbs

/// Soft drifting glows behind the content. Decorative only — never hit-tested,
/// hidden from VoiceOver, and still under Reduce Motion.
struct GuardOrbs: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// Anchor (fraction of the screen from centre), size, and how far and how fast it wanders.
    private struct Orb { let color: Color; let size, ax, ay, reach, speed, phase: CGFloat }
    private let orbs = [
        Orb(color: DSColor.accent, size: 230, ax:  0.30, ay: -0.30, reach: 70, speed: 0.11, phase: 0),
        Orb(color: DSColor.gold,   size: 190, ax: -0.34, ay:  0.22, reach: 80, speed: 0.09, phase: 2.1),
        Orb(color: DSColor.accent, size: 160, ax:  0.36, ay:  0.06, reach: 60, speed: 0.13, phase: 4.2),
        Orb(color: DSColor.gold,   size: 120, ax: -0.20, ay: -0.10, reach: 90, speed: 0.07, phase: 1.3),
    ]

    var body: some View {
        GeometryReader { geo in
            TimelineView(.animation(minimumInterval: 1 / 30, paused: reduceMotion)) { timeline in
                let t = reduceMotion ? 0 : CGFloat(timeline.date.timeIntervalSinceReferenceDate
                                                  .truncatingRemainder(dividingBy: 10_000))
                ZStack {
                    ForEach(orbs.indices, id: \.self) { i in
                        let o = orbs[i]
                        let a = t * o.speed + o.phase
                        // breathes between dim and bright on its own beat
                        let glow = 0.5 + 0.5 * sin(a * 1.7)
                        Circle()
                            .fill(RadialGradient(colors: [o.color.opacity(0.20 + 0.16 * glow), o.color.opacity(0)],
                                                 center: .center, startRadius: 0, endRadius: o.size * 0.6))
                            .frame(width: o.size, height: o.size)
                            .scaleEffect(0.9 + 0.2 * glow)
                            .blur(radius: 36)
                            // a lazy figure-eight around its anchor
                            .offset(x: geo.size.width * o.ax + o.reach * sin(a),
                                    y: geo.size.height * o.ay + o.reach * 0.8 * sin(a * 2 + 0.5))
                    }
                }
                .frame(width: geo.size.width, height: geo.size.height)
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

// MARK: - Emblem

/// Nested squircles radiating from a capsule. Reads as a signal going out,
/// which is what a scanner does.
struct RingEmblem: View {
    var rings: Int = 9
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        TimelineView(.animation(minimumInterval: 1 / 30, paused: reduceMotion)) { timeline in
            // a slow sonar pulse travels outward through the rings every ~3 s
            let wave = reduceMotion ? -1 : (timeline.date.timeIntervalSinceReferenceDate / 3)
                .truncatingRemainder(dividingBy: 1) * Double(rings + 3) - 1
            emblem(wave: wave)
        }
        .frame(height: 86)
        .clipped()
        .accessibilityHidden(true)
    }

    private func emblem(wave: Double) -> some View {
        ZStack {
            ForEach(0..<rings, id: \.self) { i in
                let step = CGFloat(i + 1)
                let glow = max(0, 1 - abs(Double(i) - wave))
                RoundedRectangle(cornerRadius: (46 + step * 10) / 2, style: .continuous)
                    .strokeBorder(DSColor.outlineStrong.opacity(0.85 - Double(i) / Double(rings + 1)),
                                  lineWidth: 1)
                    .overlay(RoundedRectangle(cornerRadius: (46 + step * 10) / 2, style: .continuous)
                        .strokeBorder(DSColor.accent.opacity(0.55 * glow), lineWidth: 1.2))
                    .frame(width: 92 + step * 32, height: 46 + step * 10)
            }
            Image("HMark")
                .resizable().scaledToFit()
                .frame(width: 19, height: 19)
                .frame(width: 86, height: 42)
                .background(DSColor.surface, in: Capsule())
                .overlay(Capsule().strokeBorder(DSColor.outlineStrong, lineWidth: 1))
        }
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
