//
//  CitationStore.swift
//  Haliable
//
//  Citations live as editable DATA, not Swift (Citation Protocol §9). This loads
//  the bundled `Citations.json` and hands citations to the engine, which applies
//  the §8 gate. Two keyed sections:
//    • `cells`      — grade cells, keyed {subject, origin, position}
//    • `certifiers` — body→standard satisfaction claims, keyed {body, position}
//  Adding a citation = editing JSON. No code change, no risk to the engine.
//
//  Ships EMPTY: until the owner fills entries, every cell AND every certifier
//  claim stays pending. A missing/unparseable file degrades safely to empty.
//

import Foundation

/// One JSON entry: the citations for a single (subject, origin, position) grade cell.
struct CitationEntry: Codable, Hashable {
    let subject: String     // GradeMatrix.Subject.reviewLabel, e.g. "E120", "gelatin"
    let origin: String      // Origin.rawValue, e.g. "unspecified", "plant"
    let position: String    // HalalStandard.rawValue, e.g. "lenient"
    let citations: [Citation]
}

/// One JSON entry: the citations backing a certifier→standard satisfaction claim
/// (the body's own recognition / accreditation list).
struct CertifierCitationEntry: Codable, Hashable {
    let body: String        // CertificationBody.rawValue, e.g. "hmc"
    let position: String    // HalalStandard.rawValue, e.g. "zabiha"
    let citations: [Citation]
}

/// Top-level shape of Citations.json. `certifiers` is optional so the empty
/// `{ "version": 1, "cells": [] }` file still decodes.
struct CitationFile: Codable, Hashable {
    let version: Int
    let cells: [CitationEntry]
    let certifiers: [CertifierCitationEntry]?
}

/// Loads + indexes Citations.json. `shared` is the production instance; it is a
/// `var` ONLY so tests may inject a fixture — production never reassigns it.
final class CitationStore {

    static var shared = CitationStore()

    private let byCell: [String: [Citation]]
    private let byCert: [String: [Citation]]

    static func cellKey(subject: String, origin: String, position: String) -> String {
        "cell::\(subject)::\(origin)::\(position)"
    }
    static func certKey(body: String, position: String) -> String {
        "cert::\(body)::\(position)"
    }

    /// Production init — load from the bundle, degrade to empty on any failure.
    init() {
        let file = Self.loadFromBundle()
        self.byCell = Self.indexCells(file?.cells ?? [])
        self.byCert = Self.indexCerts(file?.certifiers ?? [])
    }

    /// Test/explicit init.
    init(cells: [CitationEntry] = [], certifiers: [CertifierCitationEntry] = []) {
        self.byCell = Self.indexCells(cells)
        self.byCert = Self.indexCerts(certifiers)
    }

    /// Convenience kept for cell-only fixtures.
    convenience init(entries: [CitationEntry]) { self.init(cells: entries, certifiers: []) }

    // MARK: - Lookups

    /// Citations for a grade cell, or [] when none are on file.
    func citations(subject: String, origin: String, position: String) -> [Citation] {
        byCell[Self.cellKey(subject: subject, origin: origin, position: position)] ?? []
    }

    /// Citations backing a certifier→standard satisfaction claim, or [].
    func citations(body: String, position: String) -> [Citation] {
        byCert[Self.certKey(body: body, position: position)] ?? []
    }

    /// Total citations on file (cells + certifiers) — worksheet header + tests.
    var totalCitationCount: Int {
        byCell.values.reduce(0) { $0 + $1.count } + byCert.values.reduce(0) { $0 + $1.count }
    }

    // MARK: - Loading

    private static func indexCells(_ entries: [CitationEntry]) -> [String: [Citation]] {
        var out: [String: [Citation]] = [:]
        for e in entries {
            out[cellKey(subject: e.subject, origin: e.origin, position: e.position), default: []] += e.citations
        }
        return out
    }

    private static func indexCerts(_ entries: [CertifierCitationEntry]) -> [String: [Citation]] {
        var out: [String: [Citation]] = [:]
        for e in entries {
            out[certKey(body: e.body, position: e.position), default: []] += e.citations
        }
        return out
    }

    /// Decode a `CitationFile` from raw JSON (exposed for tests).
    static func decode(_ data: Data) -> CitationFile? {
        try? JSONDecoder().decode(CitationFile.self, from: data)
    }

    private static func loadFromBundle() -> CitationFile? {
        for bundle in Bundle.allBundles {
            if let url = bundle.url(forResource: "Citations", withExtension: "json"),
               let data = try? Data(contentsOf: url),
               let file = decode(data) {
                return file
            }
        }
        return nil
    }
}
