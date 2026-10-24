//
//  HistoryRegrade.swift
//  Haliable
//
//  A History row stores the verdict from the day it was scanned. When the
//  rules get better (a new alias, a stricter match), an old "Halal" row must
//  not keep saying Halal. On launch, every row with a cached product is graded
//  again under the standard it was saved with.
//

import Foundation
import SwiftData

enum HistoryRegrade {
    /// ponytail: re-grades every row on each launch (~1 ms each); gate on a
    /// rules-version stamp if History ever reaches thousands of rows.
    @MainActor static func run(context: ModelContext, engine: RulesEngine) {
        guard let records = try? context.fetch(FetchDescriptor<ScanRecord>()), !records.isEmpty else { return }
        let cache = SwiftDataProductCache(context: context)
        var changed = false
        for record in records {
            guard let product = cache.cached(barcode: record.barcode) else { continue }
            let verdict = engine.evaluate(product: product, standard: record.standard ?? .general)
            if record.overallVerdict != verdict.overall || record.score != verdict.clearedScore {
                record.overallVerdict = verdict.overall
                record.score = verdict.clearedScore
                changed = true
            }
        }
        if changed { try? context.save() }
    }
}
