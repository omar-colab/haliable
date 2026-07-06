//
//  VerdictBadge.swift
//  Haliable
//
//  Created by Omar O on 6/1/26.
//

import SwiftUI

// A small colored pill showing a verdict: green Halal, red Haram, amber
// Questionable. Reused everywhere a verdict appears, so it lives in Components.
//
// Now a thin wrapper over the generic `StatusBadge` chip — the verdict's color
// and icon come from the design tokens (`Verdict.tint` / `Verdict.symbolName`),
// so there's one source of truth instead of a color switch repeated per screen.
struct VerdictBadge: View {
    let verdict: Verdict

    var body: some View {
        StatusBadge(text: verdict.displayName,
                    systemImage: verdict.symbolName,
                    tint: verdict.tint)
    }
}

// #Preview lets you see this component live in Xcode's canvas
// without running the whole app. Great for designing in isolation.
#Preview {
    VStack(spacing: 12) {
        VerdictBadge(verdict: .halal)
        VerdictBadge(verdict: .haram)
        VerdictBadge(verdict: .doubtful)
    }
}
