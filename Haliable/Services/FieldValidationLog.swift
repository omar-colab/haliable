//
//  FieldValidationLog.swift
//  Haliable
//
//  The store behind the field-validation log (Citation Protocol §4). Records
//  scans, persists them as JSON, exports them for sharing, and merges another
//  scanner's export so counts POOL into one prioritized order. Its `subjectCounts`
//  feed `ReviewDocument.generate(fieldLog:)` so the worksheet self-orders by what
//  is actually scanned.
//
//  @Observable so a future logging screen can bind to it; injectable file URL
//  (nil = in-memory) keeps it testable.
//

import Foundation
import Observation

@Observable
final class FieldValidationLog {

    /// Logged scans, most recent last. Deduped by `id` on insert/merge.
    private(set) var entries: [FieldScanEntry]

    /// Where entries persist (nil = in-memory only, used by tests).
    private let fileURL: URL?

    private static let exportVersion = 1

    init(fileURL: URL? = FieldValidationLog.defaultFileURL()) {
        self.fileURL = fileURL
        self.entries = FieldValidationLog.load(from: fileURL)
    }

    // MARK: - Recording

    /// Append a scan (no-op if an entry with the same id already exists).
    func record(_ entry: FieldScanEntry) {
        guard !entries.contains(where: { $0.id == entry.id }) else { return }
        entries.append(entry)
        save()
    }

    /// Convenience: log a scan straight from a computed verdict. `subjects` are the
    /// flagged ingredients' resolved subject labels — the traffic signal.
    @discardableResult
    func record(verdict: ProductVerdict, scannerId: String, lookedRight: Bool? = nil) -> FieldScanEntry {
        let subjects = Array(Set(verdict.flagged.map { GradeMatrix.subjectLabel(for: $0) })).sorted()
        let entry = FieldScanEntry(
            gtin: verdict.product.id,
            productName: verdict.product.name,
            position: verdict.matched.first?.standard ?? .general,
            computedGrade: verdict.overallGrade,
            subjects: subjects,
            lookedRight: lookedRight,
            scannerId: scannerId
        )
        record(entry)
        return entry
    }

    // MARK: - Traffic signal

    /// Subject → number of scans that flagged it. This is the high-traffic order
    /// the worksheet uses. Each scan counts a subject at most once.
    func subjectCounts() -> [String: Int] {
        var counts: [String: Int] = [:]
        for entry in entries {
            for subject in Set(entry.subjects) { counts[subject, default: 0] += 1 }
        }
        return counts
    }

    /// How many scans judged the grade wrong — a quick engine-accuracy read.
    var lookedWrongCount: Int { entries.filter { $0.lookedRight == false }.count }

    // MARK: - Share / pool

    /// Serialize the log for sharing with another scanner.
    func exportData() throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return try encoder.encode(FieldScanExport(version: Self.exportVersion, entries: entries))
    }

    /// Write the export to a temporary file and return its URL (for a share sheet).
    func exportFileURL(filename: String = "haliable-field-log.json") throws -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(filename)
        try exportData().write(to: url, options: .atomic)
        return url
    }

    /// Merge another scanner's export. Deduped by `id`, so pooling the same export
    /// twice is idempotent. Returns the number of NEW entries added.
    @discardableResult
    func merge(_ data: Data) -> Int {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        guard let imported = try? decoder.decode(FieldScanExport.self, from: data) else { return 0 }
        return merge(imported.entries)
    }

    @discardableResult
    func merge(_ incoming: [FieldScanEntry]) -> Int {
        let existing = Set(entries.map(\.id))
        let fresh = incoming.filter { !existing.contains($0.id) }
        guard !fresh.isEmpty else { return 0 }
        entries.append(contentsOf: fresh)
        save()
        return fresh.count
    }

    // MARK: - Persistence

    static func defaultFileURL() -> URL? {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first?
            .appendingPathComponent("FieldValidationLog.json")
    }

    private static func load(from url: URL?) -> [FieldScanEntry] {
        guard let url, let data = try? Data(contentsOf: url) else { return [] }
        let decoder = JSONDecoder(); decoder.dateDecodingStrategy = .iso8601
        return (try? decoder.decode(FieldScanExport.self, from: data))?.entries ?? []
    }

    private func save() {
        guard let fileURL else { return }
        guard let data = try? exportData() else { return }
        try? data.write(to: fileURL, options: .atomic)
    }
}
