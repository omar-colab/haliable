//
//  LaunchIntroView.swift
//  Haliable
//
//  A brief (~0.8s) "warm intro" shown over the main UI at launch.
//
//  It is deliberately a CONTINUATION of the static launch screen, not a second
//  splash: the static launch (Info.plist → UILaunchScreen) already paints the
//  fixed dark "LaunchBackground" with the "LaunchMark" (crescent + glowing green
//  H) centered, so this view starts from that exact frame — same image, same
//  dark background, same position — then gives the mark a confident scale-settle
//  and glow bloom, and dissolves into the TabView. Because the static screen
//  matched the first frame, there is no flash and no visible "pop".
//
//  This brand moment is always DARK (the launch screen is pinned dark), so the
//  subtree is forced to the dark appearance — DSColor.background / DSColor.accent
//  resolve to their dark variants regardless of the user's theme override.
//
//  It does NO network or blocking work. The real UI is built and live behind it
//  the entire time, so this never adds to perceived launch time — it only
//  delays the *reveal* by a few hundred milliseconds of polish.
//

import SwiftUI

struct LaunchIntroView: View {
    /// Called once the dissolve completes so the parent can drop this overlay.
    var onFinished: () -> Void

    /// Footprint of the centered mark — matches the static launch image size.
    private let markSize: CGFloat = 150

    @State private var glow: CGFloat = 0      // accent glow radius (blooms in)
    @State private var scale: CGFloat = 1.0   // gentle settle, starts at rest
    @State private var fade: Double = 1.0     // whole-overlay dissolve

    var body: some View {
        ZStack {
            DSColor.background
                .ignoresSafeArea()

            Image("LaunchMark")                 // crescent + glowing green H
                .resizable()
                .scaledToFit()
                .frame(width: markSize, height: markSize)
                // A soft accent halo on top of the mark's own baked glow.
                .shadow(color: DSColor.accent.opacity(0.45), radius: glow)
                .scaleEffect(scale)
        }
        .opacity(fade)
        .environment(\.colorScheme, .dark)      // brand moment is always dark
        .task { await run() }
    }

    private func run() async {
        // Bloom the glow and a small confident scale-up from the resting frame.
        withAnimation(.easeOut(duration: 0.45)) {
            glow = 22
            scale = 1.05
        }
        // Settle back to rest.
        withAnimation(.easeInOut(duration: 0.30).delay(0.45)) {
            scale = 1.0
        }
        // Hold the mark on screen ~0.8s, then dissolve into the app.
        try? await Task.sleep(for: .seconds(0.80))
        withAnimation(.easeInOut(duration: 0.32)) {
            fade = 0
        }
        try? await Task.sleep(for: .seconds(0.33))
        onFinished()
    }
}

#Preview {
    LaunchIntroView(onFinished: {})
}
