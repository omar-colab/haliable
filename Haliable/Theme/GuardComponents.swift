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
    var action: () -> Void = {}

    var body: some View {
        Button(action: action) {
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
            .padding(14)
            .background(
                LinearGradient(colors: [DSColor.accent, DSColor.accentDeep],
                               startPoint: .topLeading, endPoint: .bottomTrailing),
                in: RoundedRectangle(cornerRadius: 28, style: .continuous)
            )
            .shadow(color: DSColor.accent.opacity(0.35), radius: 18, y: 8)
        }
        .pressable()
        .accessibilityLabel("\(title). \(subtitle)")
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
                RoundedRectangle(cornerRadius: (54 + step * 11) / 2, style: .continuous)
                    .strokeBorder(DSColor.outline.opacity(1 - Double(i) / Double(rings + 2)),
                                  lineWidth: 1)
                    .frame(width: 104 + step * 30, height: 50 + step * 11)
            }
            Image("HMark")
                .resizable().scaledToFit()
                .frame(width: 24, height: 24)
                .frame(width: 100, height: 48)
                .background(DSColor.surface, in: Capsule())
                .overlay(Capsule().strokeBorder(DSColor.outlineStrong, lineWidth: 1))
        }
        .frame(height: 104)
        .clipped()
        .accessibilityHidden(true)
    }
}
