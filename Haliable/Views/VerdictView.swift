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
    @State private var expanded: Set<UUID> = []

    init(verdict: ProductVerdict) {
        self.initialVerdict = verdict
        _live = State(initialValue: verdict)
    }

    var body: some View {
        @Bindable var settings = settings
        return ScrollView {
            VStack(alignment: .leading, spacing: DSSpacing.sm) {
                verdictTop
                    .padding(.top, DSSpacing.lg)
                    .reveal()

                // A draft driving cell is never shown as an authoritative ruling.
                if live.overallNeedsReview {
                    PendingReviewBanner(draftGrade: live.overallGrade)
                        .id(live.overallGrade)
                        .transition(.opacity)
                }

                standardChips
                    .reveal(0.08)

                CertificationStatusView(product: live.product,
                                        standard: settings.halalStandard)
                    .animation(.easeInOut(duration: 0.25), value: settings.halalStandard)

                GuardSection(title: "Flagged",
                             trailing: live.flagged.isEmpty ? nil : "\(live.flagged.count) of \(live.matched.count) checked")
                    .padding(.top, DSSpacing.xs)

                if live.flagged.isEmpty {
                    EmptyStateView(
                        symbol: "checkmark.circle",
                        title: "Nothing flagged",
                        message: "No prohibited or questionable ingredients matched our verified rules."
                    )
                } else {
                    ForEach(Array(live.flagged.enumerated()), id: \.element.id) { i, item in
                        flaggedRow(item).reveal(0.16 + Double(min(i, 6)) * 0.05)
                    }
                }

                if live.overall != .halal {
                    GuardAction(symbol: "pencil.line",
                                title: "Ask a scholar",
                                subtitle: "We research the label and send you the sources.") {
                        showReviewRequest = true
                    }
                    .padding(.top, DSSpacing.xxs)
                }

                // Standing disclosure (Spec §A3) — on every verdict surface.
                standingDisclosure
                    .padding(.top, DSSpacing.xs)
            }
            .padding(.horizontal, DSSpacing.screen)
            .padding(.bottom, DSSpacing.xl)
            .animation(.easeInOut(duration: 0.3), value: live.overall)
        }
        .background(DSColor.surface)
        .presentationDragIndicator(.visible)
        .presentationCornerRadius(30)
        .presentationBackground(DSColor.surface)
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

    /// Ring, grade, product, and how many of the checked ingredients flagged.
    private var verdictTop: some View {
        HStack(spacing: DSSpacing.sm) {
            FlaggedRing(flagged: live.flagged.count,
                        checked: live.matched.count,
                        tint: live.overall.tint,
                        diameter: 66)
                .background(PulseRings(color: live.overall.tint, diameter: 66, repeats: false))
            VStack(alignment: .leading, spacing: 2) {
                // A draft driving cell never gets a confident headline (§A3);
                // the PendingReviewBanner below carries the draft grade.
                Text(live.overallNeedsReview ? "Pending review" : live.overall.displayName)
                    .font(.custom("Spectral-Medium", size: 27, relativeTo: .title))
                    .tracking(-0.6)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                    .foregroundStyle(live.overallNeedsReview ? DSColor.warning : live.overall.tint)
                    .id(live.overall)
                    .transition(.opacity)
                Text([live.product.name, live.product.brand].compactMap { $0 }.joined(separator: " · "))
                    .font(.system(size: 13))
                    .foregroundStyle(DSColor.textSecondary)
                    .lineLimit(1)
                Text(live.flagged.isEmpty
                     ? "Nothing flagged · \(settings.halalStandard.displayName)"
                     : "\(live.flagged.count) flagged · \(settings.halalStandard.displayName)")
                    .font(.system(size: 11))
                    .foregroundStyle(DSColor.textTertiary)
                if !live.overallNeedsReview {
                    GradeBadge(grade: live.overallGrade, pendingReview: false)
                        .id(live.overallGrade)
                        .transition(.opacity)
                        .padding(.top, 4)
                }
            }
            Spacer(minLength: 0)
        }
        .animation(DSMotion.arrive, value: live.overallGrade)
        .accessibilityElement(children: .combine)
    }

    /// Who said so, in one line — or the honest "awaiting citation".
    private func sourceLine(_ item: MatchedIngredient) -> String {
        let base: String
        if let c = item.citations.first {
            base = "\(c.sourceName) · \(c.date.prefix(4))"
        } else if let src = item.source {
            base = "\(src.body) · \(src.year)"
        } else {
            base = "awaiting citation"
        }
        return item.needsReview && !item.citations.isEmpty ? base + " · draft" : base
    }

    private func flaggedRow(_ item: MatchedIngredient) -> some View {
        let open = expanded.contains(item.id)
        return VStack(alignment: .leading, spacing: DSSpacing.xs) {
            GuardRow(symbol: item.grade.symbolName,
                     tint: item.grade.tint,
                     title: item.displayName,
                     subtitle: sourceLine(item)) {
                withAnimation(DSMotion.move) {
                    if open { expanded.remove(item.id) } else { expanded.insert(item.id) }
                }
            }
            if open {
                VStack(alignment: .leading, spacing: DSSpacing.xs) {
                    HStack(spacing: DSSpacing.xs) {
                        GradeBadge(grade: item.grade, pendingReview: item.needsReview)
                        if item.needsReview { DraftTag() }
                    }
                    Text(item.explanation)
                        .font(.system(size: 13.5))
                        .foregroundStyle(DSColor.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                    if !item.citations.isEmpty { citationsBlock(item) }
                    if let source = item.source {
                        Link(destination: URL(string: source.url) ?? URL(string: "https://haliable.netlify.app")!) {
                            Label("\(source.body) · \(source.title) (\(source.year))",
                                  systemImage: "book.closed")
                                .font(DSFont.caption)
                                .foregroundStyle(DSColor.accent)
                        }
                    }
                }
                .padding(DSSpacing.sm)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(DSColor.surfaceElevated, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
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
