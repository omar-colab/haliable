//
//  AcknowledgementsView.swift
//  Haliable
//
//  Licenses / data-source attributions. Haliable bundles no third-party Swift
//  packages by default (Supabase is optional and only linked when added), so
//  this is mostly about the open data the scanner relies on — which their
//  licenses require us to credit.
//

import SwiftUI

struct AcknowledgementsView: View {
    private struct Credit: Identifiable {
        let id = UUID()
        let name: String
        let license: String
        let detail: String
        let url: String
    }

    private let credits: [Credit] = [
        Credit(name: "Open Food Facts",
               license: "Open Database License (ODbL) 1.0",
               detail: "Primary product & ingredient database. Data © contributors, used under ODbL.",
               url: "https://world.openfoodfacts.org"),
        Credit(name: "USDA FoodData Central",
               license: "U.S. Public Domain",
               detail: "Fallback nutrition & ingredient lookups.",
               url: "https://fdc.nal.usda.gov"),
        Credit(name: "SF Symbols",
               license: "Apple SF Symbols License",
               detail: "System iconography throughout the app.",
               url: "https://developer.apple.com/sf-symbols/"),
    ]

    var body: some View {
        List {
            Section {
                ForEach(credits) { credit in
                    VStack(alignment: .leading, spacing: DSSpacing.xxs) {
                        Text(credit.name)
                            .font(DSFont.headline)
                            .foregroundStyle(DSColor.textPrimary)
                        Text(credit.license)
                            .font(DSFont.caption)
                            .foregroundStyle(DSColor.accent)
                        Text(credit.detail)
                            .font(DSFont.body)
                            .foregroundStyle(DSColor.textSecondary)
                        if let url = URL(string: credit.url) {
                            Link(credit.url, destination: url)
                                .font(DSFont.caption)
                        }
                    }
                    .padding(.vertical, DSSpacing.xxs)
                    .listRowBackground(DSColor.surface)
                }
            } footer: {
                Text("Halal rulings cite IFANCA, ISNA, and AMJA guidance. Citations should be independently verified before relying on them.")
                    .font(DSFont.caption)
                    .foregroundStyle(DSColor.textSecondary)
            }
        }
        .scrollContentBackground(.hidden)
        .background(DSColor.background)
        .navigationTitle("Acknowledgements")
        .navigationBarTitleDisplayMode(.inline)
    }
}
