//
//  AboutV2.swift
//  Haliable
//
//  About / methodology, on the Guard background and header (board style).
//

import SwiftUI

struct AboutV2: View {
    var body: some View {
        NavigationStack {
            ZStack {
                GuardBackground()
                ScrollView {
                    VStack(alignment: .leading, spacing: DSSpacing.lg) {
                        GuardIDRow(title: "About", subtitle: "How Haliable works") { EmptyView() }
                        section("How verdicts work") {
                            VStack(alignment: .leading, spacing: DSSpacing.md) {
                                verdictRow(.halal, "Halal",
                                           "No prohibited or questionable ingredients matched our verified rules.")
                                divider
                                verdictRow(.doubtful, "Questionable",
                                           "An ingredient's source couldn't be confirmed (e.g. natural flavors, unsourced gelatin, ambiguous E-numbers). We explain why instead of guessing.")
                                divider
                                verdictRow(.haram, "Haram",
                                           "Contains an ingredient that is not permissible, such as pork or wine.")
                            }
                        }

                        section("Our safety stance") {
                            stance
                        }

                        section("Standards referenced") {
                            VStack(alignment: .leading, spacing: DSSpacing.sm) {
                                // The bodies Citations.json actually cites most (AMJA was listed but never cited).
                                chips(["SANHA", "AHF", "IFANCA", "MUIS", "HMC", "JAKIM", "ISNA", "Darul Ifta fatwas"])
                                paragraph("Each ingredient verdict cites the body behind it. Citations should be independently verified before relying on them.")
                            }
                        }

                        section("Privacy") {
                            paragraph("The scanner runs on your device. Barcodes are only sent to the anonymous Open Food Facts / USDA lookups, and the Find map's Connecticut places ship inside the app, so your location never leaves your phone. Sign-in (Apple) is required only to submit a manual review or a store — never to scan.")
                        }
                    }
                    .padding(.horizontal, DSSpacing.screen)
                    .padding(.top, DSSpacing.xs)
                    .padding(.bottom, DSSpacing.xl)
                }
                .scrollIndicators(.hidden)
            }
            .toolbar(.hidden, for: .navigationBar)
        }
    }

    // MARK: - Building blocks

    private func section<C: View>(_ label: String, @ViewBuilder _ content: () -> C) -> some View {
        VStack(alignment: .leading, spacing: DSSpacing.sm) {
            SectionLabel(label)
            content()
                .frame(maxWidth: .infinity, alignment: .leading)
                .glassCard()
        }
    }

    private func verdictRow(_ verdict: Verdict, _ title: String, _ body: String) -> some View {
        HStack(alignment: .top, spacing: DSSpacing.sm) {
            Image(systemName: verdict.symbolName)
                .font(.title3)
                .foregroundStyle(verdict.tint)
                .frame(width: 28)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: DSSpacing.xxs) {
                Text(title)
                    .font(DSFont.headline)
                    .foregroundStyle(verdict.tint)
                    .lineLimit(1).minimumScaleFactor(0.5)   // "Questionabl" at accessibility sizes
                Text(body)
                    .font(DSFont.body)
                    .foregroundStyle(DSColor.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private func paragraph(_ text: String) -> some View {
        Text(text)
            .font(DSFont.body)
            .foregroundStyle(DSColor.textSecondary)
            .fixedSize(horizontal: false, vertical: true)
    }

    /// The editorial safety promise — italic serif with the key word in amber.
    private var stance: some View {
        ObliqueText(runs: [
            .italic("A false “Halal” is the worst error we can make — so anything we cannot positively confirm, including a product with no ingredient data, is shown as ", size: 19, color: "TextPrimary"),
            .italic("Questionable", size: 19, color: "Warning"),
            .italic(", never assumed halal.", size: 19, color: "TextPrimary"),
        ], lineSpacing: 4)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// Standards-body chips, wrapped onto as many lines as they need. (A
    /// horizontal rail with clipping disabled let chips slide out of the card.)
    private func chips(_ items: [String]) -> some View {
        WrapLayout(spacing: DSSpacing.xs) {
                ForEach(items, id: \.self) { item in
                    Text(item)
                        .font(DSFont.caption)
                        .foregroundStyle(DSColor.textSecondary)
                        .padding(.horizontal, DSSpacing.sm + 2)
                        .padding(.vertical, DSSpacing.xs)
                        .background(DSColor.surfaceElevated, in: Capsule())
                        .overlay(Capsule().strokeBorder(DSColor.outline, lineWidth: 1))
                }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var divider: some View {
        Rectangle()
            .fill(DSColor.outline.opacity(0.5))
            .frame(height: 1)
    }
}

/// Lays children out left to right, starting a new line when the next one won't fit.
private struct WrapLayout: Layout {
    var spacing: CGFloat

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let rows = rows(width: proposal.width ?? .infinity, subviews)
        let height = rows.map(\.height).reduce(0, +) + spacing * CGFloat(max(rows.count - 1, 0))
        return CGSize(width: proposal.width ?? rows.map(\.width).max() ?? 0, height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var y = bounds.minY
        for row in rows(width: bounds.width, subviews) {
            var x = bounds.minX
            for i in row.items {
                let size = subviews[i].sizeThatFits(.unspecified)
                subviews[i].place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
                x += size.width + spacing
            }
            y += row.height + spacing
        }
    }

    private func rows(width: CGFloat, _ subviews: Subviews) -> [(items: [Int], width: CGFloat, height: CGFloat)] {
        var rows: [(items: [Int], width: CGFloat, height: CGFloat)] = []
        for (i, view) in subviews.enumerated() {
            let size = view.sizeThatFits(.unspecified)
            if let last = rows.last, last.width + spacing + size.width <= width {
                rows[rows.count - 1] = (last.items + [i], last.width + spacing + size.width, max(last.height, size.height))
            } else {
                rows.append(([i], size.width, size.height))
            }
        }
        return rows
    }
}

#Preview {
    AboutV2().preferredColorScheme(.dark)
}
