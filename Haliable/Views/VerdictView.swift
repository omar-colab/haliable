//
//  VerdictView.swift
//  Haliable
//
//  Created by Omar O on 6/3/26.
//

import SwiftUI

struct VerdictView: View {
    let verdict: ProductVerdict
    @State private var showReviewRequest = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    VerdictBadge(verdict: verdict.overall)
                        .padding(.top)

                    Text(verdict.product.name)
                        .font(.title.bold())
                    if let brand = verdict.product.brand {
                        Text(brand).foregroundStyle(.secondary)
                    }

                    Text(verdict.summary)
                        .font(.callout)
                        .foregroundStyle(.secondary)

                    Divider()

                    Text("What we flagged")
                        .font(.headline)

                    if verdict.flagged.isEmpty {
                        EmptyStateView(
                            symbol: "checkmark.circle",
                            title: "Nothing flagged",
                            message: "No prohibited or questionable ingredients matched our verified rules."
                        )
                    } else {
                        ForEach(verdict.flagged) { item in
                            flaggedRow(item)
                        }
                    }

                    // The bridge to the new photo-review feature: when the
                    // verdict is anything but a clean halal, let the user ask a human.
                    if verdict.overall != .halal {
                        reviewPrompt
                    }
                }
                .padding()
            }
            .navigationTitle("Verdict")
            .sheet(isPresented: $showReviewRequest) {
                RequestReviewView(prefillName: verdict.product.name,
                                  prefillBarcode: verdict.product.id)
            }
        }
    }

    private func flaggedRow(_ item: MatchedIngredient) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(item.displayName).font(.body.weight(.semibold))
                Spacer()
                VerdictBadge(verdict: item.verdict).font(.caption)
            }
            Text(item.explanation)
                .font(.callout)
                .foregroundStyle(.secondary)
            if let source = item.source {
                Link(destination: URL(string: source.url) ?? URL(string: "https://haliable.app")!) {
                    Label("\(source.body) · \(source.title) (\(source.year))",
                          systemImage: "book.closed")
                        .font(.caption)
                }
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private var reviewPrompt: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Not sure? Ask a human.")
                .font(.headline)
            Text("Send us photos of the product and ingredient list for a manual halal review.")
                .font(.callout).foregroundStyle(.secondary)
            Button {
                showReviewRequest = true
            } label: {
                Label("Request manual review", systemImage: "camera.viewfinder")
                    .frame(maxWidth: .infinity).padding(.vertical, 6)
            }
            .buttonStyle(.borderedProminent)
        }
        .padding(.top, 8)
    }
}

#Preview {
    let fakeProduct = Product(
        id: "0049000028911",
        name: "Diet Coke",
        brand: "Coca-Cola",
        rawIngredientsText: "Carbonated water, caramel color, natural flavors, aspartame",
        additivesENumbers: ["E150D", "E951"]
    )
    let fakeMatched = [
        MatchedIngredient(originalText: "natural flavors", matchedRule: nil),
        MatchedIngredient(originalText: "E150D (caramel color)", matchedRule: nil)
    ]
    return VerdictView(verdict: ProductVerdict(product: fakeProduct, matched: fakeMatched, overall: .doubtful))
}
