//
//  GradeMatrix+Review.swift
//  Haliable
//
//  Launch-gate support: a deterministic, read-only projection of the live
//  seeded matrix + certifier satisfaction sets for the REVIEW.md generator
//  (`ReviewDocument`) and its coverage test. Nothing here AUTHORS a fiqh value
//  or changes a seed — it only enumerates and groups what is already in
//  `GradeMatrix.seededTable` and `CertificationBody`. The four OPEN levers
//  (Final Spec §A) are surfaced as questions, not decisions.
//

import Foundation

extension GradeMatrix {

    // MARK: - Seeded-cell enumeration

    /// One seeded outcome flattened out of the nested table, for review.
    struct SeededEntry: Hashable {
        let subject: Subject
        let origin: Origin
        let standard: HalalStandard
        let cell: GradeCell

        /// Stable identity string a reviewer (and the coverage test) can key on.
        var key: String { "\(subject.reviewLabel) | \(origin.rawValue) | \(standard.rawValue)" }
    }

    /// Every seeded `(subject, origin, standard)` cell in the live table, in a
    /// deterministic order (subject kind → subject label → origin → strictness).
    /// The REVIEW.md generator and its coverage test both read this, so no
    /// flagged cell can be silently dropped from scholar review.
    static var allSeededEntries: [SeededEntry] {
        var out: [SeededEntry] = []
        for (subject, byOrigin) in seededTable {
            for (origin, byStandard) in byOrigin {
                for (standard, bare) in byStandard {
                    // Enrich with live citations (Citations.json) + the §8 inputs,
                    // so the worksheet/tests see real clearance state, not bare grades.
                    let cell = enriched(grade: bare.grade, confidence: bare.confidence,
                                        source: bare.source, subjectLabel: subject.reviewLabel,
                                        origin: origin, position: standard)
                    out.append(SeededEntry(subject: subject, origin: origin,
                                           standard: standard, cell: cell))
                }
            }
        }
        return out.sorted { lhs, rhs in
            let lr = (lhs.subject.sortRank, lhs.subject.reviewLabel,
                      Self.originRank(lhs.origin), lhs.standard.strictnessRank * -1)
            let rr = (rhs.subject.sortRank, rhs.subject.reviewLabel,
                      Self.originRank(rhs.origin), rhs.standard.strictnessRank * -1)
            if lr.0 != rr.0 { return lr.0 < rr.0 }
            if lr.1 != rr.1 { return lr.1 < rr.1 }
            if lr.2 != rr.2 { return lr.2 < rr.2 }
            return lr.3 < rr.3
        }
    }

    /// A "row" is one (subject, origin) pairing across the four positions —
    /// the natural unit for the review table. Returns the four standards in
    /// strict→lenient order with their cells.
    struct SeededRow: Hashable {
        let subject: Subject
        let origin: Origin
        /// zabiha, hanafiStrict, general, lenient — in that fixed display order.
        let cells: [(standard: HalalStandard, cell: GradeCell)]

        static func == (l: SeededRow, r: SeededRow) -> Bool {
            l.subject == r.subject && l.origin == r.origin
                && l.cells.map(\.cell) == r.cells.map(\.cell)
                && l.cells.map(\.standard) == r.cells.map(\.standard)
        }
        func hash(into h: inout Hasher) {
            h.combine(subject); h.combine(origin); h.combine(cells.map(\.cell))
        }

        /// The shared provenance string (cells in a row carry the same source).
        var source: String { cells.first?.cell.source ?? "" }
        /// True when the four positions do not all agree — a consequential call.
        var diverges: Bool { Set(cells.map(\.cell.grade)).count > 1 }
        /// All cells in the row are draft (every seed is, but assert it explicitly).
        var needsReview: Bool { cells.contains { $0.cell.needsReview } }
    }

    /// The seeded table reshaped into display rows, grouped by review category,
    /// deterministically ordered. This is what the transform table renders.
    static var seededRows: [SeededRow] {
        let order: [HalalStandard] = [.zabiha, .hanafiStrict, .general, .lenient]
        var rows: [SeededRow] = []
        for (subject, byOrigin) in seededTable {
            for (origin, byStandard) in byOrigin {
                let cells = order.compactMap { std -> (standard: HalalStandard, cell: GradeCell)? in
                    byStandard[std].map { bare in
                        (standard: std,
                         cell: enriched(grade: bare.grade, confidence: bare.confidence,
                                        source: bare.source, subjectLabel: subject.reviewLabel,
                                        origin: origin, position: std))
                    }
                }
                guard !cells.isEmpty else { continue }
                rows.append(SeededRow(subject: subject, origin: origin, cells: cells))
            }
        }
        return rows.sorted { lhs, rhs in
            let lg = ReviewGroup.of(lhs.subject), rg = ReviewGroup.of(rhs.subject)
            if lg.order != rg.order { return lg.order < rg.order }
            if lhs.subject.sortRank != rhs.subject.sortRank { return lhs.subject.sortRank < rhs.subject.sortRank }
            if lhs.subject.reviewLabel != rhs.subject.reviewLabel { return lhs.subject.reviewLabel < rhs.subject.reviewLabel }
            return originRank(lhs.origin) < originRank(rhs.origin)
        }
    }

    /// The subset of rows where the four positions disagree — the divergence
    /// appendix (vanilla extract, carmine, rennet, …). Most consequential first
    /// (widest spread between strictest and most-lenient grade).
    static var divergentRows: [SeededRow] {
        seededRows.filter(\.diverges).sorted { a, b in
            spread(a) != spread(b) ? spread(a) > spread(b)
                                   : a.subject.reviewLabel < b.subject.reviewLabel
        }
    }

    private static func spread(_ row: SeededRow) -> Int {
        let grades = row.cells.map(\.cell.grade.rawValue)
        return (grades.max() ?? 0) - (grades.min() ?? 0)
    }

    static func originRank(_ origin: Origin) -> Int {
        Origin.allCases.firstIndex(of: origin) ?? Int.max
    }

    /// The published body whose stance governs a position (Citation Protocol §1A).
    /// `lenient` is a synthesized "most permissive defensible" stance, not one body.
    static func governingBody(for position: HalalStandard) -> String {
        switch position {
        case .zabiha:       return "HMC / HFSAA"
        case .hanafiStrict: return "JAKIM / MUI / ESMA"
        case .general:      return "IFANCA / ISNA"
        case .lenient:      return "most permissive published scholarly position (needs 2 sources)"
        }
    }

    // MARK: - Open levers (Final Spec §A — surfaced, NOT decided)

    /// One of the four fiqh-direction calls the engineer must NOT make. Each
    /// carries a live status read from the code where derivable, so the reviewer
    /// sees the current (default / absent) behavior alongside the open question.
    struct OpenLever: Hashable {
        let id: String
        let title: String
        let question: String
        let liveStatus: String
    }

    /// The four UNSET levers, with live status pulled from the matrix/certifier
    /// state so the document reflects the code, not a stale note.
    static var openLevers: [OpenLever] {
        let hasSeafoodRow = seededTable[.category(.seafoodNonFish)] != nil
        let confidences = Set(allSeededEntries.map(\.cell.confidence.rawValue)).sorted()

        return [
            OpenLever(
                id: "seafood-non-fish",
                title: "Seafood / non-fish seafood lever",
                question: "What grade does non-fish seafood (shrimp, crab, shellfish, squid, …) take under each of the four positions — and does hanafiStrict escalate it (fish-only)?",
                liveStatus: hasSeafoodRow
                    ? "A seafood row IS seeded — confirm its values."
                    : "UNSET — no `category(.seafoodNonFish)` row is seeded, so it currently falls to the conservative fallback (Questionable — contested) under every position. The old fish-only escalation under hanafiStrict is NOT reproduced."
            ),
            OpenLever(
                id: "bare-alcohol-tier",
                title: "Bare-alcohol tier",
                question: "What grade applies to alcohol/ethanol that is neither confirmed khamr nor a confirmed <0.5% non-khamr carrier (i.e. presence known, source/quantity unknown)?",
                liveStatus: "UNSET — confirmed khamr tokens hit the hard-haram pin (Haram, all positions); a named non-khamr carrier uses the vanilla-extract tier. The in-between 'bare alcohol' case has no dedicated tier and currently rides the generic alcohol-carrier row."
            ),
            OpenLever(
                id: "certifier-meat-split",
                title: "Certifier meat / non-meat split",
                question: "Should a body's satisfaction set differ for meat vs non-meat products (e.g. a body trusted for additives but not for its slaughter standard)?",
                liveStatus: "UNSET — each `CertificationBody` exposes a SINGLE `confidentlySatisfies` set with no meat/non-meat distinction. `uncertainlySatisfies` is empty pending this call."
            ),
            OpenLever(
                id: "confidence",
                title: "Confidence levels",
                question: "Confirm the `Confidence` value on each seeded cell (drives how assertively the UI may speak once a cell is signed off).",
                liveStatus: "UNSET as authoritative — seeded cells currently carry: \(confidences.joined(separator: ", ")). All are draft."
            ),
        ]
    }

    /// Certifier → satisfaction projection for the review table.
    struct CertifierReviewRow: Hashable {
        let body: CertificationBody
        let standard: HalalStandard
        let satisfies: Bool
        /// "confident" | "uncertain"
        let basis: String
    }

    static var certifierReviewRows: [CertifierReviewRow] {
        let order: [HalalStandard] = [.zabiha, .hanafiStrict, .general, .lenient]
        var rows: [CertifierReviewRow] = []
        for body in CertificationBody.allCases {
            for std in order {
                let confident = body.confidentlySatisfies.contains(std)
                let uncertain = body.uncertainlySatisfies.contains(std)
                rows.append(CertifierReviewRow(
                    body: body, standard: std,
                    satisfies: confident || uncertain,
                    basis: confident ? "confident" : (uncertain ? "uncertain (may meet)" : "—")
                ))
            }
        }
        return rows
    }
}

// MARK: - Subject + grouping helpers

extension GradeMatrix.Subject {
    /// Human-readable label for the review tables.
    var reviewLabel: String {
        switch self {
        case .category(let c): return c.rawValue
        case .eNumber(let e):  return e
        case .named(let n):    return n
        }
    }

    /// Orders the three subject kinds: category → E-number → named.
    var sortRank: Int {
        switch self {
        case .category: return 0
        case .eNumber:  return 1
        case .named:    return 2
        }
    }
}

/// The ingredient-category buckets the transform table is grouped under.
enum ReviewGroup: String, CaseIterable {
    case animal      = "Animal / slaughter-dependent"
    case insect      = "Insect-derived"
    case alcohol     = "Alcohol carriers (non-khamr)"
    case additive    = "Ambiguous-origin additives"

    var order: Int { ReviewGroup.allCases.firstIndex(of: self) ?? Int.max }

    static func of(_ subject: GradeMatrix.Subject) -> ReviewGroup {
        switch subject {
        case .category(.gelatin), .category(.meat), .category(.enzyme):
            return .animal
        case .named("whey"):
            return .animal
        case .eNumber("E120"), .eNumber("E904"), .eNumber("E901"):
            return .insect
        case .category(.alcohol), .named("vanilla extract"), .named("flavor ethanol carrier"):
            return .alcohol
        default:
            return .additive
        }
    }
}
