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
        Credit(name: "OpenStreetMap",
               license: "Open Database License (ODbL) 1.0",
               detail: "Halal places on the Find map. Data © OpenStreetMap contributors, used under ODbL.",
               url: "https://www.openstreetmap.org/copyright"),
        Credit(name: "USDA FoodData Central",
               license: "U.S. Public Domain",
               detail: "Fallback nutrition & ingredient lookups.",
               url: "https://fdc.nal.usda.gov"),
        Credit(name: "SF Symbols",
               license: "Apple SF Symbols License",
               detail: "System iconography throughout the app.",
               url: "https://developer.apple.com/sf-symbols/"),
        Credit(name: "Spectral",
               license: "SIL Open Font License 1.1",
               detail: "Copyright 2017 The Spectral Project Authors. The display serif — screen titles, card headers and the \"Ha\" of the wordmark.",
               url: "https://github.com/productiontype/Spectral"),
        Credit(name: "Instrument Serif",
               license: "SIL Open Font License 1.1",
               detail: "Copyright 2022 The Instrument Serif Project Authors. The editorial italic accent — the \"liable\" of the wordmark, taglines and verdict subtitles.",
               url: "https://github.com/Instrument/instrument-serif"),
        Credit(name: "Playfair Display",
               license: "SIL Open Font License 1.1",
               detail: "Copyright 2017 The Playfair Project Authors.",
               url: "https://github.com/clauseggers/Playfair-Display"),
        Credit(name: "Nunito",
               license: "SIL Open Font License 1.1",
               detail: "Copyright 2014 The Nunito Project Authors.",
               url: "https://github.com/googlefonts/nunito"),
        Credit(name: "Yellowtail",
               license: "Apache License 2.0",
               detail: "Copyright Astigmatic (AOETI).",
               url: "https://fonts.google.com/specimen/Yellowtail"),
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
                Text("Halal rulings cite published halal bodies (SANHA, AHF, IFANCA, MUIS and others) and fatwas. Citations should be independently verified before relying on them.")
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
