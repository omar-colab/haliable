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
                                chips(["IFANCA", "ISNA", "AMJA", "HMC", "JAKIM"])
                                paragraph("Each ingredient verdict cites the body behind it. Citations should be independently verified before relying on them.")
                            }
                        }

                        section("Privacy") {
                            paragraph("The scanner runs on your device. Barcodes are only sent to the anonymous Open Food Facts / USDA lookups. Sign-in (Apple) is required only to submit a manual review or a store — never to scan.")
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

    /// A soft rail of standards-body chips.
    private func chips(_ items: [String]) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: DSSpacing.xs) {
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
            .padding(.vertical, 1)
        }
        .scrollClipDisabled()
    }

    private var divider: some View {
        Rectangle()
            .fill(DSColor.outline.opacity(0.5))
            .frame(height: 1)
    }
}

#Preview {
    AboutV2().preferredColorScheme(.dark)
}
