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
    @Query(sort: \ScanRecord.scannedAt, order: .reverse) private var history: [ScanRecord]

    @State private var showSettings = false
    @State private var showStandardSheet = false

    private var needsAttention: [ScanRecord] {
        Array(history.filter { $0.overallVerdict != .halal }.prefix(2))
    }
    private var awaitingCount: Int {
        reviews.requests.filter { $0.status != .completed }.count
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

                    RingEmblem()
                        .padding(.top, DSSpacing.xs)

                    headline
                        .padding(.top, DSSpacing.xxs)
                        .padding(.bottom, DSSpacing.md)

                    GuardAction(symbol: "barcode.viewfinder",
                                title: "Start a halal scan",
                                subtitle: "Check a label before it goes in the basket.") {
                        onScan(nil)
                    }
                    .accessibilityIdentifier("home.startScan")

                    attention
                        .padding(.top, DSSpacing.md)
                }
                .padding(.horizontal, DSSpacing.screen)
                .padding(.top, DSSpacing.xs)
                .padding(.bottom, DSSpacing.lg)
            }
            .scrollIndicators(.hidden)
        }
        .sheet(isPresented: $showSettings) { SettingsV2() }
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
        if !needsAttention.isEmpty || awaitingCount > 0 {
            VStack(spacing: 10) {
                GuardSection(title: "Needs attention", trailing: "See all", action: onSeeHistory)
                ForEach(needsAttention) { rec in scanRow(rec) }
                if awaitingCount > 0 {
                    GuardRow(symbol: "clock",
                             tint: DSColor.textPrimary,
                             title: awaitingCount == 1 ? "1 awaiting a scholar" : "\(awaitingCount) awaiting a scholar",
                             subtitle: "Review requests in progress",
                             action: onSeeReviews)
                }
            }
        } else if !history.isEmpty {
            VStack(spacing: 10) {
                GuardSection(title: "Recently checked", trailing: "See all", action: onSeeHistory)
                ForEach(history.prefix(3)) { rec in scanRow(rec) }
            }
        } else {
            GuardRow(symbol: "sparkles",
                     tint: DSColor.accent,
                     title: "Nothing needs you yet",
                     subtitle: "Scans that aren't clearly halal show up here.",
                     showsArrow: false)
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
