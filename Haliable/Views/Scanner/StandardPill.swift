//
//  StandardPill.swift
//  Haliable
//
//  The compact, tappable chip that shows the user's active halal standard with a
//  chevron and the green design-token glow. Lives at the top of the Scanner (and
//  on the Verdict screen) as an in-context entry point to the standard selector.
//

import SwiftUI

struct StandardPill: View {
    let standard: HalalStandard
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: DSSpacing.xs) {
                Image(systemName: standard.symbol)
                    .font(.caption.weight(.semibold))
                Text(standard.displayName)
                    .font(DSFont.caption.weight(.semibold))
                Image(systemName: "chevron.down")
                    .font(.caption2.weight(.bold))
                    .opacity(0.7)
            }
            .foregroundStyle(DSColor.accent)
            .padding(.horizontal, DSSpacing.sm)
            .padding(.vertical, DSSpacing.xs)
            .background(DSColor.accent.opacity(0.10), in: Capsule())
            .overlay(Capsule().strokeBorder(DSColor.accent.opacity(0.55), lineWidth: 1))
            .shadow(color: DSColor.accent.opacity(0.30), radius: 8)
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Halal standard: \(standard.displayName)")
        .accessibilityHint("Double-tap to change")
        .accessibilityAddTraits(.isButton)
    }
}

#Preview {
    VStack(spacing: DSSpacing.lg) {
        StandardPill(standard: .zabiha) {}
        StandardPill(standard: .general) {}
        StandardPill(standard: .lenient) {}
    }
    .padding()
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(DSColor.background)
}
