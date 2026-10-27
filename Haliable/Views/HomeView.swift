//
//  HomeView.swift
//  Haliable
//
//  Board screen 1. No live camera here on purpose: the board's Home is a
//  dashboard, and scanning is its own full-screen view (ScanSessionView). That
//  is what lets the emblem and headline fit — the earlier attempt stacked them
//  on a 396pt viewfinder and pushed the scan button below the fold.
//
//  "Needs attention" is built only from what the app actually holds: saved scans
//  that weren't halal, and review requests still waiting on a human.
//

import SwiftUI
import SwiftData

struct HomeView: View {
    /// Opens the scanner; a barcode re-checks that product under the current standard.
    var onScan: (String?) -> Void
    var onSeeHistory: () -> Void
    var onSeeReviews: () -> Void

    @Environment(AppSettings.self) private var settings
    @Environment(AuthManager.self) private var auth
    @Environment(ReviewStore.self) private var reviews
    @Environment(RulesEngine.self) private var engine
    @Query(sort: \ScanRecord.scannedAt, order: .reverse) private var history: [ScanRecord]

    @State private var showSettings = false
    @State private var showStandardSheet = false
    @State private var showChecker = false
    @State private var checked: ProductVerdict?
    @State private var checkedText: String?

    private var needsAttention: [ScanRecord] {
        Array(history.filter { $0.overallVerdict != .halal }.prefix(2))
    }
    private var awaitingCount: Int {
        reviews.requests.filter { $0.status != .completed }.count
    }
    /// When the Reviews tab was last opened; answers newer than that are news.
    @AppStorage("reviewsSeenAt") private var reviewsSeenAt: Double = 0
    private var answeredCount: Int {
        reviews.requests.filter {
            $0.status == .completed && ($0.reviewedAt?.timeIntervalSince1970 ?? 0) > reviewsSeenAt
        }.count
    }

    var body: some View {
        @Bindable var settings = settings
        return ZStack {
            GuardBackground()

            ScrollView {
                VStack(spacing: 0) {
                    idRow
                    HStack {
                        StandardPill(standard: settings.halalStandard) { showStandardSheet = true }
                        Spacer(minLength: 0)
                    }
                    .padding(.top, DSSpacing.sm)
                    .reveal()

                    RingEmblem()
                        .padding(.top, DSSpacing.xs)
                        .reveal(0.05)

                    headline
                        .padding(.top, DSSpacing.xxs)
                        .padding(.bottom, DSSpacing.md)
                        .reveal(0.1)

                    GuardAction(symbol: "barcode.viewfinder",
                                title: "Start a halal scan",
                                subtitle: "Check a label before it goes in the basket.") {
                        onScan(nil)
                    }
                    .accessibilityIdentifier("home.startScan")
                    .reveal(0.15)

                    GuardAction(symbol: "text.viewfinder",
                                title: "Check ingredients",
                                subtitle: "Type, paste or read a label — no barcode needed.") {
                        showChecker = true
                    }
                    .accessibilityIdentifier("home.checkIngredients")
                    .padding(.top, DSSpacing.xs)
                    .reveal(0.18)

                    attention
                        .padding(.top, DSSpacing.md)
                        .reveal(0.22)
                }
                .padding(.horizontal, DSSpacing.screen)
                .padding(.top, DSSpacing.xs)
                .padding(.bottom, DSSpacing.lg)
            }
            .scrollIndicators(.hidden)
        }
        .sheet(isPresented: $showSettings) { SettingsV2() }
        // The result opens once the checker has fully closed; two sheets
        // swapping in one frame can drop the second.
        .sheet(isPresented: $showChecker, onDismiss: {
            if let text = checkedText {
                checkedText = nil
                checked = engine.evaluate(product: LabelScanView.product(text), standard: settings.halalStandard)
            }
        }) {
            LabelScanView { checkedText = $0 }
        }
        .sheet(item: $checked) { VerdictView(verdict: $0) }
        .sheet(isPresented: $showStandardSheet) {
            StandardSelectorSheet(selected: $settings.halalStandard,
                                  onCommit: { _ in settings.hasChosenStandard = true })
        }
    }

    // MARK: - Pieces

    private var idRow: some View {
        GuardIDRow(title: auth.givenName ?? "Welcome",
                   subtitle: auth.givenName == nil ? "Haliable" : "Welcome") {
            RingButton(symbol: "gearshape", label: "Settings") { showSettings = true }
        }
    }

    private var headline: some View {
        VStack(spacing: 2) {
            Text("Your personal")
            HStack(spacing: 8) {
                Text("halal guard")
                CrescentPill()
            }
        }
        .font(.system(size: 30, weight: .heavy))
        .tracking(-1.1)
        .foregroundStyle(DSColor.textPrimary)
        .multilineTextAlignment(.center)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Your personal halal guard")
        .accessibilityAddTraits(.isHeader)
    }

    @ViewBuilder private var attention: some View {
        if !needsAttention.isEmpty || awaitingCount > 0 || answeredCount > 0 {
            VStack(spacing: 10) {
                GuardSection(title: "Needs attention", trailing: "See all", action: onSeeHistory)
                if answeredCount > 0 {
                    GuardRow(symbol: "checkmark.bubble",
                             tint: DSColor.accent,
                             title: answeredCount == 1 ? "1 review answered" : "\(answeredCount) reviews answered",
                             subtitle: "Tap to read the sources",
                             action: onSeeReviews)
                }
                ForEach(needsAttention) { rec in scanRow(rec) }
                if awaitingCount > 0 {
                    GuardRow(symbol: "clock",
                             tint: DSColor.textPrimary,
                             title: awaitingCount == 1 ? "1 awaiting an answer" : "\(awaitingCount) awaiting an answer",
                             subtitle: "Review requests in progress",
                             thinking: true,
                             action: onSeeReviews)
                }
            }
        } else if !history.isEmpty {
            VStack(spacing: 10) {
                GuardSection(title: "Recently checked", trailing: "See all", action: onSeeHistory)
                ForEach(history.prefix(3)) { rec in scanRow(rec) }
            }
        } else {
            // First run: show how it works instead of empty space.
            VStack(spacing: 10) {
                GuardSection(title: "How it works")
                GuardRow(symbol: "barcode.viewfinder", tint: DSColor.accent,
                         title: "Scan the barcode",
                         subtitle: "We read the ingredient list for you.", showsArrow: false)
                GuardRow(symbol: "checklist", tint: DSColor.accent,
                         title: "Every ingredient is checked",
                         subtitle: "Against the standard you follow, with sources.", showsArrow: false)
                GuardRow(symbol: "text.book.closed", tint: DSColor.warning,
                         title: "Unsure? Ask for sources",
                         subtitle: "We research the label and send back what scholars wrote.", showsArrow: false)
            }
        }
    }

    private func scanRow(_ rec: ScanRecord) -> some View {
        let when = rec.scannedAt.formatted(.relative(presentation: .named))
        let detail = [rec.overallVerdict.displayName, rec.standard?.displayName, when]
            .compactMap { $0 }.joined(separator: " · ")
        return GuardRow(symbol: rec.overallVerdict.rowSymbol,
                        tint: rec.overallVerdict.tint,
                        title: rec.productName,
                        subtitle: detail) {
            onScan(rec.barcode)
        }
    }
}

extension Verdict {
    /// The outline symbol used in list rows (the filled seals are for badges).
    var rowSymbol: String {
        switch self {
        case .halal:    return "checkmark.circle"
        case .doubtful: return "questionmark.circle"
        case .haram:    return "xmark.circle"
        }
    }
}
