//
//  ScanOrb.swift
//  Haliable
//
//  The "checking ingredients" loader: a slowly turning sphere of dots with a
//  gold scan band sweeping it like a barcode laser. Drawn natively in one
//  Canvas (no package). Under Reduce Motion it holds still.
//

import SwiftUI

struct ScanOrb: View {
    var diameter: CGFloat = 96
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// Fibonacci sphere: evenly spread points, computed once.
    private static let points: [SIMD3<Double>] = {
        let n = 150, golden = Double.pi * (3 - 5.0.squareRoot())
        return (0..<n).map { i in
            let y = 1 - 2 * (Double(i) + 0.5) / Double(n)
            let r = (1 - y * y).squareRoot(), a = golden * Double(i)
            return SIMD3(cos(a) * r, y, sin(a) * r)
        }
    }()

    var body: some View {
        TimelineView(.animation(paused: reduceMotion)) { timeline in
            let t = reduceMotion ? 0.6 : timeline.date.timeIntervalSinceReferenceDate
            Canvas { ctx, size in
                let spin = t * 0.7, tilt = 0.38
                let breathe = 1 + 0.035 * sin(t * 2.2)
                let radius = min(size.width, size.height) / 2 * 0.86 * breathe
                let mid = CGPoint(x: size.width / 2, y: size.height / 2)
                let band = sin(t * 1.6)                     // scan line, -1…1
                for p in Self.points {
                    // spin around y, then tilt toward the viewer
                    let x = p.x * cos(spin) + p.z * sin(spin)
                    let z0 = -p.x * sin(spin) + p.z * cos(spin)
                    let y = p.y * cos(tilt) - z0 * sin(tilt)
                    let z = p.y * sin(tilt) + z0 * cos(tilt)
                    let depth = (z + 1) / 2                 // 0 back … 1 front
                    let hit = max(0, 1 - abs(y - band) * 6) // inside the band
                    let dot = (1.1 + 1.6 * depth + 1.4 * hit) * diameter / 96
                    let rect = CGRect(x: mid.x + x * radius - dot / 2, y: mid.y + y * radius - dot / 2,
                                      width: dot, height: dot)
                    ctx.opacity = 0.18 + 0.82 * max(depth, hit)
                    ctx.fill(Path(ellipseIn: rect), with: .color(hit > 0.25 ? DSColor.gold : DSColor.accent))
                }
            }
        }
        .frame(width: diameter, height: diameter)
        .background(Circle().fill(DSColor.accent.opacity(0.10)).blur(radius: 22))
        .accessibilityHidden(true)
    }
}

/// Status line that cycles through what the app is doing, so the wait reads as work.
struct CyclingStatus: View {
    let lines: [String]
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1.3)) { timeline in
            let i = reduceMotion || lines.isEmpty ? 0 : Int(timeline.date.timeIntervalSinceReferenceDate / 1.3) % lines.count
            ZStack {
                Text(lines.isEmpty ? "" : lines[i])
                    .id(i)
                    .transition(.opacity.combined(with: .offset(y: 6)))
            }
            .animation(DSMotion.move, value: i)
        }
    }
}

/// The "thinking" orb: a soft liquid blob in the brand green and gold that
/// wobbles while the app waits on something slower than a scan (a scholar
/// review, a map lookup). Same idea as ScanOrb: one Canvas, no package, and
/// it holds still under Reduce Motion.
struct ThinkingOrb: View {
    var diameter: CGFloat = 64
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        TimelineView(.animation(paused: reduceMotion)) { timeline in
            let t = reduceMotion ? 0 : timeline.date.timeIntervalSinceReferenceDate
            Canvas { ctx, size in
                let mid = CGPoint(x: size.width / 2, y: size.height / 2)
                let r = min(size.width, size.height) / 2 * 0.78
                // three slow lobes + a faster ripple = organic, never repeating exactly
                func blob(_ phase: Double, _ amp: Double) -> Path {
                    var path = Path()
                    let n = 72
                    for k in 0...n {
                        let a = Double(k) / Double(n) * 2 * .pi
                        let wob = 1 + amp * (0.55 * sin(3 * a + t * 1.3 + phase)
                                           + 0.30 * sin(2 * a - t * 0.9 + phase * 2)
                                           + 0.15 * sin(5 * a + t * 2.1))
                        let pt = CGPoint(x: mid.x + cos(a) * r * wob, y: mid.y + sin(a) * r * wob)
                        k == 0 ? path.move(to: pt) : path.addLine(to: pt)
                    }
                    path.closeSubpath()
                    return path
                }
                let spin = Angle(radians: t * 0.6)
                ctx.fill(blob(1.7, 0.10),
                         with: .linearGradient(Gradient(colors: [DSColor.gold.opacity(0.55), DSColor.accent.opacity(0.35)]),
                                               startPoint: .zero, endPoint: CGPoint(x: size.width, y: size.height)))
                ctx.fill(blob(0, 0.08),
                         with: .conicGradient(Gradient(colors: [DSColor.accent, DSColor.accentDeep, DSColor.gold, DSColor.accent]),
                                              center: mid, angle: spin))
                // glassy highlight, top-left
                let hl = CGRect(x: mid.x - r * 0.55, y: mid.y - r * 0.62, width: r * 0.7, height: r * 0.42)
                ctx.fill(Path(ellipseIn: hl), with: .radialGradient(Gradient(colors: [.white.opacity(0.55), .clear]),
                                                                   center: CGPoint(x: hl.midX, y: hl.midY),
                                                                   startRadius: 0, endRadius: r * 0.4))
            }
        }
        .frame(width: diameter, height: diameter)
        .background(Circle().fill(DSColor.accent.opacity(0.18)).blur(radius: diameter / 4))
        .accessibilityHidden(true)
    }
}

#Preview {
    VStack(spacing: 16) {
        ThinkingOrb()
        ScanOrb()
        CyclingStatus(lines: ["Reading barcode…", "Checking ingredients…"])
    }
    .padding()
    .background(DSColor.background)
}
