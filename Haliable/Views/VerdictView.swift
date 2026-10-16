//
//  VerdictView.swift
//  Haliable
//
//  Created by Omar O on 6/3/26.
//

import SwiftUI

struct VerdictView: View {
    /// The verdict as first computed (carries the Product we re-evaluate from).
    let initialVerdict: ProductVerdict

    @Environment(RulesEngine.self) private var engine
    @Environment(AppSettings.self) private var settings

    /// The live verdict shown — recomputed when the active standard changes so
    /// the user can see, in place, that their standard actually moves the needle.
    @State private var live: ProductVerdict
    @State private var showReviewRequest = false
    @State private var showStandardSheet = false

    init(verdict: ProductVerdict) {
        self.initialVerdict = verdict
        _live = State(initialValue: verdict)
    }

    var body: some View {
        @Bindable var settings = settings
        return NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: DSSpacing.md) {
                    headerSection
                        .padding(.top)

                    clearedHeader
                    standardChips

                    // Standing disclosure (Spec §A3) — persistent on every verdict
                    // surface so "report, don't rule" stays true to the user.
                    standingDisclosure

                    Text(live.product.name)
                        .font(DSFont.title)
                        .foregroundStyle(DSColor.textPrimary)
                    if let brand = live.product.brand {
                        Text(brand).font(DSFont.body).foregroundStyle(DSColor.textSecondary)
                    }

                    Text(live.summary)
                        .font(DSFont.body)
                        .foregroundStyle(DSColor.textSecondary)
                        .id(live.overall)                // crossfade the summary too
                        .transition(.opacity)

                    // How this product's certification compares to the active
                    // standard (renders nothing when there's no cert signal).
                    CertificationStatusView(product: live.product,
                                            standard: settings.halalStandard)
                        .animation(.easeInOut(duration: 0.25), value: settings.halalStandard)

                    Divider()

                    Text("What we flagged")
                        .font(DSFont.headline)
                        .foregroundStyle(DSColor.textPrimary)

                    if live.flagged.isEmpty {
                        EmptyStateView(
                            symbol: "checkmark.circle",
                            title: "Nothing flagged",
                            message: "No prohibited or questionable ingredients matched our verified rules."
                        )
                    } else {
                        ForEach(live.flagged) { item in
                            flaggedRow(item)
                        }
                    }

                    // The bridge to the new photo-review feature: when the
                    // verdict is anything but a clean halal, let the user ask a human.
                    if live.overall != .halal {
                        reviewPrompt
                    }
                }
                .padding()
                .animation(.easeInOut(duration: 0.3), value: live.overall)
            }
            .navigationTitle("Verdict")
            .onChange(of: settings.halalStandard) { _, newStandard in
                withAnimation(.easeInOut(duration: 0.3)) {
                    live = engine.evaluate(product: initialVerdict.product, standard: newStandard)
                }
            }
            .sheet(isPresented: $showReviewRequest) {
                RequestReviewView(prefillName: live.product.name,
                                  prefillBarcode: live.product.id)
            }
            .sheet(isPresented: $showStandardSheet) {
                StandardSelectorSheet(
                    selected: $settings.halalStandard,
                    onCommit: { _ in settings.hasChosenStandard = true }
                )
            }
        }
    }

    private func flaggedRow(_ item: MatchedIngredient) -> some View {
        VStack(alignment: .leading, spacing: DSSpacing.xs) {
            HStack(spacing: DSSpacing.xs) {
                Text(item.displayName)
                    .font(DSFont.body.weight(.semibold))
                    .foregroundStyle(DSColor.textPrimary)
                if item.needsReview { DraftTag() }
                Spacer()
                GradeBadge(grade: item.grade, pendingReview: item.needsReview)
            }
            Text(item.explanation)
                .font(DSFont.body)
                .foregroundStyle(DSColor.textSecondary)

            // Reported, cited positions (Spec §B). A contested cell carries more
            // than one — we show BOTH rather than forcing a pick (Spec §A2).
            if !item.citations.isEmpty {
                citationsBlock(item)
            }

            if let source = item.source {
                Link(destination: URL(string: source.url) ?? URL(string: "https://haliable.netlify.app")!) {
                    Label("\(source.body) · \(source.title) (\(source.year))",
                          systemImage: "book.closed")
                        .font(DSFont.caption)
                        .foregroundStyle(DSColor.accent)
                }
            }
        }
        .cardStyle()
    }

    /// Renders each published, cited position for a cell. For a contested cell
    /// this is two or more conflicting sources, shown side by side.
    private func citationsBlock(_ item: MatchedIngredient) -> some View {
        VStack(alignment: .leading, spacing: DSSpacing.xs) {
            HStack(spacing: DSSpacing.xxs) {
                Image(systemName: "text.book.closed")
                    .font(DSFont.caption)
                    .foregroundStyle(DSColor.accent)
                    .accessibilityHidden(true)
                Text(item.isContested ? "Sources disagree — both positions reported"
                                      : "Reported from published sources")
                    .font(DSFont.caption.weight(.semibold))
                    .foregroundStyle(DSColor.textSecondary)
            }
            ForEach(item.citations.indices, id: \.self) { i in
                let c = item.citations[i]
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: DSSpacing.xxs) {
                        StatusBadge(text: c.tier.shortLabel, tint: DSColor.accent)
                        Text(c.sourceName)
                            .font(DSFont.caption.weight(.semibold))
                            .foregroundStyle(DSColor.textPrimary)
                    }
                    if !c.paraphrase.isEmpty {
                        Text(c.paraphrase)
                            .font(DSFont.caption)
                            .foregroundStyle(DSColor.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    citationReference(c)
                }
            }
        }
        .padding(DSSpacing.sm)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(DSColor.accent.opacity(0.06),
                    in: RoundedRectangle(cornerRadius: DSRadius.md, style: .continuous))
    }

    /// The reference is a tappable link when it's a web URL, else plain text
    /// (a document + clause/page reference the user can look up).
    @ViewBuilder private func citationReference(_ c: Citation) -> some View {
        if let url = URL(string: c.reference), url.scheme == "http" || url.scheme == "https" {
            Link(destination: url) {
                Label("\(c.reference) · \(c.date)", systemImage: "link")
                    .font(DSFont.caption)
                    .foregroundStyle(DSColor.accent)
                    .lineLimit(1)
            }
        } else {
            Label("\(c.reference) · \(c.date)", systemImage: "doc.text")
                .font(DSFont.caption)
                .foregroundStyle(DSColor.textSecondary)
        }
    }

    /// The persistent standing disclosure line (Spec §A3).
    private var standingDisclosure: some View {
        HStack(alignment: .top, spacing: DSSpacing.xxs) {
            Image(systemName: "info.circle")
                .font(DSFont.caption)
                .foregroundStyle(DSColor.textSecondary)
                .accessibilityHidden(true)
            Text(HaliableDisclosure.standing)
                .font(DSFont.caption)
                .foregroundStyle(DSColor.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }

    /// The headline verdict. When the driving cell is still a DRAFT
    /// (`overallNeedsReview`), the confident `GradeBadge` is REPLACED by the
    /// unmistakable `PendingReviewBanner` — never shown as an authoritative
    /// ruling. Otherwise the confident badge sits beside the standard pill.
    @ViewBuilder private var headerSection: some View {
        if live.overallNeedsReview {
            HStack(alignment: .center) {
                Spacer()
                StandardPill(standard: settings.halalStandard) {
                    showStandardSheet = true
                }
            }
            PendingReviewBanner(draftGrade: live.overallGrade)
                .id(live.overallGrade)                  // re-id ⇒ crossfade on change
                .transition(.opacity)
        } else {
            HStack(alignment: .center) {
                GradeBadge(grade: live.overallGrade, pendingReview: false)
                    .id(live.overallGrade)              // re-id ⇒ crossfade on change
                    .transition(.opacity)
                Spacer()
                StandardPill(standard: settings.halalStandard) {
                    showStandardSheet = true
                }
            }
        }
    }

    /// How much of the label actually cleared. A product with two flags out of
    /// eighteen ingredients is mostly fine; a bare red badge says otherwise and
    /// is the less honest of the two.
    private var clearedHeader: some View {
        HStack(spacing: DSSpacing.sm) {
            FlaggedRing(flagged: live.flagged.count,
                        checked: live.matched.count,
                        tint: live.overall.tint)
            VStack(alignment: .leading, spacing: 1) {
                Text(live.overall.displayName)
                    .font(DSFont.title)
                    .foregroundStyle(live.overall.tint)
                Text(live.flagged.isEmpty
                     ? "Nothing flagged · \(settings.halalStandard.displayName)"
                     : "from \(live.matched.count) checked · \(settings.halalStandard.displayName)")
                    .font(DSFont.caption)
                    .foregroundStyle(DSColor.textSecondary)
            }
            Spacer(minLength: 0)
        }
        .animation(DSMotion.arrive, value: live.overallGrade)
        .accessibilityElement(children: .combine)
    }

    /// All four standards on screen. The whole point of this app is that the
    /// verdict moves with the standard, and that was previously buried behind a
    /// sheet — so it may as well have been invisible.
    private var standardChips: some View {
        @Bindable var settings = settings
        return HStack(spacing: 5) {
            ForEach(HalalStandard.allCases.sorted { $0.strictnessRank > $1.strictnessRank }) { std in
                let active = std == settings.halalStandard
                Button {
                    withAnimation(DSMotion.move) {
                        settings.halalStandard = std
                        settings.hasChosenStandard = true
                    }
                } label: {
                    Text(std.displayName)
                        .font(.system(size: 11, weight: .semibold))
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(
                            active
                            ? AnyShapeStyle(LinearGradient(colors: [DSColor.accent, DSColor.accentGradientEnd],
                                                           startPoint: .topLeading,
                                                           endPoint: .bottomTrailing))
                            : AnyShapeStyle(DSColor.surface),
                            in: Capsule()
                        )
                        .overlay(Capsule().strokeBorder(active ? .clear : DSColor.outline, lineWidth: 1))
                        .foregroundStyle(active ? DSColor.onAccent : DSColor.textSecondary)
                }
                .pressable()
                .accessibilityLabel(std.displayName)
                .accessibilityAddTraits(active ? [.isSelected] : [])
            }
        }
    }

    private var reviewPrompt: some View {
        VStack(alignment: .leading, spacing: DSSpacing.xs) {
            Text("Not sure? Ask a human.")
                .font(DSFont.headline)
                .foregroundStyle(DSColor.textPrimary)
            Text("Send us photos of the product and ingredient list for a manual halal review.")
                .font(DSFont.body)
                .foregroundStyle(DSColor.textSecondary)
            PrimaryButton(title: "Request manual review", systemImage: "camera.viewfinder") {
                showReviewRequest = true
            }
            .padding(.top, DSSpacing.xxs)
        }
        .padding(.top, DSSpacing.xs)
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
    return VerdictView(verdict: ProductVerdict(product: fakeProduct, matched: fakeMatched, overallGrade: .mashboohContested))
        .environment(RulesEngine())
        .environment(AppSettings())
}
