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

                        proTeaser

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

    // MARK: - Haliable Pro (coming soon)

    /// A teaser only — nothing is sold in the app. Every feature listed is one the
    /// current stack can grow into (review agent, certified-brands.json, OFF data,
    /// SwiftData). Scanning and verdicts stay free: safety is never paywalled.
    private static let proFeatures: [(String, String, String)] = [
        ("person.badge.clock", "Priority scholar reviews",
         "Unlimited requests, answered first — with the published source quoted in full."),
        ("menucard", "Menu scanner",
         "Photograph a restaurant menu and see which dishes to ask the staff about."),
        ("checkmark.seal", "Certificate check",
         "Scan a halal logo or certificate and see whether that certifier and brand are on file."),
        ("bell.badge", "Ingredient-change alerts",
         "Get notified when a product you buy changes its recipe."),
        ("person.3", "Family profiles",
         "A standard for everyone in the house — Zabiha for one, General for another."),
        ("icloud.and.arrow.down", "Offline mode",
         "The full ingredient library on your phone, for travel and dead zones."),
    ]

    private var proTeaser: some View {
        VStack(alignment: .leading, spacing: DSSpacing.md) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("COMING SOON")
                        .font(.system(size: 10.5, weight: .bold))
                        .tracking(1.4)
                        .foregroundStyle(DSColor.gold)
                    Text("Haliable Pro")
                        .font(.system(size: 26, weight: .heavy))
                        .tracking(-0.6)
                        .foregroundStyle(.white)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 0) {
                    Text("$10").font(.system(size: 24, weight: .heavy)).foregroundStyle(.white)
                    Text("per month").font(.system(size: 11)).foregroundStyle(.white.opacity(0.75))
                }
            }

            VStack(alignment: .leading, spacing: DSSpacing.sm) {
                ForEach(Self.proFeatures, id: \.1) { symbol, title, detail in
                    HStack(alignment: .top, spacing: DSSpacing.sm) {
                        Image(systemName: symbol)
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(DSColor.gold)
                            .frame(width: 34, height: 34)
                            .background(.white.opacity(0.14), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                            .accessibilityHidden(true)
                        VStack(alignment: .leading, spacing: 1) {
                            Text(title).font(.system(size: 15, weight: .semibold)).foregroundStyle(.white)
                            Text(detail)
                                .font(.system(size: 12.5))
                                .foregroundStyle(.white.opacity(0.8))
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    .accessibilityElement(children: .combine)
                }
            }

            Link(destination: URL(string: "https://haliable.netlify.app/#waitlist")!) {
                Text("Join the waitlist")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(DSColor.accentDeep)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 13)
                    .background(.white, in: Capsule())
            }
            .accessibilityHint("Opens the Haliable website")

            Text("Scanning and verdicts stay free, always. Nothing is charged today.")
                .font(.system(size: 11))
                .foregroundStyle(.white.opacity(0.7))
                .frame(maxWidth: .infinity, alignment: .center)
        }
        .padding(DSSpacing.md + 2)
        .background(
            LinearGradient(colors: [DSColor.accentDeep, DSColor.accent],
                           startPoint: .topLeading, endPoint: .bottomTrailing),
            in: RoundedRectangle(cornerRadius: 28, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 28, style: .continuous)
            .strokeBorder(DSColor.gold.opacity(0.45), lineWidth: 1))
        .shadow(color: DSColor.accent.opacity(0.3), radius: 18, y: 8)
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
