//
//  HalalStandardEducationView.swift
//  Haliable
//
//  Plain-language explainer reached from the (?) in the standard selector. No
//  fiqh jargon dumps — just "here's what each setting actually changes."
//

import SwiftUI

struct HalalStandardEducationView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DSSpacing.lg) {
                Text("Scholars differ on where the line falls. Haliable lets you pick the position you follow, and applies it consistently to every scan. Stricter settings flag more things; none of them will ever call something Halal that we can't confirm.")
                    .font(DSFont.body)
                    .foregroundStyle(DSColor.textSecondary)

                ForEach(HalalStandard.allCases.sorted { $0.strictnessRank > $1.strictnessRank }) { std in
                    VStack(alignment: .leading, spacing: DSSpacing.xs) {
                        Label(std.displayName, systemImage: std.symbol)
                            .font(DSFont.headline)
                            .foregroundStyle(DSColor.accent)
                        Text(std.whatThisMeans)
                            .font(DSFont.body)
                            .foregroundStyle(DSColor.textPrimary)
                    }
                    .cardStyle()
                }

                Text("Haliable's rulings cite published halal bodies (SANHA, AHF, IFANCA, MUIS and others) and fatwas. Standard mappings are a first pass and should be independently verified — they're a guide, not a fatwa.")
                    .font(DSFont.caption)
                    .foregroundStyle(DSColor.textSecondary)
            }
            .padding(DSSpacing.md)
        }
        .scrollContentBackground(.hidden)
        .background(DSColor.background)
        .navigationTitle("Halal Standards")
        .navigationBarTitleDisplayMode(.inline)
    }
}
