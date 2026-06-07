//
//  MethodologyView.swift
//  Haliable
//
//  The "About" tab: explains how verdicts are reached and the privacy stance.
//  Transparency is the product's wedge, so it gets its own screen.
//

import SwiftUI

struct MethodologyView: View {
    var body: some View {
        NavigationStack {
            List {
                Section("How verdicts work") {
                    row("checkmark.seal.fill", .green, "Halal",
                        "No prohibited or questionable ingredients matched our verified rules.")
                    row("questionmark.diamond.fill", Color(red: 0.71, green: 0.52, blue: 0.16), "Questionable",
                        "An ingredient's source couldn't be confirmed (e.g. natural flavors, unsourced gelatin, ambiguous E-numbers). We explain why instead of guessing.")
                    row("xmark.seal.fill", .red, "Haram",
                        "Contains an ingredient that is not permissible, such as pork or wine.")
                }
                Section("Our safety stance") {
                    Text("A false \"Halal\" is the worst error we can make, so anything we cannot positively confirm — including a product with no ingredient data — is shown as Questionable, never assumed halal.")
                        .font(.callout)
                }
                Section("Standards referenced") {
                    Text("IFANCA · ISNA · AMJA. Each ingredient verdict cites the body behind it. Citations should be independently verified before relying on them.")
                        .font(.callout)
                }
                Section("Privacy") {
                    Text("The scanner runs on your device. Barcodes are only sent to the anonymous Open Food Facts / USDA lookups. Sign-in (Apple) is required only to submit a manual review or a store — never to scan.")
                        .font(.callout)
                }
            }
            .navigationTitle("About")
        }
    }

    private func row(_ symbol: String, _ color: Color, _ title: String, _ body: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Label(title, systemImage: symbol).foregroundStyle(color).font(.headline)
            Text(body).font(.callout).foregroundStyle(.secondary)
        }.padding(.vertical, 2)
    }
}
