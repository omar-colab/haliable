//
//  VerdictBadge.swift
//  Haliable
//
//  Created by Omar O on 6/1/26.
//

import SwiftUI

// A small colored pill showing a verdict: green Halal, red Haram, orange Doubtful.
// Reused everywhere a verdict appears, so it lives in Components.
struct VerdictBadge: View {
    let verdict: Verdict

    var body: some View {
        // Pick color, icon, and label based on the verdict.
        // This 'switch' is exactly the pattern you practiced on Day 5.
        let (color, symbol): (Color, String) = {
            switch verdict {
            case .halal:
                return (.green, "checkmark.seal.fill")
            case .haram:
                return (.red, "xmark.seal.fill")
            case .doubtful:
                return (Color(red: 0.71, green: 0.52, blue: 0.16), "questionmark.diamond.fill") // honest amber
            }
        }()

        Label(verdict.displayName, systemImage: symbol)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(color.opacity(0.18))   // faint colored background
            .foregroundStyle(color)            // bold text in the same color
            .clipShape(Capsule())              // rounded pill shape
            .bold()
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
