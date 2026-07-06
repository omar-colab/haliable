//
//  HistoryV2.swift
//  Haliable
//
//  Redesigned History on the shared AppScreen scaffold. Same data and logic as
//  HistoryView (live @Query of ScanRecord, swipe-to-delete) — re-skinned to
//  match the app's holistic dark look. Original HistoryView is untouched.
//
//  Preview swap: in RootTabView.swift, change `HistoryView()` to `HistoryV2()`.
//

import SwiftUI
import SwiftData

struct HistoryV2: View {
    @Query(sort: \ScanRecord.scannedAt, order: .reverse) private var records: [ScanRecord]
    @Environment(\.modelContext) private var modelContext
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        NavigationStack {
            AppScreen(eyebrow: "Your record", title: "History", trailing: {
                if !records.isEmpty {
                    EditButton()
                        .font(DSFont.caption)
                        .tint(DSColor.accentDeep)
                }
            }) {
                if records.isEmpty {
                    emptyState
                } else {
                    List {
                        summary
                            .listRowBackground(Color.clear)
                            .listRowSeparator(.hidden)
                            .listRowInsets(EdgeInsets(top: 0, leading: DSSpacing.lg,
                                                      bottom: DSSpacing.md, trailing: DSSpacing.lg))
                        ForEach(records) { record in
                            row(record)
                                .listRowBackground(Color.clear)
                                .listRowSeparator(.hidden)
                                .listRowInsets(EdgeInsets(top: DSSpacing.xs, leading: DSSpacing.lg,
                                                          bottom: DSSpacing.xs, trailing: DSSpacing.lg))
                        }
                        .onDelete(perform: delete)
                    }
                    .listStyle(.plain)
                    .scrollContentBackground(.hidden)
                    .scrollIndicators(.hidden)
                }
            }
        }
    }

    // MARK: - Summary (streak + stats), computed from real scans

    private var summary: some View {
        VStack(spacing: DSSpacing.sm) {
            streakCard
            HStack(spacing: DSSpacing.sm) {
                statTile(value: "\(records.count)", label: "Scanned", tint: DSColor.textPrimary)
                statTile(value: "\(halalPercent)%", label: "Halal", tint: DSColor.accentDeep)
                statTile(value: "\(flaggedCount)", label: "Flagged", tint: DSColor.warning)
            }
            SectionLabel("Recent")
                .padding(.top, DSSpacing.xs)
        }
    }

    private var streakCard: some View {
        let onGradient = scheme == .light
        return HStack(spacing: DSSpacing.md) {
            Text("\(streakDays)")
                .font(DSFont.serif(46, weight: .semibold))
                .foregroundStyle(onGradient ? DSColor.onAccent : DSColor.accent)
            ObliqueText(runs: [
                .italic(streakDays == 1
                 ? "day of mindful eating — keep checking before you buy."
                 : "days of mindful eating — keep checking before you buy.",
                 size: 15, color: onGradient ? "OnAccent" : "TextSecondary"),
            ], lineSpacing: 2)
            Spacer(minLength: 0)
        }
        .padding(.vertical, DSSpacing.md)
        .padding(.horizontal, DSSpacing.lg)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            if onGradient {
                LinearGradient(colors: [DSColor.accent, DSColor.accentDeep],
                               startPoint: .topLeading, endPoint: .bottomTrailing)
            } else {
                DSColor.surface
            }
        }
        .overlay(alignment: .topTrailing) {
            Circle()
                .strokeBorder((onGradient ? Color.white : DSColor.accent).opacity(0.14), lineWidth: 14)
                .frame(width: 130, height: 130)
                .offset(x: 30, y: -30)
                .accessibilityHidden(true)
        }
        .clipShape(RoundedRectangle(cornerRadius: DSRadius.md, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: DSRadius.md, style: .continuous)
                .strokeBorder(onGradient ? Color.clear : DSColor.accent.opacity(0.30), lineWidth: 1)
        )
        .shadow(color: DSColor.accent.opacity(onGradient ? 0.35 : 0.10), radius: 18, y: 10)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(streakDays) day streak of checking before you buy")
    }

    private func statTile(value: String, label: String, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: DSSpacing.xxs) {
            Text(value)
                .font(DSFont.serif(28, weight: .semibold))
                .foregroundStyle(tint)
            Text(label.uppercased())
                .font(DSFont.label)
                .tracking(0.6)
                .foregroundStyle(DSColor.textSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(DSSpacing.sm + 2)
        .background(DSColor.surface, in: RoundedRectangle(cornerRadius: DSRadius.sm, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: DSRadius.sm, style: .continuous)
            .strokeBorder(DSColor.outline, lineWidth: 1))
    }

    /// Consecutive calendar days (ending today or yesterday) with at least one scan.
    private var streakDays: Int {
        let cal = Calendar.current
        let days = Set(records.map { cal.startOfDay(for: $0.scannedAt) })
        guard !days.isEmpty else { return 0 }
        var cursor = cal.startOfDay(for: Date())
        if !days.contains(cursor) {
            guard let yesterday = cal.date(byAdding: .day, value: -1, to: cursor),
                  days.contains(yesterday) else { return 0 }
            cursor = yesterday
        }
        var streak = 0
        while days.contains(cursor) {
            streak += 1
            guard let prev = cal.date(byAdding: .day, value: -1, to: cursor) else { break }
            cursor = prev
        }
        return streak
    }

    private var halalPercent: Int {
        guard !records.isEmpty else { return 0 }
        let halal = records.filter { $0.overallVerdict == .halal }.count
        return Int((Double(halal) / Double(records.count) * 100).rounded())
    }

    private var flaggedCount: Int {
        records.filter { $0.overallVerdict != .halal }.count
    }

    private func row(_ record: ScanRecord) -> some View {
        HStack(spacing: DSSpacing.md) {
            ProductMonogram(text: record.productName, size: 46)
            VStack(alignment: .leading, spacing: DSSpacing.xxs) {
                Text(record.productName)
                    .font(DSFont.headline)
                    .foregroundStyle(DSColor.textPrimary)
                    .lineLimit(1)
                HStack(spacing: DSSpacing.xs) {
                    Text(record.barcode)
                    Text("·")
                    Text(record.scannedAt, format: .relative(presentation: .named))
                }
                .font(DSFont.caption)
                .foregroundStyle(DSColor.textTertiary)
                .lineLimit(1)
            }
            Spacer(minLength: 0)
            VerdictBadge(verdict: record.overallVerdict)
        }
        .glassCard()
        .accessibilityElement(children: .combine)
    }

    private var emptyState: some View {
        VStack(spacing: DSSpacing.md) {
            Spacer()
            Image("HMark")
                .renderingMode(.template)
                .resizable().scaledToFit()
                .frame(width: 64, height: 64)
                .foregroundStyle(DSColor.accent)
                .shadow(color: DSColor.accent.opacity(0.4), radius: 16)
                .accessibilityHidden(true)
            Text("No scans yet")
                .font(DSFont.title)
                .foregroundStyle(DSColor.textPrimary)
            Text("Scan your first product on the Scan tab — it'll show up here with its verdict.")
                .font(DSFont.body)
                .foregroundStyle(DSColor.textSecondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, DSSpacing.xl)
            Spacer()
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.horizontal, DSSpacing.lg)
    }

    private func delete(at offsets: IndexSet) {
        for index in offsets { modelContext.delete(records[index]) }
        try? modelContext.save()
    }
}

#Preview {
    HistoryV2()
        .modelContainer(for: ScanRecord.self, inMemory: true)
        .preferredColorScheme(.dark)
}
