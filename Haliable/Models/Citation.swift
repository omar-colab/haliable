//
//  Citation.swift
//  Haliable
//
//  Sourced-research model (Citation Protocol §7). Haliable REPORTS published
//  positions with real citations — it never issues a bare ruling in its own
//  voice. A grade may present as cleared only when backed by strong-enough,
//  well-formed sources; otherwise it stays pending.
//
//  Citations are DATA, not code: they live in the bundled `Citations.json`
//  (see CitationStore) keyed by {subject, origin, position}. Filling a cell never
//  requires a Swift edit. The clearance invariant (Protocol §8) is enforced in
//  `GradeCell` so it can't be bypassed.
//

import Foundation

/// Source quality tier (Protocol §2). Tier 1 or 2 may clear a cell; tier 3 may
/// orient the reasoning but never clears on its own.
enum SourceTier: Int, Codable, Hashable, CaseIterable {
    case standardBody = 1   // the body's OWN published doc (JAKIM/MUI/ESMA/SMIIC, IFANCA/HMC/HFSAA)
    case peerReviewed = 2   // peer-reviewed scholarship (journal / Google Scholar)
    case secondary    = 3   // reputable explainer — orientation only

    /// Tier 1 and 2 are strong enough to clear a cell; tier 3 is not.
    var canClear: Bool { self == .standardBody || self == .peerReviewed }

    var shortLabel: String { "Tier \(rawValue)" }

    var label: String {
        switch self {
        case .standardBody: return "Tier 1 — standard body's own document"
        case .peerReviewed: return "Tier 2 — peer-reviewed scholarship"
        case .secondary:    return "Tier 3 — secondary explainer (support only)"
        }
    }
}

/// One published source backing a reported position (Protocol §7). Plural on a
/// cell: a contested item or a two-source clearance stores several.
struct Citation: Codable, Hashable {
    let sourceName: String      // e.g. "JAKIM MS1500:2019", "MUI Fatwa No. 12/2011"
    let reference: String       // URL or document + clause/page
    let date: String            // publication or access date
    let tier: SourceTier
    let paraphrase: String      // what the source actually says — lets anyone check the grade

    init(sourceName: String, reference: String, date: String,
         tier: SourceTier, paraphrase: String) {
        self.sourceName = sourceName
        self.reference = reference
        self.date = date
        self.tier = tier
        self.paraphrase = paraphrase
    }

    /// Well-formed = all four fields present (§8.3): name + reference + date + paraphrase.
    var isWellFormed: Bool {
        ![sourceName, reference, date, paraphrase].contains {
            $0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
    }

    /// Strong enough to count toward clearance: tier 1/2 AND well-formed.
    var clears: Bool { tier.canClear && isWellFormed }

    /// Normalized organization/author identity, for the "independent sources" check.
    var sourceIdentity: String {
        sourceName.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    /// One-line summary for the verdict detail and the worksheet.
    var oneLine: String {
        let head = "\(sourceName) (\(tier.shortLabel), \(date))"
        return paraphrase.isEmpty ? head : "\(head): \(paraphrase)"
    }
}

/// The persistent standing disclosure (Protocol §12) — shown on every verdict
/// surface so "report, don't rule" stays true to the user. One source of truth.
enum HaliableDisclosure {
    static let standing =
        "Sourced from published halal standards and scholarly references — verify with a scholar you trust for your situation."
}
