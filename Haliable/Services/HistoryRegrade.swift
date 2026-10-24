//
//  HistoryRegrade.swift
//  Haliable
//
//  A History row stores the verdict from the day it was scanned. When the
//  rules get better (a new alias, a stricter match), an old "Halal" row must
//  not keep saying Halal. Once per app version, every row with a cached
//  product is graded again under the standard it was saved with.
//

import Foundation
import SwiftData

enum HistoryRegrade {
    /// The rules ship inside the app, so a new version is when they can change.
    static var currentStamp: String {
        let info = Bundle.main.infoDictionary
        return "\(info?["CFBundleShortVersionString"] ?? "")-\(info?["CFBundleVersion"] ?? "")"
    }
    private static let stampKey = "historyRegradeStamp"

    /// Runs on the main actor (SwiftData's context), yielding between rows so
    /// a long History never freezes launch.
    @MainActor static func run(context: ModelContext, engine: RulesEngine,
                               stamp: String = currentStamp, defaults: UserDefaults = .standard) async {
        guard defaults.string(forKey: stampKey) != stamp else { return }
        let records = (try? context.fetch(FetchDescriptor<ScanRecord>())) ?? []
        let cache = SwiftDataProductCache(context: context)
        for record in records {
            if Task.isCancelled { return }   // try again next launch
            guard let product = cache.cached(barcode: record.barcode) else { continue }
            let verdict = engine.evaluate(product: product, standard: record.standard ?? .general)
            if record.overallVerdict != verdict.overall || record.score != verdict.clearedScore {
                record.overallVerdict = verdict.overall
                record.score = verdict.clearedScore
            }
            await Task.yield()
        }
        try? context.save()
        defaults.set(stamp, forKey: stampKey)
    }
}
