//
//  HistoryV2.swift
//  Haliable
//
//  Board screen 8 — History, grouped by day, each row carrying the standard it
//  was graded under (scans saved before Oct 16, 2026 have none and just show the
//  time). Swipe to delete is kept. Tapping a row re-checks that product under the
//  CURRENT standard rather than replaying a stale verdict.
//

import SwiftUI
import SwiftData

struct HistoryV2: View {
    /// Re-check a product (opens the scanner on that barcode).
    var onOpen: (String) -> Void = { _ in }

    @Query(sort: \ScanRecord.scannedAt, order: .reverse) private var records: [ScanRecord]
    @Environment(\.modelContext) private var modelContext
    @State private var filter: Verdict? = nil

    private var weekRecords: [ScanRecord] {
        let start = Calendar.current.date(byAdding: .day, value: -7, to: .now) ?? .now
        return records.filter { $0.scannedAt >= start }
    }

    private var filtered: [ScanRecord] {
        guard let filter else { return records }
        return records.filter { $0.overallVerdict == filter }
    }

    /// (heading, rows) per calendar day, newest first.
    private var days: [(String, [ScanRecord])] {
        let cal = Calendar.current
        let groups = Dictionary(grouping: filtered) { cal.startOfDay(for: $0.scannedAt) }
        return groups.keys.sorted(by: >).map { day in
            let title: String
            if cal.isDateInToday(day) { title = "Today" }
            else if cal.isDateInYesterday(day) { title = "Yesterday" }
            else { title = day.formatted(.dateTime.weekday(.wide).month().day()) }
            return (title, groups[day] ?? [])
        }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                GuardBackground()
                List {
                    Group {
                        GuardIDRow(title: "History",
                                   subtitle: weekRecords.count == 1 ? "1 this week" : "\(weekRecords.count) this week") {
                            EmptyView()
                        }
                        if records.isEmpty {
                            GuardRow(symbol: "barcode.viewfinder", tint: DSColor.accent,
                                     title: "No scans yet",
                                     subtitle: "Scan a product — it shows up here with its verdict.",
                                     showsArrow: false)
                                .padding(.top, DSSpacing.md)
                        } else {
                            GuardAction(symbol: "checkmark.circle", title: weekSummary,
                                        subtitle: "Your last 7 days.", action: nil)
                                .padding(.top, DSSpacing.xs)
                            GuardSegments(options: [(nil, "All"), (Verdict.halal, "Halal"),
                                                    (.doubtful, "Questionable"), (.haram, "Haram")],
                                          selection: $filter)
                                .padding(.top, DSSpacing.xxs)
                        }
                    }
                    .guardListRow()

                    ForEach(days, id: \.0) { title, rows in
                        GuardSection(title: title)
                            .padding(.top, DSSpacing.xs)
                            .guardListRow()
                        ForEach(rows) { rec in
                            row(rec).guardListRow()
                        }
                        .onDelete { offsets in delete(offsets.map { rows[$0] }) }
                    }
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
                .scrollIndicators(.hidden)
            }
            .toolbar(.hidden, for: .navigationBar)
        }
    }

    private var weekSummary: String {
        let c = { (v: Verdict) in weekRecords.filter { $0.overallVerdict == v }.count }
        return "\(c(.halal)) halal · \(c(.doubtful)) questionable · \(c(.haram)) haram"
    }

    private func row(_ rec: ScanRecord) -> some View {
        let when = rec.scannedAt.formatted(.relative(presentation: .named))
        return GuardRow(symbol: rec.overallVerdict.rowSymbol,
                        tint: rec.overallVerdict.tint,
                        title: rec.productName,
                        subtitle: [rec.standard?.displayName, when].compactMap { $0 }.joined(separator: " · ")) {
            onOpen(rec.barcode)
        }
        .accessibilityHint("Re-checks this product. Swipe left to delete.")
    }

    private func delete(_ items: [ScanRecord]) {
        for item in items { modelContext.delete(item) }
        try? modelContext.save()
    }
}

private extension View {
    func guardListRow() -> some View {
        listRowBackground(Color.clear)
            .listRowSeparator(.hidden)
            .listRowInsets(EdgeInsets(top: 5, leading: DSSpacing.md, bottom: 5, trailing: DSSpacing.md))
    }
}

#Preview {
    HistoryV2()
        .modelContainer(for: ScanRecord.self, inMemory: true)
}
