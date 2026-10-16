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

    var standard: HalalStandard? { standardRaw.flatMap(HalalStandard.init(rawValue:)) }

    init(
        id: UUID = UUID(),
        barcode: String,
        productName: String,
        overallVerdict: Verdict,
        scannedAt: Date = .now,
        standard: HalalStandard? = nil
    ) {
        self.id = id
        self.barcode = barcode
        self.productName = productName
        self.overallVerdict = overallVerdict
        self.scannedAt = scannedAt
        self.standardRaw = standard?.rawValue
    }
}
