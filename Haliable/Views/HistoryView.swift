//
//  HistoryView.swift
//  Haliable
//
//  Created by Omar O on 6/4/26.
//

import SwiftUI
import SwiftData

struct HistoryView: View {
    // SwiftData fetches and keeps this list live automatically.
    @Query(sort: \ScanRecord.scannedAt, order: .reverse) private var records: [ScanRecord]
    @Environment(\.modelContext) private var modelContext

    var body: some View {
        NavigationStack {
            List {
                ForEach(records) { record in
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(record.productName).font(.headline)
                            Text(record.barcode).font(.caption).foregroundStyle(.secondary)
                        }
                        Spacer()
                        VerdictBadge(verdict: record.overallVerdict).font(.caption)
                    }
                }
                .onDelete(perform: delete)
            }
            .navigationTitle("History")
            .toolbar { if !records.isEmpty { EditButton() } }
            .overlay {
                if records.isEmpty {
                    EmptyStateView(symbol: "clock",
                                   title: "No scans yet",
                                   message: "Scan your first product on the Scan tab.")
                }
            }
        }
    }

    private func delete(at offsets: IndexSet) {
        for index in offsets { modelContext.delete(records[index]) }
        try? modelContext.save()
    }
}
