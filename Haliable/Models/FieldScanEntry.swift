//
//  FieldScanEntry.swift
//  Haliable
//
//  Field-validation log (Citation Protocol §4). As the owner (and a friend) scan
//  real grocery items, each scan is logged. This does two jobs at once: it
//  validates the engine ("did the grade look right?") AND counts which subjects
//  actually recur — that frequency is the high-traffic signal that orders the
//  research worksheet (`ReviewDocument.generate(fieldLog:)`).
//
//  Entries are shareable: a second person's exported log merges in (deduped by
//  id), so two people scanning separately pool into one prioritized order.
//

import Foundation

/// One logged scan during field validation.
struct FieldScanEntry: Codable, Identifiable, Hashable {
    let id: UUID
    let gtin: String                // barcode (GTIN), the scan's identity
    let productName: String
    let position: HalalStandard     // the active standard at scan time
    let computedGrade: GradeLevel   // what the engine returned
    let subjects: [String]          // flagged subject labels in this scan (traffic signal)
    let lookedRight: Bool?          // owner's eyeball check — nil = not yet judged
    let scannedAt: Date
    let scannerId: String           // who scanned (provenance for pooling)

    init(id: UUID = UUID(), gtin: String, productName: String, position: HalalStandard,
         computedGrade: GradeLevel, subjects: [String], lookedRight: Bool? = nil,
         scannedAt: Date = Date(), scannerId: String) {
        self.id = id
        self.gtin = gtin
        self.productName = productName
        self.position = position
        self.computedGrade = computedGrade
        self.subjects = subjects
        self.lookedRight = lookedRight
        self.scannedAt = scannedAt
        self.scannerId = scannerId
    }
}

/// The exchange format for sharing/pooling logs between scanners.
struct FieldScanExport: Codable, Hashable {
    let version: Int
    let entries: [FieldScanEntry]
}
