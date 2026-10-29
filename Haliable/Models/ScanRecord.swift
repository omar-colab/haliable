//
//  ScanRecord.swift
//  Haliable
//
//  Created by Omar O on 5/29/26.
//

import Foundation
import SwiftData

// One saved scan — the minimal info we keep in history.
//
// Migrated from a Codable struct to a SwiftData @Model. SwiftData gives us
// persistence, querying (@Query), and automatic UI updates for free, and is
// the iOS 17+ successor to Core Data. `Verdict` persists fine because it is a
// Codable RawRepresentable.
@Model
final class ScanRecord {
    @Attribute(.unique) var id: UUID
    var barcode: String
    var productName: String
    var overallVerdict: Verdict
    var scannedAt: Date
    /// The standard this scan was graded under. Optional so rows saved before it
    /// existed migrate cleanly (they simply show no standard).
    var standardRaw: String? = nil
    /// `ProductVerdict.clearedScore` at scan time. Optional for the same reason.
    var score: Int? = nil
    /// Ingredients typed or read off a pack. Set only for label checks, which
    /// have no barcode (`barcode` is empty); re-checking grades this text.
    var ingredientsText: String? = nil

    var standard: HalalStandard? { standardRaw.flatMap(HalalStandard.init(rawValue:)) }

    init(
        id: UUID = UUID(),
        barcode: String,
        productName: String,
        overallVerdict: Verdict,
        scannedAt: Date = .now,
        standard: HalalStandard? = nil,
        score: Int? = nil,
        ingredientsText: String? = nil
    ) {
        self.id = id
        self.barcode = barcode
        self.productName = productName
        self.overallVerdict = overallVerdict
        self.scannedAt = scannedAt
        self.standardRaw = standard?.rawValue
        self.score = score
        self.ingredientsText = ingredientsText
    }
}

extension ScanRecord {
    /// Saves a label check. The same list checked again replaces its old row,
    /// like a re-scanned barcode.
    static func saveLabelCheck(_ text: String, verdict: ProductVerdict,
                               standard: HalalStandard, in context: ModelContext) {
        let key: String? = text
        let old = (try? context.fetch(FetchDescriptor<ScanRecord>(
            predicate: #Predicate { $0.ingredientsText == key }))) ?? []
        old.forEach(context.delete)
        context.insert(ScanRecord(barcode: "", productName: labelTitle(text),
                                  overallVerdict: verdict.overall, standard: standard,
                                  score: verdict.clearedScore, ingredientsText: text))
        try? context.save()
    }

    /// "Label: sugar, gelatin, water…" — the first three items name the row.
    static func labelTitle(_ text: String) -> String {
        let items = text.split(whereSeparator: { ",;\n".contains($0) })
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        return "Label: " + items.prefix(3).joined(separator: ", ") + (items.count > 3 ? "…" : "")
    }
}
